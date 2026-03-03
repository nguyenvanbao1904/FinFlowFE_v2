//
//  NavigationTypes.swift
//  FinFlowCore


import SwiftUI

@MainActor
public protocol AppRouterProtocol: AnyObject {
    var path: NavigationPath { get set }
    var root: AppRoot { get }
    var presentedSheet: AppRoute? { get set }
    
    /// Navigate to a specific route
    func navigate(to route: AppRoute)

    /// Go back one screen
    func pop()

    /// Return to root screen
    func popToRoot()

    /// Replace entire navigation stack
    func replacePath(with routes: [AppRoute])

    /// Navigate to specific screen with multiple routes (for deep linking)
    func navigateToDeepLink(_ routes: [AppRoute])
    
    /// Present a global sheet
    func presentSheet(_ route: AppRoute)
    
    /// Dismiss the global sheet
    func dismissSheet()
}

public enum AppRoot: Equatable, Sendable {
    case splash
    case authentication
    case welcomeBack
    case dashboard
    case locked
}

/// Centralized enum for all navigation destinations.
/// Lives in Core to prevent circular dependencies.
public enum AppRoute: Hashable, Sendable {
    // MARK: - Authentication Flow
    case login
    case register
    case forgotPassword
    
    // MARK: - Main Flow
    case dashboard
    case profile
    case settings
    case transactionDetail(id: String)
    case updateProfile(UserProfile)
    case changePassword(hasPassword: Bool)
    case createPIN(email: String)
    case addTransaction
}

extension AppRoute: Identifiable {
    public var id: Int { hashValue }
}
