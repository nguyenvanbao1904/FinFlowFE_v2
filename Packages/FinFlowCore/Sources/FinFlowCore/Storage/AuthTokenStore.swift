import Foundation

/// Định nghĩa các Key để tránh gõ sai chuỗi (Hardcoded strings)
public enum KeychainKey {
    public static let accessToken = "auth_token"
    public static let refreshToken = "refresh_token"
}

public actor AuthTokenStore: TokenStoreProtocol {
    private let keychain: KeychainService

    public init(keychain: KeychainService) {
        self.keychain = keychain
    }

    // MARK: - Access Token (TokenStoreProtocol Implementation)

    public func setToken(_ token: String?) async {
        if let token = token {
            await keychain.save(token, for: KeychainKey.accessToken)
        } else {
            await keychain.delete(account: KeychainKey.accessToken)
        }
    }

    public func getToken() async -> String? {
        return await keychain.retrieve(for: KeychainKey.accessToken)
    }

    public func clearToken() async {
        await keychain.delete(account: KeychainKey.accessToken)
    }

    // MARK: - Refresh Token (New Unified API)

    public func setRefreshToken(_ token: String?) async {
        if let token = token {
            await keychain.save(token, for: KeychainKey.refreshToken)
        } else {
            await keychain.delete(account: KeychainKey.refreshToken)
        }
    }

    public func getRefreshToken() async -> String? {
        Logger.debug("🔍 Getting refresh token from Keychain...", category: "Storage")
        let token = await keychain.retrieve(for: KeychainKey.refreshToken)
        if let token = token {
            Logger.info("✅ Refresh token found: \(token.prefix(10))...", category: "Storage")
        } else {
            Logger.warning("❌ Refresh token NOT found in Keychain", category: "Storage")
        }
        return token
    }

    public func clearRefreshToken() async {
        await keychain.delete(account: KeychainKey.refreshToken)
    }

    // MARK: - Utility

    /// Xóa toàn bộ token (Dùng khi Logout)
    public func clearAll() async {
        await clearToken()
        await clearRefreshToken()
    }

    // MARK: - Debug Logging

    /// Log token status trong Keychain để debug (CHỈ log existence + prefix, KHÔNG log full token)
    public func logTokenStatus() async {
        let accessToken = await getToken()
        let refreshToken = await getRefreshToken()

        Logger.debug(
            """
            🔑 Token Status in Keychain:
            - Access Token: \(accessToken.map { "✅ Exists (\(String($0.prefix(20)))...)" } ?? "❌ Not Found")
            - Refresh Token: \(refreshToken.map { "✅ Exists (\(String($0.prefix(20)))...)" } ?? "❌ Not Found")
            - Access Token Length: \(accessToken?.count ?? 0) chars
            - Refresh Token Length: \(refreshToken?.count ?? 0) chars
            """, category: "Storage")
    }
}
