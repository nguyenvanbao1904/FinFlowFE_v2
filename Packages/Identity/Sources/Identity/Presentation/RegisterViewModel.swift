import Combine
import FinFlowCore
import Foundation
import SwiftUI

@MainActor
public class RegisterViewModel: ObservableObject {
    // Form fields
    @Published public var username = ""
    @Published public var email = ""
    @Published public var password = ""
    @Published public var passwordConfirmation = ""
    @Published public var firstName = ""
    @Published public var lastName = ""
    @Published public var dob = Date()

    // State

    // Email Verification State
    @Published public var otpCode = ""
    @Published public var showOTPInput = false
    @Published public var isEmailVerified = false
    @Published public var isSendingOTP = false
    
    // Computed property for validation UI
    public var isEmailValid: Bool {
        let emailRegEx = "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    // State
    @Published public var isLoading = false
    @Published public var alert: AppErrorAlert? = nil
    @Published public var isRegistrationSuccess = false

    private let registerUseCase: RegisterUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let sessionManager: SessionManager

    public init(
        registerUseCase: RegisterUseCaseProtocol,
        loginUseCase: LoginUseCaseProtocol,
        sessionManager: SessionManager
    ) {
        self.registerUseCase = registerUseCase
        self.loginUseCase = loginUseCase
        self.sessionManager = sessionManager
    }

    // Mock Send OTP
    public func sendOTP() async {
        guard isEmailValid else { return }
        isSendingOTP = true
        // Mock API delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isSendingOTP = false
        showOTPInput = true
    }

    // Mock Verify OTP
    public func verifyOTP() async {
        guard !otpCode.isEmpty else { return }
        // Mock verification
        try? await Task.sleep(nanoseconds: 500_000_000)
        if otpCode == "123456" { // Hardcode for demo
            showOTPInput = false
            isEmailVerified = true
            alert = .general(title: "Thành công", message: "Email đã được xác thực")
        } else {
            alert = .general(title: "Lỗi", message: "Mã OTP không đúng (Demo: 123456)")
        }
    }

    public func register() async {
        // 1. Basic UI Validation
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty, !passwordConfirmation.isEmpty else {
            self.alert = .general(title: "Thông báo", message: "Vui lòng điền đầy đủ thông tin bắt buộc")
            return
        }

        guard password == passwordConfirmation else {
            self.alert = .general(title: "Lỗi", message: "Mật khẩu xác nhận không khớp")
            return
        }
        
        guard isEmailVerified else {
            self.alert = .general(title: "Thông báo", message: "Vui lòng xác thực email trước khi đăng ký")
            return
        }

        // Email format validation could be added here or rely on Backend

        isLoading = true
        defer { isLoading = false }

        // 2. Prepare Request
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dobString = dateFormatter.string(from: dob)

        let request = RegisterRequest(
            username: username,
            email: email,
            password: password,
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName,
            dob: dobString
        )

        // 3. Call UseCase
        do {
            try await registerUseCase.execute(request: request)
            Logger.info("Registration API success, attempting auto-login...", category: "Auth")
            
            // 4. Auto Login
            let loginResponse = try await loginUseCase.execute(username: username, password: password)
            await sessionManager.login(response: loginResponse)
            
            // Success! Session update triggers Router to switch to Dashboard automatically.
        } catch {
            Logger.error("Register/Login failed: \(error)", category: "Auth")
            if let appError = error as? AppError {
                self.alert = .auth(message: appError.localizedDescription)
            } else {
                self.alert = .general(title: "Lỗi", message: error.localizedDescription)
            }
        }
    }
}
