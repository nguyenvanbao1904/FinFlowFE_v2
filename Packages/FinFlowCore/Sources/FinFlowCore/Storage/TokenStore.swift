import Foundation

public protocol TokenStoreProtocol: Sendable {
    func setToken(_ token: String?) async
    func getToken() async -> String?
    func clearToken() async
}

/// Lưu token tạm thời trong bộ nhớ. Có thể thay thế bằng Keychain sau này.
public actor InMemoryTokenStore: TokenStoreProtocol {
    private var token: String?
    
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
}

