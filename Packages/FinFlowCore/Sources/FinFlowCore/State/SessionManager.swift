//
//  SessionManager.swift
//  FinFlowCore
//

import Foundation
import Observation

@MainActor
@Observable
public final class SessionManager: SessionManagerProtocol {
    private static let refreshTokenLifetime: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    public private(set) var state: SessionState = .loading
    public private(set) var currentUser: UserProfile?


    // Expose tokenStore for biometric check
    public let tokenStore: any TokenStoreProtocol
    private let authRepository: any AuthRepositoryProtocol
    private let userDefaultsManager: any UserDefaultsManagerProtocol
    private let pinManager: any PINManagerProtocol
    
    /// Flag to indicate if biometric authentication is in progress
    public var isBiometricAuthenticationInProgress: Bool = false
    
    // Track active refresh task to allow cancellation on logout
    @ObservationIgnored
    private var activeRefreshTask: Task<RefreshTokenResponse, any Error>?
    
    public init(
        tokenStore: any TokenStoreProtocol,
        authRepository: any AuthRepositoryProtocol,
        userDefaultsManager: any UserDefaultsManagerProtocol,
        pinManager: any PINManagerProtocol
    ) {
        self.tokenStore = tokenStore
        self.authRepository = authRepository
        self.userDefaultsManager = userDefaultsManager
        self.pinManager = pinManager
        Logger.info("📊SessionManager initialized", category: "Session")
    }

    /// Kiểm tra đã có PIN cho email chưa
    public func hasPIN(for email: String) async -> Bool {
        await pinManager.hasPIN(for: email)
    }

    /// Kiểm tra user hiện tại có password hay không (từ UserDefaults)
    public func hasPassword() async -> Bool {
        await userDefaultsManager.getHasPassword()
    }

    /// Tăng bộ đếm nhập sai PIN, vượt ngưỡng sẽ xóa token và PIN
    /// - Returns: (allowed, attempts, max)
    public func incrementPINFailCounter(for email: String) async -> (allowed: Bool, attempts: Int, max: Int) {
        await pinManager.handleFailedPIN(for: email, tokenStore: tokenStore)
    }

    /// Reset bộ đếm nhập sai PIN
    public func resetPINFailCounter(for email: String) async {
        await pinManager.resetFailCounter(for: email)
    }

    /// Xóa PIN cho email
    public func deletePIN(for email: String) async {
        try? await pinManager.deletePIN(for: email)
    }

    public func restoreSession() async {
        state = .loading

        let email = await userDefaultsManager.getEmail()
        let hasUserData = email != nil && !email!.isEmpty
        let isRefreshTokenValid = await userDefaultsManager.isRefreshTokenValid()

        if !isRefreshTokenValid {
            if hasUserData {
                let firstName = await userDefaultsManager.getFirstName()
                let lastName = await userDefaultsManager.getLastName()
                Logger.info("Session expired for user: \(email!)", category: "Session")
                state = .sessionExpired(email: email!, firstName: firstName, lastName: lastName)
            } else {
                Logger.info("First launch - no previous session", category: "Session")
                state = .unauthenticated
            }
            return
        }

        guard let token = await tokenStore.getToken() else {
            guard let refreshToken = await tokenStore.getRefreshToken(),
                !refreshToken.isEmpty
            else {
                Logger.warning("No refresh token found", category: "Session")
                state = .unauthenticated
                return
            }

            let email = await userDefaultsManager.getEmail() ?? ""
            let firstName = await userDefaultsManager.getFirstName()
            let lastName = await userDefaultsManager.getLastName()

            state = .welcomeBack(email: email, firstName: firstName, lastName: lastName)
            return
        }

        state = .authenticated(token: token)
        await loadCurrentUser()
    }

