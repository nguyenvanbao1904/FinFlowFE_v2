import SwiftUI
import Observation
import FinFlowCore
import OSLog



@MainActor
@Observable
public final class AppRouter: AppRouterProtocol {
    public var path = NavigationPath()
    public var root: AppRoot = .splash
    
    // Legacy support (computed)
    public var isAuthenticated: Bool {
        root == .dashboard
    }

    private let sessionManager: any SessionManagerProtocol

    public init(sessionManager: any SessionManagerProtocol) {
        self.sessionManager = sessionManager
        Logger.info("AppRouter initialized", category: "Navigation")
        startSessionObservation()
    }

    private func startSessionObservation() {
        withObservationTracking {
            // Register observation by accessing the property
            self.handleStateChange(self.sessionManager.state)
        } onChange: { [weak self] in
            // Schedule re-observation on change
            Task { @MainActor [weak self] in
                self?.startSessionObservation()
            }
        }
    }

    private func handleStateChange(_ state: SessionState) {
        Logger.info("Session: \(state)", category: "Navigation")

        switch state {
        case .authenticated:
            root = .dashboard
            path = NavigationPath()
        case .welcomeBack:
            root = .welcomeBack
            path = NavigationPath()
        case .unauthenticated, .sessionExpired:
            root = .authentication
            path = NavigationPath()
        case .loading, .refreshing:
            root = .splash
        case .locked:
            root = .locked
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

    public func navigateToDeepLink(_ routes: [AppRoute]) {
        path = NavigationPath(routes)
    }
}
