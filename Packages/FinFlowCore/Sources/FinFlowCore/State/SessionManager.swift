//
//  SessionManager.swift
//  FinFlowCore
//

import Combine
import Foundation

@MainActor
public final class SessionManager: ObservableObject {
    @Published public private(set) var state: SessionState = .loading
    @Published public private(set) var currentUser: UserProfile?

    public enum SessionState: Equatable {
        case loading
        case authenticated(token: String)
        case unauthenticated
        case refreshing
        case sessionExpired

        public var isAuthenticated: Bool {
            if case .authenticated = self { return true }
            return false
        }
    }

    private let tokenStore: any TokenStoreProtocol
    private let authRepository: any AuthRepositoryProtocol

    public init(
        tokenStore: any TokenStoreProtocol,
        authRepository: any AuthRepositoryProtocol
    ) {
        self.tokenStore = tokenStore
        self.authRepository = authRepository
        Logger.info("📊SessionManager initialized", category: "Session")
    }

    public func restoreSession() async {
        Logger.info("🔄 Restoring session...", category: "Session")
        state = .loading

        guard let token = await tokenStore.getToken() else {
            Logger.info("❌ No token found", category: "Session")
            state = .unauthenticated
            return
        }

        Logger.info("✅ Token found", category: "Session")
        state = .authenticated(token: token)
        await loadCurrentUser()
    }

    public func login(response: LoginResponse) async {
        Logger.info("Logging in: \(response.username)", category: "Session")
        await tokenStore.setToken(response.token)
        state = .authenticated(token: response.token)
        await loadCurrentUser()
    }

    public func logout() async {
        Logger.info("🚪 Logging out", category: "Session")
        await tokenStore.clearToken()
        state = .unauthenticated
        currentUser = nil
    }

    public func refreshSession() async throws {
        Logger.info("🔄 Refreshing token", category: "Session")
        state = .refreshing

        do {
            let response = try await authRepository.refreshToken()
            await tokenStore.setToken(response.token)
            state = .authenticated(token: response.token)
            Logger.info("✅ Token refreshed", category: "Session")
        } catch {
            Logger.error("❌ Refresh failed: \(error)", category: "Session")
            handleSessionExpired()
            throw error
        }
    }

    public func handleSessionExpired() {
        Logger.warning("⚠️ Session expired", category: "Session")
        state = .sessionExpired
        currentUser = nil
    }

    public func updateCurrentUser(_ user: UserProfile) {
        Logger.info("📝 Updating user profile", category: "Session")
        currentUser = user
    }

    private func loadCurrentUser() async {
        Logger.info("📥 Loading profile...", category: "Session")
        do {
            currentUser = try await authRepository.getMyProfile()
            Logger.info("✅ Profile loaded", category: "Session")
        } catch {
            Logger.error("❌ Failed to load profile: \(error)", category: "Session")
        }
    }
}
