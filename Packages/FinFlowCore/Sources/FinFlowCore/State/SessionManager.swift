//
//  SessionManager.swift
//  FinFlowCore
//

import Foundation
import Observation

@MainActor

@Observable
public final class SessionManager {
    public private(set) var state: SessionState = .loading
    public private(set) var currentUser: UserProfile?

    public enum SessionState: Equatable, Sendable {
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
    // MARK: - Async Streams

    /// Dòng dữ liệu trạng thái (State Stream) - Phiên bản Fix Lỗi Timing
    public var stateStream: AsyncStream<SessionState> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self = self else { return }

                // 1. Yield giá trị đầu tiên ngay lập tức
                continuation.yield(self.state)

                // 2. Vòng lặp lắng nghe thay đổi
                while !Task.isCancelled {
                    // Tạo một "điểm chờ" (Signal)
                    await withCheckedContinuation {
                        (innerContinuation: CheckedContinuation<Void, Never>) in
                        // Đăng ký theo dõi
                        withObservationTracking {
                            _ = self.state  // "Chạm" vào biến để đăng ký
                        } onChange: {
                            // Khi biến SẮP thay đổi (willSet), ta resume task
                            // Việc resume này sẽ đẩy Task ra hàng đợi sau khi việc gán hoàn tất
                            Task { @MainActor in
                                innerContinuation.resume()
                            }
                        }
                    }

                    // 3. Sau khi "tỉnh dậy", giá trị đã được update xong -> Yield giá trị mới
                    continuation.yield(self.state)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
