import FinFlowCore
import Observation
import SwiftUI

@MainActor
@Observable
public final class RegisterViewModel {
    // Form fields
    public var username = "" {
        didSet {
            guard username != oldValue else { return }
            usernameDebounceTask?.cancel()
            usernameDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { return }
                await self.checkUsernameAvailability(self.username)
            }
        }
    }
    public var email = "" {
        didSet {
            // Tránh reset khi không thực sự thay đổi
            guard email != oldValue else { return }

            // Reset states khi email thay đổi
            isEmailVerified = false
            showOTPInput = false
            otpCode = ""
            emailValidationMessage = nil

            // Trigger debounced validation
            emailDebounceTask?.cancel()
            emailDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { return }
                await self.validateEmail(self.email)
            }
        }
    }

    public var password = ""
    public var passwordConfirmation = ""
    public var firstName = "" {
        didSet {
            if !firstName.isEmpty { firstNameMessage = nil }
        }
    }
    public var lastName = "" {
        didSet {
            if !lastName.isEmpty { lastNameMessage = nil }
        }
    }
    public var dob = Date()

    // State

    // Email Verification State
    public var otpCode = "" {
        didSet {
            Task {
                let formatted = await otpHandler.formatInput(otpCode)
                if formatted != otpCode {
                    otpCode = formatted
                }
            }
        }
    }
    public var showOTPInput = false
    public var isEmailVerified = false
    public var isSendingOTP = false
    public var otpCooldownRemaining = 0
    public var registrationToken = ""

    // Email Validation State
    public var isCheckingEmail = false
    public var emailValidationMessage: String?
    public var isEmailAvailable = false
    public var isCheckingUsername = false
    public var isUsernameAvailable = false

    public var isEmailValid: Bool {
        let emailRegEx = "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    // Computed: Có thể gửi OTP không?
    public var canSendOTP: Bool {
        return isEmailValid && isEmailAvailable && !isCheckingEmail && !isEmailVerified
            && otpCooldownRemaining == 0
    }

    // Computed: Form ready to register
    public var isFormValid: Bool {
        return !username.isEmpty
            && isEmailVerified
            && isEmailValid
            && isEmailAvailable
            && isUsernameAvailable
            && !password.isEmpty
            && password == passwordConfirmation
            && !firstName.isEmpty
            && !lastName.isEmpty
    }

    public var isLoading = false
    public var alert: AppErrorAlert?
    public var isRegistrationSuccess = false

    private let registerUseCase: RegisterUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let sessionManager: any SessionManagerProtocol
    private let otpHandler: OTPInputHandler
    private let onRegistrationSuccess: (String) -> Void
    private let onNavigateToLogin: () -> Void

    // Field validation messages
    public var usernameMessage: String?
    public var firstNameMessage: String?
    public var lastNameMessage: String?
    public var passwordMessage: String?
    public var passwordConfirmationMessage: String?

    private var emailDebounceTask: Task<Void, Never>?
    private var usernameDebounceTask: Task<Void, Never>?
    private var otpCooldownTask: Task<Void, Never>?

    public init(
        registerUseCase: RegisterUseCaseProtocol,
        loginUseCase: LoginUseCaseProtocol,
        sessionManager: any SessionManagerProtocol,
        otpHandler: OTPInputHandler,
        onRegistrationSuccess: @escaping (String) -> Void = { _ in },
        onNavigateToLogin: @escaping () -> Void = {}
    ) {
        self.registerUseCase = registerUseCase
        self.loginUseCase = loginUseCase
        self.sessionManager = sessionManager
        self.otpHandler = otpHandler
        self.onRegistrationSuccess = onRegistrationSuccess
        self.onNavigateToLogin = onNavigateToLogin
    }

    // MARK: - Field Validation

    public enum Field {
        case username
        case firstName
        case lastName
        case password
        case passwordConfirmation
    }

    public func validate(_ field: Field) {
        switch field {
        case .username:
            usernameMessage = Self.validateRequired(username, name: "Tên đăng nhập")
                ?? (username.contains(where: { $0.isWhitespace }) ? "Tên đăng nhập không được chứa khoảng trắng" : nil)
        case .firstName:
            firstNameMessage = Self.validateRequired(firstName, name: "Họ")
        case .lastName:
            lastNameMessage = Self.validateRequired(lastName, name: "Tên")
        case .password:
            passwordMessage = Self.validateRequired(password, name: "Mật khẩu")
        case .passwordConfirmation:
            passwordConfirmationMessage = Self.validateRequired(passwordConfirmation, name: "Vui lòng nhập lại mật khẩu", emptyMessage: "Vui lòng nhập lại mật khẩu")
                ?? (passwordConfirmation != password ? "Mật khẩu xác nhận không khớp" : nil)
        }
    }

    private static func validateRequired(_ value: String, name: String, emptyMessage: String? = nil) -> String? {
        value.isEmpty ? (emptyMessage ?? "\(name) không được để trống") : nil
    }

    private func validateEmail(_ email: String) async {
        // Reset state
        emailValidationMessage = nil
        isEmailAvailable = false

        // Kiểm tra empty
        guard !email.isEmpty else {
            return
        }

        // Kiểm tra format
        guard isEmailValid else {
            emailValidationMessage = "Email không hợp lệ"
            isEmailAvailable = false
            return
        }

        // Kiểm tra email đã tồn tại chưa
        isCheckingEmail = true
        defer { isCheckingEmail = false }

        do {
            let exists = try await registerUseCase.checkEmailExists(email: email)

            if exists {
                emailValidationMessage = "Email này đã được đăng ký"
                isEmailAvailable = false
            } else {
                emailValidationMessage = nil
                isEmailAvailable = true
            }
        } catch {
            Logger.error("Check email exists failed: \(error)", category: "Auth")
            emailValidationMessage = "Không thể kiểm tra email"
            isEmailAvailable = false
        }
    }

    @MainActor
    private func checkUsernameAvailability(_ username: String) async {
        guard !username.isEmpty else {
            isUsernameAvailable = false
            return
        }

        // Only proceed if local validation passes
        guard usernameMessage == nil else {
            isUsernameAvailable = false
            return
        }

        isCheckingUsername = true
        defer { isCheckingUsername = false }

        do {
            let exists = try await registerUseCase.checkUsernameExists(username: username)

            if exists {
                usernameMessage = "Tên đăng nhập đã được sử dụng"
                isUsernameAvailable = false
            } else {
                usernameMessage = nil
                isUsernameAvailable = true
            }
        } catch {
            Logger.error("Check username exists failed: \(error)", category: "Auth")
            usernameMessage = "Không thể kiểm tra tên đăng nhập"
            isUsernameAvailable = false
        }
    }

    // Send OTP
    public func sendOTP() async {
        // Kiểm tra có thể gửi OTP không
        guard canSendOTP else {
            if !isEmailValid {
                alert = .general(title: "Lỗi", message: "Email không hợp lệ")
            } else if !isEmailAvailable {
                alert = .general(title: "Lỗi", message: "Email này đã được đăng ký trong hệ thống")
            } else if otpCooldownRemaining > 0 {
                alert = .general(
                    title: "Thông báo",
                    message: "Vui lòng chờ \(otpCooldownRemaining)s trước khi gửi lại OTP")
            }
            return
        }

        isSendingOTP = true
        defer { isSendingOTP = false }

        do {
            try await otpHandler.sendOTP(to: email, purpose: .register)
            // Success
            showOTPInput = true
            alert = .general(title: "Thành công", message: "Mã OTP đã được gửi đến email của bạn")
            startOtpCooldown()
        } catch {
            Logger.error("Send OTP failed: \(error)", category: "Auth")
            self.alert = error.toAppAlert(defaultTitle: "Lỗi Gửi OTP")
        }
    }

    // Verify OTP
    public func verifyOTP() async {
        do {
            let response = try await otpHandler.verifyOTP(
                email: email,
                code: otpCode,
                purpose: .register
            )

            // Success
            showOTPInput = false
            isEmailVerified = true
            registrationToken = response.registrationToken
            alert = .general(title: "Thành công", message: "Email đã được xác thực")
        } catch let error as OTPInputHandler.OTPError {
            Logger.error("Verify OTP failed: \(error)", category: "Auth")
            self.alert = .general(title: "Lỗi", message: error.localizedDescription)
        } catch {
            Logger.error("Verify OTP failed: \(error)", category: "Auth")
            self.alert = error.toAppAlert(defaultTitle: "Lỗi Xác Thực OTP")
        }
    }

    // MARK: - OTP Cooldown
    private func startOtpCooldown(seconds: Int = 60) {
        otpCooldownTask?.cancel()
        otpCooldownRemaining = seconds

        otpCooldownTask = Task { @MainActor in
            while otpCooldownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                otpCooldownRemaining -= 1
            }
        }
    }

    public func register() async {
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty, !passwordConfirmation.isEmpty
        else {
            self.alert = .general(
                title: "Thông báo", message: "Vui lòng điền đầy đủ thông tin bắt buộc")
            return
        }

        guard password == passwordConfirmation else {
            self.alert = .general(title: "Lỗi", message: "Mật khẩu xác nhận không khớp")
            return
        }

        guard isEmailVerified else {
            self.alert = .general(
                title: "Thông báo", message: "Vui lòng xác thực email trước khi đăng ký")
            return
        }

        isLoading = true
        defer { isLoading = false }

        // 2. Call UseCase — UseCase tự format dob và build RegisterRequest
        do {
            try await registerUseCase.execute(
                username: username,
                email: email,
                password: password,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                dob: dob,
                registrationToken: registrationToken
            )
            Logger.info("Registration API success, attempting auto-login...", category: "Auth")

            // 3. Auto Login
            let loginResponse = try await loginUseCase.execute(
                username: username, password: password)
            await sessionManager.login(response: loginResponse)

            // Success! Trigger dismiss callback
            isRegistrationSuccess = true
            onRegistrationSuccess(username)
        } catch {
            Logger.error("Register/Login failed: \(error)", category: "Auth")
            alert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Đăng Ký")
        }
    }

    // MARK: - Navigation

    public func navigateToLogin() {
        onNavigateToLogin()
    }
}
