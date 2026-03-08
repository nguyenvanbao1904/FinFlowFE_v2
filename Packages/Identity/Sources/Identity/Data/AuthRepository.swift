//
//  AuthRepository.swift
//  Identity
//

import FinFlowCore
import Foundation

public final class AuthRepository: AuthRepositoryProtocol, Sendable {
    private let client: any HTTPClientProtocol
    private let tokenStore: (any TokenStoreProtocol)?
    internal let cacheService: (any CacheServiceProtocol)?

    public init(
        client: any HTTPClientProtocol,
        tokenStore: (any TokenStoreProtocol)? = nil,
        cacheService: (any CacheServiceProtocol)? = nil
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.cacheService = cacheService
    }

    public func login(req: LoginRequest) async throws -> LoginResponse {
        Logger.info("Gửi request đăng nhập...", category: "Auth")
        return try await client.request(
            endpoint: "/auth/login",
            method: "POST",
            body: req,
            headers: nil,
            version: nil,
            retryOn401: false  // 401 = sai mật khẩu, không retry refresh; giữ message từ backend
        )
    }

    public func loginGoogle(idToken: String) async throws -> LoginResponse {
        Logger.info("Gửi request đăng nhập Google...", category: "Auth")
        let req = GoogleLoginRequest(idToken: idToken)
        return try await client.request(
            endpoint: "/auth/google",
            method: "POST",
            body: req,
            headers: nil,
            version: nil,
            retryOn401: false
        )
    }

    public func register(req: RegisterRequest, token: String) async throws {
        Logger.info("Gửi request đăng ký...", category: "Auth")
        let _: RegisterResponse = try await client.request(
            endpoint: "/auth/register",
            method: "POST",
            body: req,
            headers: ["X-Registration-Token": token],
            version: nil
        )
        Logger.info("Đăng ký thành công", category: "Auth")
    }

    public func updateProfile(request: UpdateProfileRequest) async throws -> UserProfile {
        Logger.info("Updating user profile...", category: "Auth")
        let profile: UserProfile = try await client.request(
            endpoint: "/users/my-profile",
            method: "PUT",
            body: request,
            headers: nil,
            version: nil
        )

        if let cacheKey = await currentUserCacheKey(for: profile.id) {
            try? await cacheService?.save(profile, forKey: cacheKey)
        }

        Logger.info("Profile updated successfully", category: "Auth")
        return profile
    }

    public func getMyProfile() async throws -> UserProfile {
        Logger.info("Lấy thông tin profile từ server...", category: "Auth")
        let profile: UserProfile = try await client.request(
            endpoint: "/users/my-profile",
            method: "GET",
            body: nil,
            headers: nil,
            version: nil
        )

        if let cacheKey = await currentUserCacheKey(for: profile.id) {
            try? await cacheService?.save(profile, forKey: cacheKey)
        }

        Logger.info("Lấy profile thành công và đã cache", category: "Auth")
        return profile
    }

    public func refreshToken() async throws -> RefreshTokenResponse {
        guard let refreshToken = await tokenStore?.getRefreshToken() else {
            Logger.error("Không có refresh token", category: "Auth")
            throw AppError.unauthorized("Không tìm thấy refresh token")
        }

        do {
            Logger.info("Đang refresh token...", category: "Auth")
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let response: RefreshTokenResponse = try await client.request(
                endpoint: "/auth/refresh",
                method: "POST",
                body: request,
                headers: nil,
                version: nil,
                retryOn401: false  // ⛔️ Prevent infinite loop
            )

            // 🔐 CRITICAL FIX: Save new tokens immediately to prevent race condition
            // Without this, concurrent 401s will reuse old token (already blacklisted)
            await tokenStore?.setToken(response.token)
            if let newRefreshToken = response.refreshToken {
                await tokenStore?.setRefreshToken(newRefreshToken)
            }

            Logger.info("Refresh token thành công", category: "Auth")
            return response
        } catch {
            Logger.error("Refresh token thất bại: \(error)", category: "Auth")
            throw AppError.unauthorized("Lỗi làm mới phiên đăng nhập")
        }
    }

    /// Refresh token nhưng không logout/clear token khi lỗi (dùng cho silent flows)
    public func refreshTokenSilent() async throws -> RefreshTokenResponse {
        guard let refreshToken = await tokenStore?.getRefreshToken() else {
            Logger.error("Không có refresh token", category: "Auth")
            throw AppError.unauthorized("Không tìm thấy refresh token")
        }

        do {
            Logger.info("Đang refresh token (silent)...", category: "Auth")
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let response: RefreshTokenResponse = try await client.request(
                endpoint: "/auth/refresh",
                method: "POST",
                body: request,
                headers: nil,
                version: nil,
                retryOn401: false  // ⛔️ Prevent infinite loop
            )

            // 🔐 CRITICAL FIX: Save new tokens immediately to prevent race condition
            await tokenStore?.setToken(response.token)
            if let newRefreshToken = response.refreshToken {
                await tokenStore?.setRefreshToken(newRefreshToken)
            }

            Logger.info("Refresh token (silent) thành công", category: "Auth")
            return response
        } catch {
            Logger.error("Refresh token (silent) thất bại: \(error)", category: "Auth")
            // KHÔNG logout/clear token ở đây, để caller xử lý UI/alert
            throw AppError.unauthorized("Lỗi làm mới phiên đăng nhập")
        }
    }

