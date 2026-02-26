//
//  CreatePINViewModel.swift
//  Dashboard
//

import FinFlowCore
import Foundation

@MainActor
@Observable
public class CreatePINViewModel {
    public var pin: String = ""
    public var confirmPIN: String = ""
    public var alert: AppErrorAlert?
    public var isProcessing = false
    public var isCompleted = false

    // Sheet state
    public var showCreatePINSheet = false
    public var showConfirmPINSheet = false

    private let email: String
    private let pinManager: any PINManagerProtocol
    private let onCompletion: () -> Void

    public init(email: String, pinManager: any PINManagerProtocol, onCompletion: @escaping () -> Void) {
        self.email = email
        self.pinManager = pinManager
        self.onCompletion = onCompletion
    }

    /// Validation cho PIN
    private var isPINValid: Bool {
        return pin.count == 6 && pin.allSatisfy { $0.isNumber }
    }

    private var isConfirmPINValid: Bool {
        return confirmPIN.count == 6 && confirmPIN.allSatisfy { $0.isNumber }
    }

    public var canSubmit: Bool {
        return isPINValid && isConfirmPINValid && !isProcessing
    }

    /// Tạo mã PIN
    public func createPIN() async {
        guard canSubmit else {
            Logger.debug("CreatePIN: cannot submit (pinValid=\(isPINValid), confirmValid=\(isConfirmPINValid), loading=\(isProcessing))", category: "PIN")
            return
        }

        // Kiểm tra hai mã PIN có khớp không
        guard pin == confirmPIN else {
            alert = .validation(message: "Mã PIN không khớp. Vui lòng thử lại.")
            // Chỉ reset bước xác nhận, giữ nguyên pin để nhập lại confirm
            confirmPIN = ""
            return
        }

        isProcessing = true
        Logger.info("CreatePIN: saving PIN for \(email)", category: "PIN")

        do {
            // Lưu PIN vào keychain
            try await pinManager.savePIN(pin, for: email)
            Logger.info("✅ PIN created successfully for \(email)", category: "PIN")

            // 🔍 Log PIN status để verify
            await pinManager.logPINStatus(for: email)

            isCompleted = true
            onCompletion()
        } catch {
            Logger.error("❌ Failed to save PIN: \(error)", category: "PIN")
            alert = .general(title: "Lỗi", message: "Không thể lưu mã PIN. Vui lòng thử lại.")
        }

        isProcessing = false
    }

    /// Reset form
    public func reset() {
        pin = ""
        confirmPIN = ""
        alert = nil
        showCreatePINSheet = false
        showConfirmPINSheet = false
    }
}
