//
//  AuthRepository.swift
//  Identity
//

import FinFlowCore
import Foundation

public final class AuthRepository: AuthRepositoryProtocol, Sendable {
    private let apiClient: APIClient
    private let tokenStore: (any TokenStoreProtocol)?
    private let refreshTokenStore: RefreshTokenStore
    internal let cacheService: (any CacheServiceProtocol)?

    public init(
        apiClient: APIClient,
        tokenStore: (any TokenStoreProtocol)? = nil,
        refreshTokenStore: RefreshTokenStore = RefreshTokenStore(),
        cacheService: (any CacheServiceProtocol)? = nil
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.refreshTokenStore = refreshTokenStore
        self.cacheService = cacheService
    }

    public func login(req: LoginRequest) async throws -> LoginResponse {
        do {
            Logger.info("Gửi request đăng nhập...", category: "Auth")
            let response: LoginResponse = try await apiClient.request(
                endpoint: "/auth/login",
                method: "POST",
                body: req,
                retryOn401: false // Login failure should not trigger token refresh
            )

            // Lưu access token (async operation with proper concurrency)
            await tokenStore?.setToken(response.token)

            // Lưu refresh token nếu có
            if let refreshToken = response.refreshToken {
                await refreshTokenStore.setRefreshToken(refreshToken)

            }

            Logger.info("Đăng nhập thành công, token đã lưu", category: "Auth")
            return response
        } catch let error as AppError {
            Logger.error("Login failed with AppError: \(error)", category: "Auth")
            throw error 
        } catch {
            Logger.error("Login failed with unknown error: \(error)", category: "Auth")
            throw AppError.unknown
        }
    }

    public func loginGoogle(idToken: String) async throws -> LoginResponse {
        do {
            Logger.info("Gửi request đăng nhập Google...", category: "Auth")
            let req = GoogleLoginRequest(idToken: idToken)
            let response: LoginResponse = try await apiClient.request(
                endpoint: "/auth/google",
                method: "POST",
                body: req,
                retryOn401: false
            )

            await tokenStore?.setToken(response.token)
            if let refreshToken = response.refreshToken {
                await refreshTokenStore.setRefreshToken(refreshToken)
            }
            
            Logger.info("Đăng nhập Google thành công", category: "Auth")
            return response
        } catch {
            Logger.error("Login Google thất bại: \(error)", category: "Auth")
            throw error
        }
    }

    public func register(req: RegisterRequest, token: String) async throws {
        do {
            Logger.info("Gửi request đăng ký...", category: "Auth")
            let _: RegisterResponse = try await apiClient.request(
                endpoint: "/auth/register",
                method: "POST",
                body: req,
                headers: ["X-Registration-Token": token],
                retryOn401: false
            )
            Logger.info("Đăng ký thành công", category: "Auth")
        } catch {
            Logger.error("Đăng ký thất bại: \(error)", category: "Auth")
            throw error
        }
    }

    public func updateProfile(request: UpdateProfileRequest) async throws -> UserProfile {
        do {
            Logger.info("Updating user profile...", category: "Auth")
            let profile: UserProfile = try await apiClient.request(
                endpoint: "/users/my-profile",
                method: "PUT",
                body: request
            )

            // Update cache
            if let cacheKey = await currentUserCacheKey(for: profile.id) {
                try? await cacheService?.save(profile, forKey: cacheKey)
            }

            Logger.info("Profile updated successfully", category: "Auth")
            return profile
        } catch {
            Logger.error("Update profile failed: \(error)", category: "Auth")
            throw error
        }
    }

