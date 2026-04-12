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

