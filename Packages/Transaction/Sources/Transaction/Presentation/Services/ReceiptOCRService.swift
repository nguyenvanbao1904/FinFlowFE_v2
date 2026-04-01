import Foundation
import UIKit
import Vision

enum ReceiptOCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case visionError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Ảnh không hợp lệ để OCR."
        case .noTextFound:
            return "Không tìm thấy chữ trong ảnh. Thử chụp rõ hơn hoặc chọn ảnh khác."
        case let .visionError(message):
            return message
        }
    }
}

struct ReceiptOCRService: Sendable {
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage ?? image.normalizedCGImage() else {
            throw ReceiptOCRError.invalidImage
        }

        return try await Task.detached(priority: .userInitiated) {
            try Self.runVisionOCR(cgImage: cgImage)
        }.value
    }

    private static func runVisionOCR(cgImage: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02
        request.recognitionLanguages = ["vi-VN", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw ReceiptOCRError.visionError("OCR thất bại: \(error.localizedDescription)")
        }

        let observations = request.results ?? []
        let lines: [String] = observations.compactMap { obs in
            obs.topCandidates(1).first?.string
        }

        let text = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !text.isEmpty else {
            throw ReceiptOCRError.noTextFound
        }

        return text
    }
}

private extension UIImage {
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}

