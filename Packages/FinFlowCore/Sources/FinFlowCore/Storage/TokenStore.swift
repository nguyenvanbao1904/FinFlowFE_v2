import Foundation

public protocol TokenStoreProtocol: Sendable {
    func setToken(_ token: String?) async
    func getToken() async -> String?
    func clearToken() async

    // Refresh token support (optional for simple stores)
    func setRefreshToken(_ token: String?) async
    func getRefreshToken() async -> String?
    func clearRefreshToken() async

    // Debug helper (no-op by default)
    func logTokenStatus() async
}

/// Lưu token tạm thời trong bộ nhớ. Có thể thay thế bằng Keychain sau này.
public actor InMemoryTokenStore: TokenStoreProtocol {
    private var token: String?
    private var refreshToken: String?
    
    public init() {}
    
    public func setToken(_ token: String?) {
        self.token = token
    }
    
    public func getToken() -> String? {
        token
    }
    
    public func clearToken() {
        token = nil
    }

    // MARK: - Refresh Token

    public func setRefreshToken(_ token: String?) {
        refreshToken = token
    }

    public func getRefreshToken() -> String? {
        refreshToken
    }

    public func clearRefreshToken() {
        refreshToken = nil
    }

    public func logTokenStatus() {
        Logger.debug(
            """
            🔑 InMemoryTokenStore:
            - Access Token: \(token?.prefix(8) ?? "nil")
            - Refresh Token: \(refreshToken?.prefix(8) ?? "nil")
            """,
            category: "Storage"
        )
    }
}
