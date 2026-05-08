import AVFoundation
import Foundation
@preconcurrency import Speech
import Observation
import FinFlowCore

// MARK: - SpeechToTextManager
// Tất cả AVFoundation/AVAudioSession/SFSpeechRecognizer chạy trực tiếp
// trên @MainActor để tránh _dispatch_assert_queue_fail.
@MainActor
@Observable
final class SpeechToTextManager {

    // MARK: - State
    var isListening: Bool = false
    var latestTranscript: String = ""

    // MARK: - Private audio state (all accessed only on MainActor)
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    // MARK: - Public API

    func startListening(
        onPartialText: @MainActor @escaping (String) -> Void,
        onError: @MainActor @escaping (String) -> Void,
        onAutoSubmit: @MainActor @escaping (String) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let granted = await self.requestPermissions()
            guard granted else {
                onError("Bạn chưa cấp quyền microphone hoặc nhận diện giọng nói.")
                return
            }

            do {
                try self.beginRecognition(
                    onPartialText: onPartialText,
                    onError: onError,
                    onAutoSubmit: onAutoSubmit
                )
                self.isListening = true
            } catch {
                onError("Không thể bắt đầu ghi âm: \(error.localizedDescription)")
            }
        }
    }

    func stopListening() {
        isListening = false
        stopInternal()
    }

    func endListeningGracefully() {
        isListening = false
        // Signal end of audio → recognition sẽ trả về isFinal = true thay vì lỗi
        recognitionRequest?.endAudio()
        if let engine = audioEngine {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Permissions

    private nonisolated func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }

        if #available(iOS 17, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Core Recognition (all on MainActor)

    private func beginRecognition(
        onPartialText: @MainActor @escaping (String) -> Void,
        onError: @MainActor @escaping (String) -> Void,
        onAutoSubmit: @MainActor @escaping (String) -> Void,
        silenceDelay: TimeInterval = 1.5
    ) throws {
        guard let recognizer, recognizer.isAvailable else {
            onError("Nhận diện giọng nói không khả dụng.")
            return
        }

        stopInternal()

        // AVAudioSession — chạy đúng trên MainActor, tránh crash _dispatch_assert_queue_fail
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = engine.inputNode
        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 {
            recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) ?? recordingFormat
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable buf, _ in
            request.append(buf)
        }

        engine.prepare()
        try engine.start()

        // SFSpeechRecognizer callback KHÔNG đảm bảo chạy trên main thread —
        // phải dispatch về MainActor trước khi chạm vào @Observable state.
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString ?? ""
            let isFinal = result?.isFinal ?? false
            let capturedError = error

            Task { @MainActor [weak self] in
                guard let self else { return }

                if !transcript.isEmpty && self.latestTranscript != transcript {
                    self.latestTranscript = transcript
                    onPartialText(transcript)
                    self.scheduleAutoSubmit(text: transcript, delay: silenceDelay, onFire: onAutoSubmit)
                }

                if isFinal {
                    let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.cancelDebounce()
                    self.isListening = false
                    self.stopInternal()
                    if !finalText.isEmpty {
                        Logger.info("onAutoSubmit(isFinal): '\(finalText)'", category: "Speech")
                        onAutoSubmit(finalText)
                    }
                } else if let error = capturedError {
                    let nsError = error as NSError
                    let isIgnored = nsError.code == 216 ||
                        (nsError.domain == "kAFAssistantErrorDomain" &&
                         (nsError.code == 1101 || nsError.code == 203 || nsError.code == 209))
                    self.cancelDebounce()
                    self.isListening = false
                    self.stopInternal()
                    if !isIgnored {
                        Logger.error("SFSpeechRecognizer lỗi: \(nsError.domain)-\(nsError.code)", category: "Speech")
                        onError("Nhận diện bị gián đoạn.")
                    } else {
                        Logger.info("SFSpeechRecognizer dừng êm đẹp (code: \(nsError.code))", category: "Speech")
                    }
                }
            }
        }
    }

    // MARK: - Debounce (auto-submit sau khoảng lặng)

    private func scheduleAutoSubmit(
        text: String,
        delay: TimeInterval,
        onFire: @MainActor @escaping (String) -> Void
    ) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            let finalText = self.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !finalText.isEmpty else { return }
            Logger.info("Debounce fired: '\(finalText)'", category: "Speech")
            self.endListeningGracefully()
            onFire(finalText)
        }
    }

    private func cancelDebounce() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    // MARK: - Teardown

    private func stopInternal() {
        cancelDebounce()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let engine = audioEngine {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
