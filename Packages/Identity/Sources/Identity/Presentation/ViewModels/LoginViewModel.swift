//
//  LoginViewModel.swift
//  Identity
//

import Combine
import FinFlowCore
import LocalAuthentication
import SwiftUI

@MainActor
@Observable
public class LoginViewModel {
    public var username = ""
    public var password = ""
    public var isLoading = false
    public var alert: AppErrorAlert? = nil
    public var isSessionExpired = false
    public var userDisplayName: String?
    public var savedEmail: String?
    public var canUseBiometric = false
    public var biometricType: LABiometryType = .none

    private let loginUseCase: LoginUseCaseProtocol
    private let sessionManager: any SessionManagerProtocol
    private let pinManager: any PINManagerProtocol
    private let userDefaults: any UserDefaultsManagerProtocol
    private let biometricAuth: any BiometricAuthHandling
    // Keep a strong reference to router to avoid deallocation-related crashes
    private let router: any AppRouterProtocol

    public init(
        loginUseCase: LoginUseCaseProtocol,
        sessionManager: any SessionManagerProtocol,
        router: any AppRouterProtocol,
        pinManager: any PINManagerProtocol,
        userDefaults: any UserDefaultsManagerProtocol,
        biometricAuth: any BiometricAuthHandling
    ) {
        self.loginUseCase = loginUseCase
        self.sessionManager = sessionManager
        self.router = router
        self.pinManager = pinManager
        self.userDefaults = userDefaults
        self.biometricAuth = biometricAuth

        Task {
            await loadSavedUserInfo()
            await checkBiometricAvailability()
        }
    }

    /// Gọi khi view xuất hiện để đọc lại email/username từ UserDefaults (vd: sau quên mật khẩu).
    public func refreshSavedUserInfo() async {
        await loadSavedUserInfo()
    }

    /// Prefill greeting + email từ UserDefaults (dù có sessionExpired hay không)
    private func loadSavedUserInfo() async {
        let savedUsername = await userDefaults.getUsername()
        let email = await userDefaults.getEmail()
        let firstName = await userDefaults.getFirstName()
        let lastName = await userDefaults.getLastName()

        if let email {
            username = email
            savedEmail = email
        } else if let savedUsername {
            username = savedUsername
        }

        if let first = firstName, let last = lastName {
            userDisplayName = "\(first) \(last)"
        } else if let first = firstName {
            userDisplayName = first
        } else if let last = lastName {
            userDisplayName = last
        } else if let email {
            userDisplayName = email.components(separatedBy: "@").first
        }
    }

    /**
     Perform login
    
     Pattern: UseCase (business logic in UseCase)
     - UI validation here (empty check)
     - Business validation in UseCase (trim, sanitize)
     - SessionManager updates global state
     - Router navigation happens automatically via SessionManager observer
     */
    public func login() async {
        guard !username.isEmpty, !password.isEmpty else {
            self.alert = .general(title: "Thông báo", message: "Vui lòng nhập đầy đủ thông tin")
            return
        }

        isLoading = true

        do {
            let response = try await loginUseCase.execute(username: username, password: password)
            await sessionManager.login(response: response)
            Logger.info("🎯 Login success", category: "Auth")
        } catch {
            Logger.error("Đăng nhập thất bại: \(error)", category: "Auth")
            self.alert = error.toAppAlert(defaultTitle: "Lỗi")
        }

        isLoading = false
    }

    public func loginWithGoogle(idToken: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await loginUseCase.executeGoogle(idToken: idToken)
            await sessionManager.login(response: response)
            Logger.info("Google Login success", category: "Auth")
        } catch {
            Logger.error("Google Login failed: \(error)", category: "Auth")
            self.alert = error.toAppAlert(defaultTitle: "Lỗi Google Login")
        }
    }

    public func handleAppleLogin() {
        self.alert = .general(
            title: "Thông báo", message: "Tính năng đăng nhập bằng Apple sẽ sớm được cập nhật.")
    }

    public func navigateToRegister() {
        router.navigate(to: .register)
    }

    public func navigateToForgotPassword() {
        router.navigate(to: .forgotPassword)
    }

    public func clearForm() {
        username = ""
        password = ""
    }

    // MARK: - Biometric Authentication

    /// Kiểm tra xem thiết bị có hỗ trợ sinh trắc học không
    public func checkBiometricAvailability() async {
        let context = LAContext()
        var error: NSError?

        // Chỉ kiểm tra thiết bị có hỗ trợ biometric không
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else {
            canUseBiometric = false
            Logger.info("🔐 Biometric not available on device", category: "Auth")
            return
        }

        biometricType = context.biometryType
        canUseBiometric = true

        Logger.info(
            "🔐 Biometric available: \(biometricType == .faceID ? "Face ID" : "Touch ID")",
            category: "Auth")
    }

    private func ensureBiometricAvailableNow() -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            canUseBiometric = false
            alert = .general(
                title: "Thiết bị không hỗ trợ",
                message: "Thiết bị của bạn không hỗ trợ Face ID / Touch ID.")
            return false
        }
        biometricType = context.biometryType
        canUseBiometric = true
        return true
    }

    /// Đăng nhập bằng sinh trắc học
    public func loginWithBiometric() async {
        guard ensureBiometricAvailableNow() else { return }

        // Hiển thị loading trong lúc Face ID/Touch ID + refresh token silent
        isLoading = true
        defer { isLoading = false }

        let alertResult = await biometricAuth.authenticate(
            sessionManager: sessionManager,
            userDefaults: userDefaults,
            options: BiometricAuthHandler.Copy.login
        )

        if let alertResult {
            alert = alertResult
        } else {
            Logger.info("✅ Biometric authentication successful", category: "Auth")
        }
    }
}
