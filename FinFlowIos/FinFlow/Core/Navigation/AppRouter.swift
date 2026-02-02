import FinFlowCore
import SwiftUI

@MainActor
@Observable
public final class AppRouter: AppRouterProtocol {
    public var path = NavigationPath()
    public var isAuthenticated = false

    private let sessionManager: SessionManager

    public init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        Logger.info("🧭 AppRouter initialized", category: "Navigation")
        startSessionObservation()
    }

    private func startSessionObservation() {
        Task { [weak self] in
            guard let self = self else { return }
            
            // ✅ Clean, strict concurrency consistent observation
            // Using the AsyncStream exposed by SessionManager
            for await state in self.sessionManager.stateStream {
                self.handleStateChange(state)
            }
        }
    }
    
    private func handleStateChange(_ state: SessionManager.SessionState) {
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
        isAuthenticated = true
        path = NavigationPath()
    }

    public func showAuthFlow() {
        isAuthenticated = false
        path = NavigationPath()
    }

    public func navigateToDeepLink(_ routes: [AppRoute]) {
        path = NavigationPath(routes)
    }
}
