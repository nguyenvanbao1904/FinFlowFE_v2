import Foundation

/// Lưu trữ refresh token riêng biệt với access token
public actor RefreshTokenStore {
    private let service: String
    private let account: String
    
    public init(service: String = "com.finflow.app", account: String = "refresh_token") {
        self.service = service
        self.account = account
    }
    
    public func setRefreshToken(_ token: String?) async {
        guard let token = token else {
            await clearRefreshToken()
            return
        }
        
        guard let data = token.data(using: .utf8) else { return }
        
        // Xóa token cũ nếu có
        await clearRefreshToken()
        
        // Thêm token mới
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    public func getRefreshToken() async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    public func clearRefreshToken() async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
