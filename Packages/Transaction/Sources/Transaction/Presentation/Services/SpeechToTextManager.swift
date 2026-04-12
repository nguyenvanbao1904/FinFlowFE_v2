import AVFoundation
import Foundation
import Speech
import Observation

// MARK: - SpeechToTextManager
@MainActor
@Observable
final class SpeechToTextManager {
    
    var isListening: Bool = false
    var latestTranscript: String = ""
    
    @ObservationIgnored private let audio = SpeechAudioActor()
    
    // MARK: - Public API
    
    func startListening(
        onPartialText: @MainActor @escaping (String) -> Void,
        onError: @MainActor @escaping (String) -> Void,
        onAutoSubmit: @MainActor @escaping (String) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            let granted = await audio.requestPermissions()
            guard granted else {
                onError("Bạn chưa cấp quyền microphone hoặc nhận diện giọng nói.")
                return
            }
            
            do {
                try await audio.beginRecognition(
                    onTranscript: { transcript in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.latestTranscript = transcript
                            onPartialText(transcript)
                        }
                    },
                    onStop: { errorMessage in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.isListening = false
                            // Chỉ gọi onError nếu thực sự có thông báo lỗi
                            if let msg = errorMessage { onError(msg) }
                        }
                    },
                    onAutoSubmit: { finalText in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.isListening = false
                            self.latestTranscript = finalText
                            if !finalText.isEmpty {
                                onAutoSubmit(finalText)
                            }
                        }
                    }
                )
                self.isListening = true
            } catch {
                onError("Không thể bắt đầu ghi âm: \(error.localizedDescription)")
            }
        }
    }
    
    func stopListening() {
        isListening = false
        Task { await audio.stop() }
    }
}

// MARK: - AutoSubmitDebouncer
private actor AutoSubmitDebouncer {
    private var pendingTask: Task<Void, Never>?
    private var latestTranscript: String = ""
    
    func updateTranscript(_ transcript: String) {
        latestTranscript = transcript
    }
    
    func reschedule(
        after delay: TimeInterval,
        onFire: @Sendable @escaping (String) async -> Void
    ) {
        pendingTask?.cancel()
        pendingTask = Task {
            let delayNs = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled else { return }
            let finalText = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !finalText.isEmpty else { return }
            await onFire(finalText)
        }
    }
    
    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}

// MARK: - SpeechAudioActor
private actor SpeechAudioActor {
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
    
    // MARK: Permissions
    func requestPermissions() async -> Bool {
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
    
    // MARK: Recognition
    func beginRecognition(
        onTranscript: @Sendable @escaping (String) async -> Void,
        onStop: @Sendable @escaping (String?) async -> Void,
        onAutoSubmit: @Sendable @escaping (String) async -> Void,
        silenceDelay: TimeInterval = 1.5
    ) throws {
        guard let recognizer, recognizer.isAvailable else {
            Task { await onStop("Nhận diện giọng nói không khả dụng.") }
            return
        }
        
        stopInternal()
        
        let engine = audioEngine ?? AVAudioEngine()
        audioEngine = engine
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        let inputNode = engine.inputNode
        
        // FIX CRASH SIMULATOR: Ép sample rate nếu hệ thống trả về 0
        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 {
            recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) ?? recordingFormat
        }
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buf, _ in
            request.append(buf)
        }
        
        engine.prepare()
        try engine.start()
        
        let autoSubmitDebouncer = AutoSubmitDebouncer()
        
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            let transcript = result?.bestTranscription.formattedString ?? ""
            let isFinal = result?.isFinal ?? false
            
            if !transcript.isEmpty {
                Task {
                    await onTranscript(transcript)
                    await autoSubmitDebouncer.updateTranscript(transcript)
                    await autoSubmitDebouncer.reschedule(after: silenceDelay, onFire: onAutoSubmit)
                }
            }
            
            // --- LOGIC FIX LỖI POPUP PHIỀN PHỨC ---
            if isFinal {
                // Nếu đã xong thành công, hủy debouncer và báo Stop êm đẹp
                Task {
                    await autoSubmitDebouncer.cancel()
                    await onStop(nil)
                }
            } else if let error = error {
                Task {
                    let nsError = error as NSError
                    // Code 216 là lỗi "User Cancelled" - Xảy ra khi ta chủ động stop engine
                    // Chúng ta sẽ lờ lỗi này đi để không hiện Alert vô lý
                    if nsError.code != 216 {
                        await autoSubmitDebouncer.cancel()
                        await onStop("Nhận diện bị gián đoạn.")
                    } else {
                        // Nếu là lỗi 216 (do mình bấm dừng), chỉ cần dọn dẹp âm thầm
                        await autoSubmitDebouncer.cancel()
                        await onStop(nil)
                    }
                }
            }
        }
    }
    
    func stop() {
        stopInternal()
    }
    
    private func stopInternal() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if let engine = audioEngine {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
        }
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