    public func login(response: LoginResponse) async {
        Logger.info("Logging in: \(response.username)", category: "Session")
        
        // ✅ SSOT: Use centralized persistence
        await persistSession(
            token: response.token,
            refreshToken: response.refreshToken,
            expiresIn: response.refreshTokenExpiresIn
        )

        state = .authenticated(token: response.token, isRestored: response.isReactivated ?? false)
        await loadCurrentUser()
    }

    public func logout() async {
        Logger.info("Logging out (soft)", category: "Session")

        // ✅ SECURITY: Clear session & cancel pending tasks
        await clearSessionData(fully: false)

        let email = await userDefaultsManager.getEmail() ?? ""
        let firstName = await userDefaultsManager.getFirstName()
        let lastName = await userDefaultsManager.getLastName()

        state = .welcomeBack(email: email, firstName: firstName, lastName: lastName)
        currentUser = nil

        Logger.info(
            "✅ Logged out - keeping refresh token & user data for quick re-login",
            category: "Session")
    }

    /// Logout hoàn toàn - Xóa tất cả dữ liệu (dùng khi user muốn đăng nhập tài khoản khác)
    public func logoutCompletely() async {
        Logger.info("🗑️ Complete logout - clearing all data", category: "Session")

        // ✅ SECURITY: Clear everything
        await clearSessionData(fully: true)

        state = .unauthenticated
        currentUser = nil

        Logger.info("✅ Complete logout finished", category: "Session")
    }

    public func refreshSession() async throws {
        Logger.info("🔄 Refreshing token", category: "Session")
        state = .refreshing

        // Cancel previous task to avoid race
        activeRefreshTask?.cancel()

        // Wrap in Task to allow tracking & cancellation
        let task = Task {
            try await authRepository.refreshToken()
        }
        activeRefreshTask = task

        do {
            let response = try await task.value
            
            // ✅ SAFETY: Check if task was cancelled during await
            // If user logged out while we were waiting, we must NOT restore state
            if Task.isCancelled || activeRefreshTask?.isCancelled == true {
                Logger.warning("⚠️ Refresh task cancelled - Aborting state update", category: "Session")
                throw CancellationError()
            }
            
            await persistSession(
                token: response.token,
                refreshToken: response.refreshToken,
                expiresIn: response.refreshTokenExpiresIn
            )
            
            state = .authenticated(token: response.token)
            Logger.info("✅ Token refreshed", category: "Session")
        } catch {
            if error is CancellationError {
                // Do nothing if cancelled
                return
            }
            Logger.error("❌ Refresh failed: \(error)", category: "Session")
            // Clear tokens nhưng giữ user info, chuyển sang sessionExpired
            await clearSessionData(fully: false)
            await handleSessionExpired()
            throw error
        }
    }

    /// Refresh token nhưng KHÔNG thay đổi state khi thất bại.
    /// Dùng trong các flow cần giữ UI/alert, ví dụ xác thực sinh trắc học.
    /// - Returns: Token mới nếu thành công
    @discardableResult
    public func refreshSessionSilently() async throws -> String {
        Logger.info("🔄 Refreshing token (silent)", category: "Session")
        do {
            let response = try await authRepository.refreshTokenSilent()
            
            // ✅ CRITICAL FIX: Persist the NEW Refresh Token if server returned one (Rotation)
            // If we don't save it, next time we use the OLD token -> 401 Reuse Detection.
            await persistSession(
                 token: response.token,
                 refreshToken: response.refreshToken,
                 expiresIn: response.refreshTokenExpiresIn
            )
            
            Logger.info("✅ Token refreshed (silent) & persisted", category: "Session")
            return response.token
        } catch {
            Logger.error("❌ Refresh failed (silent): \(error)", category: "Session")
            throw error
        }
    }

    /// Chuyển trạng thái sang Authenticated thủ công (dùng sau khi silent refresh thành công)
    public func finalizeAuthentication(token: String) async {
        Logger.info("🔓 Finalizing authentication", category: "Session")
        state = .authenticated(token: token)
        await loadCurrentUser()
    }

