//
//  LoginViewModel.swift
//  Identity
//

import Combine
import FinFlowCore
import SwiftUI
import GoogleSignIn

@MainActor
@Observable
public class LoginViewModel {
    public var username = ""
    public var password = ""
    public var isLoading = false
    public var alert: AppErrorAlert? = nil

    private let loginUseCase: LoginUseCaseProtocol
    private let sessionManager: SessionManager
    private let router: any AppRouterProtocol

    public init(
        loginUseCase: LoginUseCaseProtocol,
        sessionManager: SessionManager,
        router: any AppRouterProtocol
    ) {
        self.loginUseCase = loginUseCase
        self.sessionManager = sessionManager
        self.router = router
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
            // Map Error to AppErrorAlert
            // Map Error to AppErrorAlert
            if let appError = error as? AppError {
                self.alert = .auth(message: appError.localizedDescription)
            } else {
                self.alert = .general(title: "Lỗi", message: error.localizedDescription)
            }
        }

        isLoading = false
    }

    public func handleGoogleLogin() async {
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .first(where: { $0 is UIWindowScene }) as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AppError.unknown // Or specific error
            }
            
            let response = try await loginUseCase.executeGoogle(idToken: idToken)
            await sessionManager.login(response: response)
            Logger.info("Google Login success", category: "Auth")
        } catch {
            Logger.error("Google Login failed: \(error)", category: "Auth")
             // Map Error to AppErrorAlert
            if let appError = error as? AppError {
                self.alert = .auth(message: appError.localizedDescription)
            } else {
                 // Ignore cancellation error if needed, or show generic
                self.alert = .general(title: "Lỗi Google Login", message: error.localizedDescription)
            }
        }
    }

    public func handleAppleLogin() {
        self.alert = .general(title: "Thông báo", message: "Tính năng đăng nhập bằng Apple sẽ sớm được cập nhật.")
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
}
