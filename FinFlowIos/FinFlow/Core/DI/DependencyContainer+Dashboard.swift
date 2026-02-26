//
//  DependencyContainer+Dashboard.swift
//  FinFlowIos

import Dashboard
import FinFlowCore
import Foundation
import Identity

// MARK: - Dashboard Feature Factories
extension DependencyContainer {

    func makeDashboardContainerViewModel(router: any AppRouterProtocol) -> DashboardContainerViewModel {
        return DashboardContainerViewModel(
            getProfileUseCase: GetProfileUseCase(repository: authRepository),
            authRepository: authRepository,
            logoutUseCase: LogoutUseCase(repository: authRepository),
            sessionManager: sessionManager,  // Now uses SessionManagerProtocol
            router: router,
            pinManager: pinManager,          // Now uses PINManagerProtocol
            otpHandler: otpHandler
        )
    }
}
