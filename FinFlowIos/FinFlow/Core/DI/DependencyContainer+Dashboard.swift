//
//  DependencyContainer+Dashboard.swift
//  FinFlowIos
//
//  Created by FinFlow Agent on 03/02/26.
//

import Dashboard
import FinFlowCore
import Foundation
import Identity

// MARK: - Dashboard Feature Factories
extension DependencyContainer {
    
    func makeDashboardViewModel(router: any AppRouterProtocol) -> DashboardViewModel {
        return DashboardViewModel(
            getProfileUseCase: GetProfileUseCase(repository: authRepository),
            authRepository: authRepository,
            logoutUseCase: LogoutUseCase(repository: authRepository),
            sessionManager: sessionManager,
            router: router
        )
    }
}
