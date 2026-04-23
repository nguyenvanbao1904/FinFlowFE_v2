import FinFlowCore
import PhotosUI
import SwiftUI
import UIKit

/// Manages AI text analysis, speech-to-text, and OCR state for AddTransactionView.
@MainActor @Observable
final class TransactionInputAssistant {
    var aiInputText: String = ""
    var isAnalyzing: Bool = false
    var speechErrorMessage: String?
    var showCameraOptions: Bool = false
    var showPhotoPicker: Bool = false
    var selectedPhotoItem: PhotosPickerItem?
    var isOCRing: Bool = false
    var ocrErrorMessage: String?
    var showMagicEffect: Bool = false

    private(set) var speechManager = SpeechToTextManager()
    private var selectedImage: UIImage?

    var isProcessing: Bool {
        isAnalyzing || isOCRing || speechManager.isListening
    }

    func submitTextForAnalysis(
        _ text: String,
        mirrorToInput: Bool,
        analyze: @escaping (String) async -> Void,
        alertAfter: @escaping () -> Bool
    ) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if mirrorToInput { aiInputText = normalized }
        triggerAIAnalysis(text: normalized, analyze: analyze, alertAfter: alertAfter)
    }

    func toggleVoiceInput(analyze: @escaping (String) async -> Void, alertAfter: @escaping () -> Bool) {
        if speechManager.isListening {
            let finalText = speechManager.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            speechManager.stopListening()
            if !finalText.isEmpty {
                submitTextForAnalysis(finalText, mirrorToInput: true, analyze: analyze, alertAfter: alertAfter)
            }
            return
        }

        speechManager.startListening(
            onPartialText: { [weak self] partialText in
                self?.aiInputText = partialText
            },
            onError: { [weak self] message in
                self?.speechErrorMessage = message
            },
            onAutoSubmit: { [weak self] finalText in
                self?.speechManager.stopListening()
                self?.submitTextForAnalysis(finalText, mirrorToInput: true, analyze: analyze, alertAfter: alertAfter)
            }
        )
    }

    func handleCameraTap() {
        if speechManager.isListening { speechManager.stopListening() }
        showCameraOptions = true
    }

    func handleImagePicked(_ image: UIImage, analyze: @escaping (String) async -> Void, alertAfter: @escaping () -> Bool) {
        selectedImage = image
        Task { await runOCRAndAnalyze(analyze: analyze, alertAfter: alertAfter) }
    }

    func handlePhotoSelected(_ item: PhotosPickerItem?, analyze: @escaping (String) async -> Void, alertAfter: @escaping () -> Bool) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    showPhotoPicker = false
                    await runOCRAndAnalyze(analyze: analyze, alertAfter: alertAfter)
                } else {
                    ocrErrorMessage = "Không thể đọc ảnh đã chọn."
                }
            } catch {
                ocrErrorMessage = "Không thể đọc ảnh đã chọn: \(error.localizedDescription)"
            }
        }
    }

    func stopListening() {
        speechManager.stopListening()
    }

    // MARK: - Private

    private func triggerAIAnalysis(
        text: String,
        analyze: @escaping (String) async -> Void,
        alertAfter: @escaping () -> Bool
    ) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isAnalyzing = true }

        Task {
            await analyze(text)

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { isAnalyzing = false }
            }

            guard !alertAfter() else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showMagicEffect = true
                    aiInputText = ""
                }
            }
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                withAnimation { showMagicEffect = false }
            }
        }
    }

    private func runOCRAndAnalyze(analyze: @escaping (String) async -> Void, alertAfter: @escaping () -> Bool) async {
        guard let image = selectedImage, !isOCRing else { return }
        isOCRing = true
        defer {
            isOCRing = false
            selectedImage = nil
            selectedPhotoItem = nil
        }

        do {
            let text = try await ReceiptOCRService().recognizeText(from: image)
            submitTextForAnalysis(text, mirrorToInput: false, analyze: analyze, alertAfter: alertAfter)
        } catch {
            ocrErrorMessage = error.localizedDescription
        }
    }
}
