import SwiftUI
import Observation
import FinFlowCore
import OSLog

@MainActor
@Observable
public final class AppRouter: AppRouterProtocol {
    public var activeTab: AppTab = .home
    public var homePath: [AppRoute] = []
    public var transactionPath: [AppRoute] = []
    public var planningPath: [AppRoute] = []
    public var wealthPath: [AppRoute] = []
    public var investmentPath: [AppRoute] = []
    public var authPath: [AppRoute] = []
    
    public var root: AppRoot = .splash
    public var presentedSheet: AppRoute?
    
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

        // Ensure no orphan sheet remains when session/root transitions.
        switch state {
        case .authenticated:
            break
        default:
            presentedSheet = nil
        }

        switch state {
        case .authenticated:
            root = .dashboard
            homePath = []
            transactionPath = []
            planningPath = []
            wealthPath = []
            investmentPath = []
            authPath = []
        case .welcomeBack:
            root = .welcomeBack
            authPath = []
        case .unauthenticated, .sessionExpired:
            root = .authentication
            authPath = []
        case .loading, .refreshing:
            root = .splash
        case .locked:
            root = .locked
        }
    }

    private var currentPath: Binding<[AppRoute]> {
        if root == .dashboard {
            switch activeTab {
            case .home:
                return Binding(get: { self.homePath }, set: { self.homePath = $0 })
            case .transaction:
                return Binding(get: { self.transactionPath }, set: { self.transactionPath = $0 })
            case .planning:
                return Binding(get: { self.planningPath }, set: { self.planningPath = $0 })
            case .wealth:
                return Binding(get: { self.wealthPath }, set: { self.wealthPath = $0 })
            case .investment:
                return Binding(get: { self.investmentPath }, set: { self.investmentPath = $0 })
            }
        } else {
            return Binding(get: { self.authPath }, set: { self.authPath = $0 })
        }
    }

    public func navigate(to route: AppRoute) {
        currentPath.wrappedValue.append(route)
    }

    public func pop() {
        guard !currentPath.wrappedValue.isEmpty else { return }
        currentPath.wrappedValue.removeLast()
    }

    public func popToRoot() {
        currentPath.wrappedValue = []
    }

    public func replacePath(with routes: [AppRoute]) {
        currentPath.wrappedValue = routes
    }

    public func navigateToDeepLink(_ routes: [AppRoute]) {
        currentPath.wrappedValue = routes
    }
    
    public func presentSheet(_ route: AppRoute) {
        presentedSheet = route
    }
    
    public func dismissSheet() {
        presentedSheet = nil
    }

    public func selectTab(_ tab: AppTab) {
        if presentedSheet != nil {
            dismissSheet()
        }
        activeTab = tab
    }
}
