//
//  DependencyContainer+Identity.swift
//  FinFlowIos

import FinFlowCore
import Foundation
import Identity

// MARK: - Identity Feature Factories
extension DependencyContainer {

    // MARK: - ViewModels

    func makeLoginViewModel(router: any AppRouterProtocol) -> LoginViewModel {
        return LoginViewModel(
            loginUseCase: LoginUseCase(repository: authRepository),
            sessionManager: sessionManager,
            router: router,
            pinManager: pinManager,
            userDefaults: userDefaultsManager,
            biometricAuth: SessionBiometricAuthCoordinator()
        )
    }

    func makeRegisterViewModel(
        onSuccess: @escaping (String) -> Void,
        onNavigateToLogin: @escaping () -> Void
    ) -> RegisterViewModel {
        return RegisterViewModel(
            registerUseCase: RegisterUseCase(repository: authRepository),
            loginUseCase: LoginUseCase(repository: authRepository),
            sessionManager: sessionManager,
            otpHandler: otpHandler,
            onRegistrationSuccess: onSuccess,
            onNavigateToLogin: onNavigateToLogin
        )
    }

    func makeForgotPasswordViewModel(onSuccess: @escaping (String) -> Void)
        -> ForgotPasswordViewModel {
        return ForgotPasswordViewModel(
            useCase: ForgotPasswordUseCase(repository: authRepository),
            otpHandler: otpHandler,
            onSuccess: onSuccess
        )
    }

    func makeWelcomeBackViewModel(
        email: String,
        firstName: String?,
        lastName: String?,
        onSwitchAccount: @escaping () -> Void
    ) -> WelcomeBackViewModel {
        return WelcomeBackViewModel(
            email: email,
            firstName: firstName,
            lastName: lastName,
            sessionManager: sessionManager,
            authRepository: authRepository,
            otpHandler: otpHandler,
            onSwitchAccount: onSwitchAccount
        )
    }

    func makeLockScreenViewModel(user: UserProfile, biometricAvailable: Bool) -> LockScreenViewModel {
        return LockScreenViewModel(
            sessionManager: sessionManager,
            pinManager: pinManager,
            user: user,
            biometricAvailable: biometricAvailable
        )
    }
}
