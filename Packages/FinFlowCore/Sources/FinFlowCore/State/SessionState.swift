import Foundation

/// Session state representing the authentication status
public enum SessionState: Equatable, Sendable {
    case loading
    case authenticated(token: String, isRestored: Bool = false)
    case unauthenticated
    case welcomeBack(email: String, firstName: String?, lastName: String?)
    case refreshing
    case sessionExpired(email: String, firstName: String?, lastName: String?)
    case locked(user: UserProfile, biometricAvailable: Bool)

    public var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}
