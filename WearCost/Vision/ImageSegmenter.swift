import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// An actor responsible for on-device ML subject isolation using Apple Vision and CoreImage
actor ImageSegmenter {
    enum SegmenterError: Error, LocalizedError {
        case invalidInputImage
        case maskGenerationFailed
        case processingError

        var errorDescription: String? {
            switch self {
            case .invalidInputImage:
                return "The provided image data could not be parsed."
            case .maskGenerationFailed:
                return "Could not generate a foreground instance mask."
            case .processingError:
                return "Failed to blend image with mask and render cutout."
            }
        }
    }

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Extracts the foreground subject from raw image data, returning a transparent cutout PNG
    func extractForeground(from rawImageData: Data) async throws -> Data {
        guard let normalizedImage = normalizeImage(from: rawImageData),
              let cgImage = normalizedImage.cgImage else {
            throw SegmenterError.invalidInputImage
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()

        try requestHandler.perform([request])

        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw SegmenterError.maskGenerationFailed
        }

        let maskPixelBuffer = try result.generateScaledMaskForImage(
            forInstances: result.allInstances,
            from: requestHandler
        )

        return try applyMask(maskPixelBuffer: maskPixelBuffer, originalCGImage: cgImage)
    }

    /// Robust helper with fallback to normalized original image data if segmentation fails
    func extractForegroundWithFallback(from rawImageData: Data) async -> (data: Data, wasSegmented: Bool) {
        do {
            let cutoutData = try await extractForeground(from: rawImageData)
            return (cutoutData, true)
        } catch {
            // Fallback: return normalized, compressed PNG of the original image
            if let normalized = normalizeImage(from: rawImageData),
               let png = normalized.pngData() {
                return (png, false)
            }
            return (rawImageData, false)
        }
    }

    private func applyMask(maskPixelBuffer: CVPixelBuffer, originalCGImage: CGImage) throws -> Data {
        let originalCIImage = CIImage(cgImage: originalCGImage)
        let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = originalCIImage
        filter.backgroundImage = CIImage(color: .clear)
        filter.maskImage = maskCIImage

        guard let outputCIImage = filter.outputImage,
              let renderedCGImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent),
              let processedImageData = UIImage(cgImage: renderedCGImage).pngData() else {
            throw SegmenterError.processingError
        }

        return processedImageData
    }

    /// Normalizes image orientation and resizes if larger than maxDimension for rapid ANE execution (< 1.5s)
    private func normalizeImage(from data: Data, maxDimension: CGFloat = 1200) -> UIImage? {
        guard let sourceImage = UIImage(data: data) else { return nil }

        var targetSize = sourceImage.size
        let maxDim = max(targetSize.width, targetSize.height)

        if maxDim > maxDimension {
            let scale = maxDimension / maxDim
            targetSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        let rendered = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return rendered
    }
}
