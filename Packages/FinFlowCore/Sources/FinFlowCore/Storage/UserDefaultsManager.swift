//
//  UserDefaultsManager.swift
//  FinFlowCore
//

import Foundation

/// Manager lưu trữ thông tin user non-sensitive vào UserDefaults
///
/// ✅ Lưu UserDefaults (Non-sensitive):
/// - firstName, lastName, email, username
///
/// ❌ KHÔNG lưu UserDefaults (Sensitive - dùng Keychain):
/// - accessToken, refreshToken, PIN hash
public actor UserDefaultsManager: UserDefaultsManagerProtocol {
    private let defaults: UserDefaults
    private let suiteName: String?

    private static func formatISO8601(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
    private enum Keys {
        static let firstName = "user_firstName"
        static let lastName = "user_lastName"
        static let email = "user_email"
        static let username = "user_username"
        static let userId = "user_id"
        static let isBiometricEnabled = "user_isBiometricEnabled"
        static let hasPassword = "user_hasPassword"
        static let refreshTokenExpiryTime = "user_refreshTokenExpiryTime"
    }

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        Logger.info("💾 UserDefaultsManager initialized", category: "Storage")
    }

    // MARK: - Save User Info

    /// Lưu thông tin user sau login
    public func saveUserInfo(_ user: UserProfile) {
        defaults.set(user.firstName, forKey: Keys.firstName)
        defaults.set(user.lastName, forKey: Keys.lastName)
        defaults.set(user.email, forKey: Keys.email)
        defaults.set(user.username, forKey: Keys.username)
        defaults.set(user.id, forKey: Keys.userId)
        defaults.set(user.isBiometricEnabled ?? false, forKey: Keys.isBiometricEnabled)
        defaults.set(user.hasPassword, forKey: Keys.hasPassword)
        defaults.synchronize()

        Logger.info("✅ Saved user info to UserDefaults: \(user.username)", category: "Storage")
    }

    // MARK: - Retrieve User Info

    public func getFirstName() async -> String? {
        return defaults.string(forKey: Keys.firstName)
    }

    public func getLastName() async -> String? {
        return defaults.string(forKey: Keys.lastName)
    }

    public func getEmail() async -> String? {
        return defaults.string(forKey: Keys.email)
    }

    /// Lưu email để prefill màn login (vd: sau quên mật khẩu). Dùng chung key với saveUserInfo.
    public func saveEmailForPrefill(_ email: String) async {
        defaults.set(email, forKey: Keys.email)
        defaults.synchronize()
    }

    public func getUsername() async -> String? {
        return defaults.string(forKey: Keys.username)
    }

    public func getUserId() async -> String? {
        return defaults.string(forKey: Keys.userId)
    }

    public func getIsBiometricEnabled() async -> Bool {
        return defaults.bool(forKey: Keys.isBiometricEnabled)
    }

    public func getHasPassword() async -> Bool {
        return defaults.bool(forKey: Keys.hasPassword)
    }

    public func saveBiometricEnabled(_ enabled: Bool) async {
        defaults.set(enabled, forKey: Keys.isBiometricEnabled)
        defaults.synchronize()
        Logger.info("✅ Updated isBiometricEnabled to \(enabled)", category: "Storage")
    }
    
    public func getBiometricEnabled() async -> Bool {
        return defaults.bool(forKey: Keys.isBiometricEnabled)
    }
    
    public func clearBiometricEnabled() async {
        defaults.removeObject(forKey: Keys.isBiometricEnabled)
        defaults.synchronize()
        Logger.info("🗑️ Cleared biometric preference", category: "Storage")
    }

    /// Get full user info
    public func getUserInfo() async -> ( // swiftlint:disable:this large_tuple
        firstName: String?, lastName: String?, email: String?, username: String?
    ) {
        return (
            firstName: await getFirstName(),
            lastName: await getLastName(),
            email: await getEmail(),
            username: await getUsername()
        )
    }

    // MARK: - Refresh Token Expiry Management

    /// Lưu thời điểm hết hạn của refresh token
    /// - Parameter expiryDate: Thời điểm hết hạn (Date)
    public func saveRefreshTokenExpiryTime(_ expiryDate: Date) async {
        defaults.set(expiryDate.timeIntervalSince1970, forKey: Keys.refreshTokenExpiryTime)
        defaults.synchronize()

        Logger.info(
            "✅ Saved refresh token expiry: \(Self.formatISO8601(expiryDate))",
            category: "Storage")
    }

    /// Lấy thời điểm hết hạn của refresh token
    public func getRefreshTokenExpiryTime() async -> Date? {
        let timestamp = defaults.double(forKey: Keys.refreshTokenExpiryTime)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Check xem refresh token còn hợp lệ không
    /// - Returns: true nếu còn hợp lệ, false nếu đã hết hạn hoặc không tồn tại
    public func isRefreshTokenValid() async -> Bool {
        Logger.debug("🔍 ========== CHECKING REFRESH TOKEN VALIDITY ==========", category: "Storage")

        guard let expiryDate = await getRefreshTokenExpiryTime() else {
            Logger.warning("❌ Refresh token expiry not found in UserDefaults", category: "Storage")
            return false
        }

        let now = Date()
        let isValid = expiryDate > now

        Logger.info("📅 Current time: \(Self.formatISO8601(now))", category: "Storage")
        Logger.info("⏰ Expiry time: \(Self.formatISO8601(expiryDate))", category: "Storage")
        Logger.info(
            "✅ Is valid: \(isValid) (time remaining: \(expiryDate.timeIntervalSince(now)) seconds)",
            category: "Storage")

        return isValid
    }

    /// Xóa thời gian hết hạn của refresh token
    public func clearRefreshTokenExpiryTime() async {
        defaults.removeObject(forKey: Keys.refreshTokenExpiryTime)
        defaults.synchronize()
    }

    // MARK: - Clear
    
    /// Clear all stored data (implements UserDefaultsManagerProtocol)
    public func clearAll() async {
        await clearUserInfo()
        Logger.info("🗑️ Cleared all UserDefaults data", category: "Storage")
    }

    /// Xóa toàn bộ thông tin user (Logout)
    public func clearUserInfo() async {
        defaults.removeObject(forKey: Keys.firstName)
        defaults.removeObject(forKey: Keys.lastName)
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.hasPassword)
        defaults.removeObject(forKey: Keys.refreshTokenExpiryTime)
        defaults.synchronize()

        Logger.info("🗑️ Cleared user info from UserDefaults", category: "Storage")
    }

    // MARK: - Debug Logging

    /// Log tất cả thông tin trong UserDefaults để debug
    public func logAllData() async {
        let info = await getUserInfo()
        let refreshTokenExpiry = await getRefreshTokenExpiryTime()
        let isValid = await isRefreshTokenValid()

        let expiryString: String
        if let expiry = refreshTokenExpiry {
            expiryString = "\(Self.formatISO8601(expiry)) (Valid: \(isValid ? "✅" : "❌"))"
        } else {
            expiryString = "nil"
        }

        Logger.debug(
            """
            📊 UserDefaults Data:
            - First Name: \(info.firstName ?? "nil")
            - Last Name: \(info.lastName ?? "nil")
            - Email: \(info.email ?? "nil")
            - Username: \(info.username ?? "nil")
            - User ID: \(await getUserId() ?? "nil")
            - Refresh Token Expiry: \(expiryString)
            """, category: "Storage")
    }
}
