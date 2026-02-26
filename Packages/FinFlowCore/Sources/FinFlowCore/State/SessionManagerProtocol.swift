import Foundation

/// Protocol defining session management responsibilities
/// Manages authentication state, user data, and session lifecycle
@MainActor
public protocol SessionManagerProtocol: AnyObject, Sendable {
    
    /// Current session state
    var state: SessionState { get }
    
    /// Currently authenticated user profile
    var currentUser: UserProfile? { get }
    
    /// Token store for biometric auth
    var tokenStore: any TokenStoreProtocol { get }

    /// Flag to indicate if biometric authentication is in progress (to suppress privacy blur)
    var isBiometricAuthenticationInProgress: Bool { get set }
    
    // MARK: - Auth Methods
    
    /// Handle successful login
    func login(response: LoginResponse) async
    
    /// Handle logout (keeps refresh token for restoration)
    func logout() async
    
    /// Complete logout (clears all tokens including refresh token)
    func logoutCompletely() async
    
    /// Refresh session with refresh token
    func refreshSession() async throws
    
    /// Refresh session silently without changing state
    func refreshSessionSilently() async throws -> String
    
    /// Restore session from saved tokens
    func restoreSession() async
    
    /// Mark session as expired and navigate to login
    func handleSessionExpired() async
    
    /// Check if refresh token is valid
    func isRefreshTokenValid() async -> Bool
    
    /// Finalize authentication with token
    func finalizeAuthentication(token: String) async
    
    // MARK: - User Data
    
    /// Update current user profile in memory
    func updateCurrentUser(_ user: UserProfile)

    /// Reload user profile from server
    func loadCurrentUser() async
    
    // MARK: - Security & PIN Methods
    
    /// Check if PIN exists for email
    func hasPIN(for email: String) async -> Bool
    
    /// Check if user has password
    func hasPassword() async -> Bool
    
    /// Authenticate with PIN
    func authenticateWithPIN(_ pin: String, email: String) async throws -> Bool
    
    /// Increment PIN fail counter and return status
    func incrementPINFailCounter(for email: String) async -> (allowed: Bool, attempts: Int, max: Int)
    
    /// Reset PIN fail counter
    func resetPINFailCounter(for email: String) async
    
    /// Delete PIN for email
    func deletePIN(for email: String) async
    
    /// Clear expired session (Delete Refresh Token, Keep User Info)
    func clearExpiredSession() async
    
    /// Lock the current session
    func lockSession() async
    
    /// Unlock the session
    func unlockSession() async
    
    /// Debug helper to log storage
    func logAllStorageData() async
}
