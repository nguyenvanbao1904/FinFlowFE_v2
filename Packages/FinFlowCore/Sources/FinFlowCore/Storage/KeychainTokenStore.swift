import Foundation
import Security

/// Lưu trữ token an toàn trong Keychain của iOS
public actor KeychainTokenStore: TokenStoreProtocol {
    private let service: String
    private let account: String
    
    public init(service: String = "com.finflow.app", account: String = "auth_token") {
        self.service = service
        self.account = account
    }
    
    public func setToken(_ token: String?) async {
        guard let token = token else {
            await clearToken()
            return
        }
        
        guard let data = token.data(using: .utf8) else { return }
        
        // Xóa token cũ nếu có
        await clearToken()
        
        // Thêm token mới
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        #if DEBUG
        if status != errSecSuccess {
            print("⚠️ [Keychain] Lỗi lưu token: \(status)")
        }
        #endif
    }
    
    public func getToken() async -> String? {
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
    
    public func clearToken() async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