    public func getMyProfile() async throws -> UserProfile {
        // Fetch từ server (cache logic được handle trong extension)
        do {
            Logger.info("Lấy thông tin profile từ server...", category: "Auth")
            let profile: UserProfile = try await apiClient.request(
                endpoint: "/users/my-profile",
                method: "GET"
            )

            // Lưu vào cache
            if let cacheKey = await currentUserCacheKey(for: profile.id) {
                try? await cacheService?.save(profile, forKey: cacheKey)
            }

            Logger.info("Lấy profile thành công và đã cache", category: "Auth")
            return profile
        } catch let error as AppError {
            // Nếu lỗi 401, thử refresh token
            if case .serverError(let code, _) = error, code == 401 {
                Logger.warning("Token hết hạn, thử refresh...", category: "Auth")
                do {
                    _ = try await refreshToken()
                    // Retry sau khi refresh thành công
                    let profile: UserProfile = try await apiClient.request(
                        endpoint: "/users/my-profile",
                        method: "GET"
                    )
                    if let cacheKey = await currentUserCacheKey(for: profile.id) {
                        try? await cacheService?.save(profile, forKey: cacheKey)
                    }
                    return profile
                } catch {
                    Logger.error("Refresh token thất bại", category: "Auth")
                    throw AppError.unauthorized("Phiên đăng nhập hết hạn")
                }
            }

            Logger.error("Get profile failed: \(error)", category: "Auth")
            throw error
        } catch {
            Logger.error("Get profile failed with unknown error: \(error)", category: "Auth")
            throw AppError.unknown
        }
    }

    public func refreshToken() async throws -> RefreshTokenResponse {
        guard let refreshToken = await refreshTokenStore.getRefreshToken() else {
            Logger.error("Không có refresh token", category: "Auth")
            throw AppError.unauthorized("Không tìm thấy refresh token")
        }

        do {
            Logger.info("Đang refresh token...", category: "Auth")
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let response: RefreshTokenResponse = try await apiClient.request(
                endpoint: "/auth/refresh",
                method: "POST",
                body: request,
                retryOn401: false  // tránh vòng lặp refresh
            )

            // Cập nhật tokens mới
            await tokenStore?.setToken(response.token)
            if let newRefreshToken = response.refreshToken {
                await refreshTokenStore.setRefreshToken(newRefreshToken)
            }

            Logger.info("Refresh token thành công", category: "Auth")
            return response
        } catch {
            Logger.error("Refresh token thất bại: \(error)", category: "Auth")
            // Xóa tokens khi refresh thất bại
            try? await logout()
            throw AppError.unauthorized("Lỗi làm mới phiên đăng nhập")
        }
    }

    public func logout() async throws {
        Logger.info("Đăng xuất, gọi API backend để invalidate token...", category: "Auth")

        // 1. Call backend API to invalidate token on server
        // This prevents the token from being used again even if stolen
        do {
            let _: EmptyResponse = try await apiClient.request(
                endpoint: "/auth/logout",
                method: "POST",
                retryOn401: false
            )
            Logger.info("Token đã được invalidate trên server", category: "Auth")
        } catch {
            // Log error but continue with local cleanup
            // Even if server logout fails, we still want to clear local tokens
            Logger.warning(
                "Không thể logout trên server: \(error), tiếp tục xóa local", category: "Auth")
        }

        // 2. Clear local tokens and cache
        await tokenStore?.clearToken()
        await refreshTokenStore.clearRefreshToken()
        try? await cacheService?.clear()

        Logger.info("Đăng xuất hoàn tất, đã xóa tokens và cache", category: "Auth")
    }

    public func sendOtp(email: String) async throws {
        let req = SendOtpRequest(email: email)
        Logger.info("Gửi OTP đến \(email)...", category: "Auth")
        let _: [String: String] = try await apiClient.request(
            endpoint: "/auth/send-otp",
            method: "POST",
            body: req,
            retryOn401: false
        )
    }

    public func verifyOtp(email: String, otp: String) async throws -> VerifyOtpResponse {
        let req = VerifyOtpRequest(email: email, otp: otp)
        Logger.info("Xác thực OTP cho \(email)...", category: "Auth")
        let response: VerifyOtpResponse = try await apiClient.request(
            endpoint: "/auth/verify-otp",
            method: "POST",
            body: req,
            retryOn401: false
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
}
