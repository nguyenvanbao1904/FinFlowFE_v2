//
//  DependencyContainer+Identity.swift
//  FinFlowIos
//
//  Created by FinFlow Agent on 03/02/26.
//

import FinFlowCore
import Identity
import Foundation

// MARK: - Identity Feature Factories
extension DependencyContainer {
    
    // MARK: - ViewModels
    
    func makeLoginViewModel(router: any AppRouterProtocol) -> LoginViewModel {
        return LoginViewModel(
            loginUseCase: LoginUseCase(repository: authRepository),
            sessionManager: sessionManager,
            router: router
        )
    }

    func makeRegisterViewModel() -> RegisterViewModel {
        return RegisterViewModel(
            registerUseCase: RegisterUseCase(repository: authRepository),
            loginUseCase: LoginUseCase(repository: authRepository),
            sessionManager: sessionManager
        )
    }

    func makeForgotPasswordViewModel() -> ForgotPasswordViewModel {
        return ForgotPasswordViewModel(useCase: ForgotPasswordUseCase(repository: authRepository))
    }
    
    // MARK: - Use Cases
    
    func makeLoginUseCase() -> LoginUseCaseProtocol {
        return LoginUseCase(repository: authRepository)
    }

    func makeLogoutUseCase() -> LogoutUseCaseProtocol {
        return LogoutUseCase(repository: authRepository)
    }
    
    // MARK: - Repositories
    
    func makeAuthRepository() -> AuthRepositoryProtocol {
        return authRepository
    }
}
