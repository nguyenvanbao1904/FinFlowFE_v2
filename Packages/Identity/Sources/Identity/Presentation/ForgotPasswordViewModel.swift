import Combine
import FinFlowCore
import Foundation
import SwiftUI

@MainActor
@Observable
public class ForgotPasswordViewModel {
    // Form Data
    public var email = "" {
        didSet { validateEmailDebounced() }
    }
    public var otpCode = ""
    public var password = ""
    public var confirmPassword = ""
    
    // UI State
    public var step: ForgotPasswordStep = .inputEmail
    public var isLoading = false
    public var alert: AppErrorAlert? = nil
    public var isSuccess = false
    
    // Data
    private var resetToken = ""
    
    public var isEmailExistenceVerified = false
    public var emailValidationMessage: String? = nil
    
    private let useCase: ForgotPasswordUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public init(useCase: ForgotPasswordUseCaseProtocol) {
        self.useCase = useCase
        setupEmailDebounce()
    }
    
    private func setupEmailDebounce() {
        // No-op or removed, logic moved to didSet
    }

    private var emailValidationTask: Task<Void, Never>?
    private func validateEmailDebounced() {
        emailValidationTask?.cancel()
        emailValidationTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            await checkEmail(email)
        }
    }
    
    private func checkEmail(_ email: String) async {
        guard !email.isEmpty else {
            isEmailExistenceVerified = false
            emailValidationMessage = nil
            return
        }
        
        let emailRegEx = "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        guard emailPred.evaluate(with: email) else {
            isEmailExistenceVerified = false
            emailValidationMessage = "Email không đúng định dạng"
            return
        }
        
        // Perform API Check
        do {
            let exists = try await useCase.checkUserExistence(email: email)
            await MainActor.run {
                if exists {
                    self.isEmailExistenceVerified = true
                    self.emailValidationMessage = nil // Valid
                } else {
                    self.isEmailExistenceVerified = false
                    self.emailValidationMessage = "Email không tồn tại trong hệ thống"
                }
            }
        } catch {
            Logger.error("Check email existence failed: \(error)", category: "Auth")
            // On error, maybe allow retry or assume false? safer to assume false
            await MainActor.run {
                self.isEmailExistenceVerified = false
                self.emailValidationMessage = "Lỗi kiểm tra email: \(error.localizedDescription)"
            }
        }
    }
    
    // Actions
    public func sendOtp() async {
        guard isEmailExistenceVerified else {
            alert = .general(title: "Lỗi", message: emailValidationMessage ?? "Email không hợp lệ")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await useCase.sendOtp(email: email)
            withAnimation {
                step = .inputOtp
            }
        } catch {
            Logger.error("Send OTP Failed: \(error)", category: "Auth")
            alert = .general(title: "Lỗi", message: error.localizedDescription)
        }
    }
    
    public func verifyOtp() async {
        guard !otpCode.isEmpty else {
            alert = .general(title: "Lỗi", message: "Vui lòng nhập mã OTP")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await useCase.verifyOtp(email: email, otp: otpCode)
            resetToken = response.registrationToken // Reuse field but it is RESET_TOKEN
            withAnimation {
                step = .resetPassword
            }
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
            try await useCase.resetPassword(password: password, confirmPassword: confirmPassword, token: resetToken)
            isSuccess = true // Trigger navigation back or success view
            alert = .general(title: "Thành công", message: "Mật khẩu đã được đặt lại thành công!")
        } catch {
             Logger.error("Reset Password Failed: \(error)", category: "Auth")
             alert = .general(title: "Lỗi", message: error.localizedDescription)
        }
    }
}

public enum ForgotPasswordStep {
    case inputEmail
    case inputOtp
    case resetPassword
}