    public func handleSessionExpired() async {
        Logger.warning("⚠️ Session expired", category: "Session")

        // Lấy user data từ UserDefaults để hiển thị welcome message
        let email = await userDefaultsManager.getEmail() ?? ""
        let firstName = await userDefaultsManager.getFirstName()
        let lastName = await userDefaultsManager.getLastName()

        state = .sessionExpired(email: email, firstName: firstName, lastName: lastName)
        currentUser = nil
    }

    /// Xác thực bằng PIN để lấy access token mới từ refresh token
    /// Dùng cho welcome back flow sau khi logout
    /// - Parameter pin: Mã PIN người dùng nhập
    /// - Parameter email: Email của user (từ UserDefaults)
    /// - Returns: true nếu thành công, false nếu PIN sai
    public func authenticateWithPIN(_ pin: String, email: String) async throws -> Bool {
        Logger.info("🔐 Authenticating with PIN for \(email)", category: "Session")

        // Verify PIN BEFORE checking token expiry (UX Improvement)
        let isPINCorrect = await pinManager.verifyPIN(pin, for: email)

        guard isPINCorrect else {
            Logger.warning("❌ PIN verification failed", category: "Session")
            throw AppError.validationError("Mã PIN không đúng")
        }

        // Check refresh token expiry trước khi gọi API
        let isRefreshTokenValid = await userDefaultsManager.isRefreshTokenValid()

        guard isRefreshTokenValid else {
            Logger.error("❌ Refresh token expired", category: "Session")
            // ℹ️ KHÔNG gọi handleSessionExpired() ở đây để tránh destroy view khi đang show alert
            // ViewModel sẽ tự handle logout sau khi user dismiss alert
            throw AppError.unauthorized("Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại")
        }

        Logger.info("✅ PIN verified successfully", category: "Session")


        do {
            // NOTE: We don't wrap this in activeRefreshTask because it's a specific user action (PIN verify)
            // But we should still use persistSession
            let response = try await authRepository.refreshToken()
            
            await persistSession(
                token: response.token,
                refreshToken: response.refreshToken,
                expiresIn: response.refreshTokenExpiresIn
            )            

            state = .authenticated(token: response.token)
            await loadCurrentUser()

            Logger.info("✅ Authenticated with PIN successfully", category: "Session")
            return true
        } catch let appError as AppError {
            Logger.error("❌ Authentication with PIN failed: \(appError)", category: "Session")
            // Không đổi state ở đây; để caller hiển thị alert và tự quyết định logout/redirect
            throw appError
        } catch {
            Logger.error("❌ Authentication with PIN failed: \(error)", category: "Session")
            throw error
        }
    }

    /// Kiểm tra xem refresh token còn hợp lệ không
    /// - Returns: true nếu refresh token còn hợp lệ, false nếu đã hết hạn
    public func isRefreshTokenValid() async -> Bool {
        return await userDefaultsManager.isRefreshTokenValid()
    }

    public func updateCurrentUser(_ user: UserProfile) {
        Logger.info("📝 Updating user profile", category: "Session")
        currentUser = user

        // Lưu vào UserDefaults để persist
        Task {
            await userDefaultsManager.saveUserInfo(user)
        }
    }

    public func loadCurrentUser() async {
        Logger.info("📥 Loading profile...", category: "Session")
        do {
            currentUser = try await authRepository.getMyProfile()

            // ✅ Lưu user info vào UserDefaults
            if let user = currentUser {
                await userDefaultsManager.saveUserInfo(user)
            }

            Logger.info("✅ Profile loaded", category: "Session")
        } catch {
            Logger.error("❌ Failed to load profile: \(error)", category: "Session")
        }
    }

    // MARK: - App Lifecycle & Security (Phase 3)

