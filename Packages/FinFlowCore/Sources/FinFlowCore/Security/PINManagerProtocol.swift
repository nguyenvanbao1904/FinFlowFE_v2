import Foundation

/// Protocol defining PIN management responsibilities
/// Handles secure storage and verification of user PINs
public protocol PINManagerProtocol: Sendable {
    /// Save PIN for specified email
    /// - Parameters:
    ///   - pin: The PIN code to save
    ///   - email: User's email address
    func savePIN(_ pin: String, for email: String) async throws
    
    /// Verify PIN for specified email
    /// - Parameters:
    ///   - pin: The PIN code to verify
    ///   - email: User's email address
    /// - Returns: True if PIN is correct
    func verifyPIN(_ pin: String, for email: String) async -> Bool
    
    /// Delete PIN for specified email
    /// - Parameter email: User's email address
    func deletePIN(for email: String) async throws
    
    /// Check if PIN exists for specified email
    /// - Parameter email: User's email address
    /// - Returns: True if PIN exists
    func hasPIN(for email: String) async -> Bool
    
    /// Log PIN status for debugging
    /// - Parameter email: User's email address
    func logPINStatus(for email: String) async
    
    /// Handle failed PIN attempt
    /// - Parameter email: User's email address
    /// - Parameter tokenStore: Token store to clear tokens if max attempts reached
    /// - Returns: Tuple containing success status and attempts info
    func handleFailedPIN(for email: String, tokenStore: any TokenStoreProtocol) async -> (allowed: Bool, attempts: Int, max: Int)
    
    /// Reset fail counter for email
    /// - Parameter email: User's email address
    func resetFailCounter(for email: String) async
}
