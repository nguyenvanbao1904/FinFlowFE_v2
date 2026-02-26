import Foundation

/// Protocol defining UserDefaults management responsibilities
/// Handles persistent storage of user preferences and session data
public protocol UserDefaultsManagerProtocol: Sendable {
    /// Save refresh token expiry time
    /// - Parameter date: Expiry date to save
    func saveRefreshTokenExpiryTime(_ date: Date) async
    
    /// Get saved refresh token expiry time
    /// - Returns: Saved expiry date, if any
    func getRefreshTokenExpiryTime() async -> Date?
    
    /// Clear saved refresh token expiry time
    func clearRefreshTokenExpiryTime() async
    
    /// Save biometric enabled preference
    /// - Parameter enabled: Whether biometric is enabled
    func saveBiometricEnabled(_ enabled: Bool) async
    
    /// Get biometric enabled preference
    /// - Returns: True if biometric is enabled
    func getBiometricEnabled() async -> Bool
    
    /// Clear biometric enabled preference
    func clearBiometricEnabled() async
    
    /// Get first name
    func getFirstName() async -> String?
    
    /// Get last name
    func getLastName() async -> String?
    
    /// Get email
    func getEmail() async -> String?

    /// Lưu email để prefill màn login (vd: sau quên mật khẩu). Dùng chung key với getEmail/saveUserInfo.
    func saveEmailForPrefill(_ email: String) async
    
    /// Get username
    func getUsername() async -> String?
    
    /// Get user ID
    func getUserId() async -> String?
    
    /// Get biometric enabled (sync)
    func getIsBiometricEnabled() async -> Bool
    
    /// Get has password
    func getHasPassword() async -> Bool
    
    /// Clear all stored data
    func clearAll() async
    
    /// Check if refresh token is valid
    func isRefreshTokenValid() async -> Bool
    
    /// Clear user info
    func clearUserInfo() async
    
    /// Save full user profile (including biometric settings)
    func saveUserInfo(_ user: UserProfile) async
    
    /// Log all data for debugging
    func logAllData() async
}
