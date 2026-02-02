import Foundation
import Security

/// Actor chịu trách nhiệm giao tiếp low-level với Keychain
/// Viết gọn gàng, tổng quát để tái sử dụng cho bất kỳ việc lưu chuỗi bảo mật nào.
public actor KeychainService {
    // Singleton pattern
    public static let shared = KeychainService()
    
    private let service: String

    public init(service: String = "com.finflow.app") {
        self.service = service
    }

    /// Lưu trữ một chuỗi vào Keychain
    public func save(_ value: String, for account: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 1. Xóa cũ trước cho chắc chắn không bị lỗi duplicate
        delete(account: account)

        // 2. Tạo query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Bảo mật cao hơn: Chỉ truy cập được khi thiết bị đã mở khóa
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    /// Đọc một chuỗi từ Keychain
    public func retrieve(for account: String) -> String? {
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
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Xóa dữ liệu khỏi Keychain
    public func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
