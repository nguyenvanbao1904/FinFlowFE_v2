//
//  PINManager.swift
//  FinFlowCore
//

import CryptoKit
import Foundation

/// Service quản lý mã PIN để bảo vệ Access Token và Refresh Token
/// PIN được lưu trong Keychain với format: pincode_{email}
public actor PINManager: PINManagerProtocol {
    private let keychain: KeychainService
    private let prefix = "pincode_"
    private let counterPrefix = "pincode_fail_"
    private let maxFailures = 5

    public init(keychain: KeychainService) {
        self.keychain = keychain
    }

    /// Tạo key cho PIN dựa trên email
    private func pinKey(for email: String) -> String {
        return prefix + email.lowercased()
    }

    private func counterKey(for email: String) -> String {
        return counterPrefix + email.lowercased()
    }

    /// Hash PIN trước khi lưu (để bảo mật)
    private func hashPIN(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Kiểm tra xem đã có PIN cho email này chưa
    public func hasPIN(for email: String) async -> Bool {
        let key = pinKey(for: email)
        return await keychain.retrieve(for: key) != nil
    }

    /// Lưu PIN mới cho email
    public func savePIN(_ pin: String, for email: String) async throws {
        let key = pinKey(for: email)
        let hashedPIN = hashPIN(pin)
        await keychain.save(hashedPIN, for: key)
    }

    /// Xác thực PIN
    public func verifyPIN(_ pin: String, for email: String) async -> Bool {
        let key = pinKey(for: email)
        guard let storedHash = await keychain.retrieve(for: key) else {
            return false
        }

        let inputHash = hashPIN(pin)
        return inputHash == storedHash
    }

    /// Xóa PIN
    public func deletePIN(for email: String) async throws {
        let key = pinKey(for: email)
        await keychain.delete(account: key)
    }

    /// Đếm số lần nhập sai PIN và xử lý khóa
    /// - Returns: (allowed, attempts, max) where allowed=false nếu đã vượt giới hạn (đã xóa token/PIN)
    public func handleFailedPIN(for email: String, tokenStore: any TokenStoreProtocol) async -> (allowed: Bool, attempts: Int, max: Int) { // swiftlint:disable:this large_tuple
        let counterKey = counterKey(for: email)
        let current = (await keychain.retrieve(for: counterKey)).flatMap { Int($0) } ?? 0
        let next = current + 1
        await keychain.save(String(next), for: counterKey)

        Logger.warning("PIN failed \(next)/\(maxFailures) for \(email)", category: "Security")

        if next >= maxFailures {
            Logger.error("PIN failed max times, clearing tokens and PIN for \(email)", category: "Security")
            await tokenStore.clearToken()
            try? await deletePIN(for: email)
            await keychain.delete(account: counterKey)
            return (false, next, maxFailures)
        }
        return (true, next, maxFailures)
    }

    /// Reset counter khi nhập đúng
    public func resetFailCounter(for email: String) async {
        let counterKey = counterKey(for: email)
        await keychain.delete(account: counterKey)
    }

    /// Đổi PIN
    public func changePIN(oldPIN: String, newPIN: String, for email: String) async -> Bool {
        guard await verifyPIN(oldPIN, for: email) else {
            return false
        }

        do {
            try await savePIN(newPIN, for: email)
            return true
        } catch {
            Logger.error("Failed to save new PIN for \(email): \(error)", category: "Security")
            return false
        }
    }

    // MARK: - Debug Logging

    /// Log thông tin PIN trong Keychain để debug (CHỈ log existence, KHÔNG log giá trị)
    public func logPINStatus(for email: String) async {
        let key = pinKey(for: email)
        let exists = await hasPIN(for: email)

        Logger.debug(
            """
            🔐 PIN Status for \(email):
            - Keychain Key: \(key)
            - PIN Exists: \(exists ? "✅ Yes" : "❌ No")
            - Hash Length: \(exists ? "64 chars (SHA-256)" : "N/A")
            """, category: "Security")
    }
}
