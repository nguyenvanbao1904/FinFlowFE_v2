//
//  NavigationTypes.swift
//  FinFlowCore
//
//  Centralized navigation contracts to avoid circular dependencies.
//  Parent app knows children, but children never know the parent.
//  Protocol + enum live in Core so every module can depend on them safely.
//

import SwiftUI

/// Router Protocol for Dependency Injection
///
/// Dependency Inversion:
/// - FinFlowCore defines the protocol + routes
/// - FinFlowIos implements the protocol (AppRouter)
/// - Feature modules (Identity, Dashboard, ...) depend only on the protocol
@MainActor
public protocol AppRouterProtocol: ObservableObject {
    /// Navigate to a specific route
    func navigate(to route: AppRoute)

    /// Go back one screen
    func pop()

    /// Return to root screen
    func popToRoot()

    /// Replace entire navigation stack
    func replacePath(with routes: [AppRoute])

    /// Switch to authenticated state (show main app)
    func showMainFlow()

    /// Switch to unauthenticated state (show login)
    func showAuthFlow()

    /// Navigate to specific screen with multiple routes (for deep linking)
    func navigateToDeepLink(_ routes: [AppRoute])
}

/// Centralized enum for all navigation destinations.
/// Lives in Core to prevent circular dependencies.
public enum AppRoute: Hashable, Sendable {
    // MARK: - Authentication Flow
    case login
    case register
    case forgotPassword
    case verifyOTP(email: String)

    // MARK: - Main Flow
    case dashboard
    case profile
    case settings

    // MARK: - Transactions
    case transactions
    case transactionDetail(id: String)
    case createTransaction

    // MARK: - Budgets
    case budgets
    case budgetDetail(id: String)
    case createBudget
}

