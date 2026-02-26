import Combine
import FinFlowCore
import Foundation
import SwiftUI

@MainActor
@Observable
public class ForgotPasswordViewModel {
    // Form Data
    public var email = "" {
        didSet {
            // Reset states khi email thay đổi
            isEmailExistenceVerified = false
            emailValidationMessage = nil

            // Trigger debounced validation
            emailDebounceSubject.send(email)
        }
    }
    public var otpCode = "" {
        didSet {
            // Auto-format to digits only, max 6 chars
            Task {
                let formatted = await otpHandler.formatInput(otpCode)
                if formatted != otpCode {
                    otpCode = formatted
                }
            }
        }
    }
    public var password = ""
    public var confirmPassword = ""

    // UI State
    public var step: ForgotPasswordStep = .inputEmail
    public var isLoading = false
    public var isSendingOTP = false
    public var isCheckingEmail = false
    public var alert: AppErrorAlert? = nil
    public var isSuccess = false

    // Email Validation State
    public var isEmailExistenceVerified = false
    private var emailVerifiedForSession = false  // Track if email was verified once this session
    public var emailValidationMessage: String? = nil

    // Computed: Có thể gửi OTP không?
    public var canSendOTP: Bool {
        return isEmailValid && isEmailExistenceVerified && !isCheckingEmail && !isSendingOTP
    }

    public var isEmailValid: Bool {
        guard !email.isEmpty else { return false }
        let emailRegEx = "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    // Data
    private var resetToken = ""

    private let useCase: ForgotPasswordUseCaseProtocol
    private let otpHandler: OTPInputHandler
    private let onSuccess: (String) -> Void

    // Debounce
    private let emailDebounceSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init(
        useCase: ForgotPasswordUseCaseProtocol,
        otpHandler: OTPInputHandler,
        onSuccess: @escaping (String) -> Void = { _ in }
    ) {
        self.useCase = useCase
        self.otpHandler = otpHandler
        self.onSuccess = onSuccess
        setupEmailDebounce()
    }

    // MARK: - Email Validation with Debounce

    private func setupEmailDebounce() {
        emailDebounceSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] email in
                Task { @MainActor [weak self] in
                    await self?.validateEmail(email)
                }
            }
            .store(in: &cancellables)
    }

    private func validateEmail(_ email: String) async {
        // Reset state
        emailValidationMessage = nil
        isEmailExistenceVerified = false

        // Kiểm tra empty
        guard !email.isEmpty else {
            return
        }

        // Kiểm tra format
        guard isEmailValid else {
            emailValidationMessage = "Email không hợp lệ"
            isEmailExistenceVerified = false
            return
        }

        // Kiểm tra email có tồn tại không (NGƯỢC LẠI với Register)
        isCheckingEmail = true
        defer { isCheckingEmail = false }

        do {
            let response = try await useCase.checkUserExistence(email: email)

            if !response.exists {
                emailValidationMessage = "Email không tồn tại trong hệ thống"
                isEmailExistenceVerified = false
                return
            }
            
            // Check account status
            if let isDeleted = response.isDeleted, isDeleted {
                emailValidationMessage = "Tài khoản đã được lên lịch xóa"
                isEmailExistenceVerified = false
                return
            }
            
            if let isActive = response.isActive, !isActive {
                emailValidationMessage = "Tài khoản đã bị vô hiệu hóa"
                isEmailExistenceVerified = false
                return
            }
            
            if let hasPassword = response.hasPassword, !hasPassword {
                emailValidationMessage = "Tài khoản dùng đăng nhập mạng xã hội, không có mật khẩu"
                isEmailExistenceVerified = false
                return
            }
            
            // All checks passed
            emailValidationMessage = nil
            isEmailExistenceVerified = true
            
        } catch {
            Logger.error("Check email exists failed: \(error)", category: "Auth")
            emailValidationMessage = "Không thể kiểm tra email"
            isEmailExistenceVerified = false
        }
    }

    // Actions
    public func sendOtp() async {
        // Kiểm tra có thể gửi OTP không
        guard canSendOTP else {
            if !isEmailValid {
                alert = .general(title: "Lỗi", message: "Email không hợp lệ")
            } else if !isEmailExistenceVerified {
                alert = .general(title: "Lỗi", message: "Email không tồn tại trong hệ thống")
            }
            return
        }

        isSendingOTP = true
        defer { isSendingOTP = false }

        do {
            try await otpHandler.sendOTP(to: email, purpose: .resetPassword)
            withAnimation {
                step = .inputOtp
            }
            alert = .general(title: "Thành công", message: "Mã OTP đã được gửi đến email của bạn")
        } catch {
            Logger.error("Send OTP Failed: \(error)", category: "Auth")
            alert = .general(title: "Lỗi", message: error.localizedDescription)
        }
    }

    public func verifyOtp() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await otpHandler.verifyOTP(
                email: email,
                code: otpCode,
                purpose: .resetPassword
            )
            resetToken = response.registrationToken  // Reuse field but it is RESET_TOKEN
            withAnimation {
                step = .resetPassword
            }
        } catch let error as OTPInputHandler.OTPError {
            Logger.error("Verify OTP Failed: \(error)", category: "Auth")
            alert = .general(title: "Lỗi", message: error.localizedDescription)
        } catch {
            Logger.error("Verify OTP Failed: \(error)", category: "Auth")
            alert = .general(title: "Lỗi", message: "Mã OTP không đúng hoặc đã hết hạn")
        }
    }

    public func resetPassword() async {
        guard !password.isEmpty, !confirmPassword.isEmpty else {
            alert = .general(title: "Lỗi", message: "Vui lòng nhập đầy đủ thông tin")
            return
        }

        guard password == confirmPassword else {
            alert = .general(title: "Lỗi", message: "Mật khẩu xác nhận không khớp")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await useCase.resetPassword(
                password: password, confirmPassword: confirmPassword, token: resetToken)
            isSuccess = true
            alert = .general(title: "Thành công", message: "Mật khẩu đã được đặt lại thành công!")
            // onSuccess được gọi khi user bấm OK trên alert (trong handleSuccessAlertDismissed)
        } catch {
            Logger.error("Reset Password Failed: \(error)", category: "Auth")
            alert = .general(title: "Lỗi", message: error.localizedDescription)
        }
    }

    /// Gọi khi user bấm OK trên alert (để quay về Login sau khi đổi mật khẩu thành công).
    public func handleSuccessAlertDismissed() {
        if isSuccess {
            onSuccess(email)
            isSuccess = false
        }
    }
}

public enum ForgotPasswordStep {
    case inputEmail
    case inputOtp
    case resetPassword
}