    /// Khóa phiên làm việc hiện tại, chuyển sang trạng thái .locked
    /// Giữ nguyên currentUser để hiển thị trên màn hình khóa
    public func lockSession() async {
        guard let user = currentUser else {
            Logger.warning("Cannot lock session: No current user", category: "Session")
            return
        }
        
        // Kiểm tra xem có hỗ trợ sinh trắc học không để hiển thị trên UI Lock
        // (Logic này có thể cần check kỹ hơn với LocalAuthentication, nhưng tạm thời dùng isBiometricEnabled của user)
        // Hoặc check system capability. Tạm thời pass false, UI check sau. 
        // Better: Check saved preference via userDefaultsManager if needed.
        let biometricAvailable = user.isBiometricEnabled ?? false
        
        Logger.info("🔒 Locking session for user: \(user.username)", category: "Session")
        state = .locked(user: user, biometricAvailable: biometricAvailable)
    }

    /// Mở khóa phiên làm việc, chuyển lại .authenticated
    /// Cần gọi sau khi verify PIN/Biometric thành công
    public func unlockSession() async {
        guard case .locked(let user, _) = state else {
            Logger.warning("Cannot unlock: Session is not locked", category: "Session")
            return
        }

        Logger.info("🔓 Unlocking session for user: \(user.username)", category: "Session")
        
        // Lấy lại token từ store (nếu còn valid)
        if let token = await tokenStore.getToken() {
             state = .authenticated(token: token)
        } else {
             // Nếu token mất/hết hạn, thử refresh silent
             do {
                 try await refreshSessionSilently()
                 if let newToken = await tokenStore.getToken() {
                     state = .authenticated(token: newToken)
                 } else {
                     await handleSessionExpired()
                 }
             } catch {
                 await handleSessionExpired()
             }
        }
    }

    // MARK: - Safe Storage Helpers (Single Source of Truth)

    private func persistSession(token: String, refreshToken: String?, expiresIn: Int?) async {
        await tokenStore.setToken(token)
        if let refreshToken = refreshToken {
            await tokenStore.setRefreshToken(refreshToken)
            let lifetime = expiresIn.map { TimeInterval($0) } ?? Self.refreshTokenLifetime
            let expiryDate = Date().addingTimeInterval(lifetime)
            await userDefaultsManager.saveRefreshTokenExpiryTime(expiryDate)
        }
    }

    private func clearSessionData(fully: Bool) async {
        // ✅ SECURITY: Cancel any pending refresh task to prevent race conditions
        activeRefreshTask?.cancel()
        activeRefreshTask = nil

        await tokenStore.clearToken() // Always clear Access Token
        
        if fully {
            // Full Logout: Clear Everything
            await tokenStore.clearRefreshToken()
            await userDefaultsManager.clearUserInfo()
        } else {
            // Soft logout (Welcome Back): KEEP Refresh Token & Expiry
            Logger.info("🔄 Soft logout: Preserving refresh token for quick re-login", category: "Session")
        }
    }

    /// Clear expired session data (Delete Refresh Token + Expiry, Keep Email)
    /// Called when 401/403 or explicit expiry is detected.
    public func clearExpiredSession() async {
        Logger.info("⚠️ Clearing expired session data", category: "Session")
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        
        await tokenStore.clearToken()
        await tokenStore.clearRefreshToken()
        await userDefaultsManager.clearRefreshTokenExpiryTime() // Ensure validity check fails next time
        
        // We DO NOT clear UserInfo here (keep email for prefill)
        // Set state to unauthenticated or sessionExpired so router switches to Login
        state = .unauthenticated
    }

    // MARK: - Debug Logging

    /// Log tất cả thông tin storage để debug
    public func logAllStorageData() async {
        Logger.debug(String(repeating: "=", count: 50), category: "Storage")
        Logger.debug("📊 STORAGE DEBUG LOG", category: "Storage")
        Logger.debug(String(repeating: "=", count: 50), category: "Storage")

        // UserDefaults
        await userDefaultsManager.logAllData()

        // Keychain - Tokens
        await tokenStore.logTokenStatus()

        Logger.debug(String(repeating: "=", count: 50), category: "Storage")
    }


}
