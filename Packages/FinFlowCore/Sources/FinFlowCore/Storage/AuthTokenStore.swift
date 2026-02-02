import Foundation

/// Định nghĩa các Key để tránh gõ sai chuỗi (Hardcoded strings)
public enum KeychainKey {
    public static let accessToken = "auth_token"
    public static let refreshToken = "refresh_token"
}

/// Actor quản lý thống nhất việc lưu trữ Token (Access + Refresh)
/// Sử dụng KeychainService ở tầng dưới để thực hiện việc lưu trữ bảo mật.
public actor AuthTokenStore: TokenStoreProtocol {
    private let keychain: KeychainService
    
    public init(keychain: KeychainService = .shared) {
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
        return await keychain.retrieve(for: KeychainKey.refreshToken)
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
}