    public func logout() async throws {
        Logger.info("Đăng xuất, gọi API backend để invalidate token...", category: "Auth")

        // 1. Call backend API to invalidate token on server
        // This prevents the token from being used again even if stolen
        do {
            let _: EmptyResponse = try await client.request(
                endpoint: "/auth/logout",
                method: "POST",
                body: nil,
                headers: nil,
                version: nil
            )
            Logger.info("Token đã được invalidate trên server", category: "Auth")
        } catch {
            // Log error but continue with local cleanup
            // Even if server logout fails, we still want to clear local tokens
            Logger.warning(
                "Không thể logout trên server: \(error), tiếp tục xóa local", category: "Auth")
        }
    }

    public func sendOtp(email: String, purpose: OtpPurpose) async throws {
        let req = SendOtpRequest(email: email, purpose: purpose)
        Logger.info("Gửi OTP đến \(email) cho mục đích \(purpose.rawValue)...", category: "Auth")
        let _: [String: String] = try await client.request(
            endpoint: "/auth/send-otp",
            method: "POST",
            body: req,
            headers: nil,
            version: nil
        )
    }

    public func verifyOtp(email: String, otp: String, purpose: OtpPurpose) async throws
        -> VerifyOtpResponse {
        let req = VerifyOtpRequest(email: email, otp: otp, purpose: purpose)
        Logger.info(
            "Xác thực OTP cho \(email) với mục đích \(purpose.rawValue)...", category: "Auth")
        let response: VerifyOtpResponse = try await client.request(
            endpoint: "/auth/verify-otp",
            method: "POST",
            body: req,
            headers: nil,
            version: nil
        )
        return response
    }

    public func resetPassword(req: ResetPasswordRequest, token: String) async throws {
        Logger.info("Gửi request đặt lại mật khẩu...", category: "Auth")
        let _: [String: String] = try await client.request(
            endpoint: "/auth/reset-password",
            method: "POST",
            body: req,
            headers: ["X-Reset-Token": token],
            version: nil
        )
        Logger.info("Đặt lại mật khẩu thành công", category: "Auth")
    }

    public func checkUserExistence(email: String?, username: String?) async throws
        -> CheckUserExistenceResponse {
        let req = CheckUserExistenceRequest(email: email, username: username)
        let response: CheckUserExistenceResponse = try await client.request(
            endpoint: "/auth/check-user-existence",
            method: "POST",
            body: req,
            headers: nil,
            version: nil
        )
        return response
    }

    // MARK: - Cache Key Helpers
    /// Derive a user-scoped cache key to avoid cross-account leakage.
    /// Prefers passed-in userId from fresh profile; falls back to decoding current token subject.
    internal func currentUserCacheKey(for userId: String? = nil) async -> String? {
        if let userId {
            return CacheKey.userProfile(for: userId)
        }
        guard
            let token = await tokenStore?.getToken(),
            let derivedId = decodeUserIdFromToken(token)
        else {
            return nil
        }
        return CacheKey.userProfile(for: derivedId)
    }

    /// Decode JWT payload to extract "sub" or "username" claim.
    private func decodeUserIdFromToken(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }

        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return (json["sub"] as? String) ?? (json["username"] as? String)
    }

    public func toggleBiometric(enabled: Bool) async throws {
        struct ToggleBiometricRequest: Codable {
            let enabled: Bool
        }

        let req = ToggleBiometricRequest(enabled: enabled)
        let _: [String: String] = try await client.request(
            endpoint: "/auth/toggle-biometric",
            method: "POST",
            body: req,
            headers: nil,
            version: nil
        )
        Logger.info("Biometric toggled: \(enabled)", category: "Auth")
    }

    public func changePassword(req: ChangePasswordRequest) async throws {
        Logger.info("Changing password...", category: "Auth")
        let _: [String: String] = try await client.request(
            endpoint: "/auth/change-password",
            method: "POST",
            body: req,
            headers: nil,
            version: nil
        )
        Logger.info("Password changed successfully", category: "Auth")
    }

    public func deleteAccount(password: String?, token: String) async throws {
        Logger.info("Deleting account...", category: "Auth")

        /// Request body cho API xóa tài khoản.
        /// - password: Có thể nil với user social (không có mật khẩu).
        /// - verificationToken: Token nhận được sau khi verify OTP.
        struct DeleteAccountRequest: Encodable {
            let password: String?
            let verificationToken: String
        }

        let request = DeleteAccountRequest(password: password, verificationToken: token)

        let _: EmptyResponse = try await client.request(
            endpoint: "/auth/delete-account",
            method: "DELETE",
            body: request,
            headers: nil,
            version: nil
        )
        Logger.info("Account deleted successfully", category: "Auth")
    }
}
