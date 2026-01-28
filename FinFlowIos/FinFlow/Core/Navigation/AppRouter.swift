//
//  AppRouter.swift
//  FinFlowIos
//

import Combine
import FinFlowCore
import SwiftUI

@MainActor
public final class AppRouter: AppRouterProtocol {
    @Published public var path = NavigationPath()
    @Published public var isAuthenticated = false

    private let sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()

    public init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        Logger.info("🧭 AppRouter initialized", category: "Navigation")
        observeSessionState()
    }

    private func observeSessionState() {
        sessionManager.$state
            .sink { [weak self] state in
                guard let self = self else { return }
                Logger.info("🧭 Session: \(state)", category: "Navigation")

                switch state {
                case .authenticated:
                    if !self.isAuthenticated { self.showMainFlow() }
                case .unauthenticated, .sessionExpired:
                    if self.isAuthenticated { self.showAuthFlow() }
                case .loading, .refreshing:
                    break
                }
            }
            .store(in: &cancellables)
    }

    public func navigate(to route: AppRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path = NavigationPath()
    }

    public func replacePath(with routes: [AppRoute]) {
        path = NavigationPath(routes)
    }

    public func showMainFlow() {
        Logger.info("🔐 Main flow", category: "Navigation")
        isAuthenticated = true
        path = NavigationPath()
    }

    public func showAuthFlow() {
        Logger.info("🔓 Auth flow", category: "Navigation")
        isAuthenticated = false
        path = NavigationPath()
    }

    public func navigateToDeepLink(_ routes: [AppRoute]) {
        path = NavigationPath(routes)
    }
}
