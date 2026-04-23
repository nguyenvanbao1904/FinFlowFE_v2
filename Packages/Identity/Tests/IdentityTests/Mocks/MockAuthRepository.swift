import Foundation
import FinFlowCore
@testable import Identity

// MARK: - Mock Auth Repository
// Implements all Identity repository protocols for unit testing.

final class MockAuthRepository: AuthenticationRepositoryProtocol, OTPRepositoryProtocol,
    AccountRepositoryProtocol, @unchecked Sendable
{

    // MARK: - Stub Responses

    var stubbedLoginResponse: LoginResponse = .mock()
    var stubbedVerifyOtpResponse: VerifyOtpResponse = .mock()
    var stubbedCheckUserExistence: CheckUserExistenceResponse = .mockNotExists()

    /// Set để force throw error từ bất kỳ method nào
    var errorToThrow: Error?

    // MARK: - Call Trackers

    var loginCallCount = 0
    var lastLoginRequest: LoginRequest?

    var loginGoogleCallCount = 0
    var lastLoginGoogleIdToken: String?

    var sendOtpCallCount = 0
    var lastSendOtpEmail: String?
    var lastSendOtpPurpose: OtpPurpose?

    var verifyOtpCallCount = 0
    var lastVerifyOtpEmail: String?
    var lastVerifyOtpCode: String?
    var lastVerifyOtpPurpose: OtpPurpose?

    var registerCallCount = 0
    var lastRegisterRequest: RegisterRequest?
    var lastRegisterToken: String?

    var resetPasswordCallCount = 0
    var lastResetPasswordRequest: ResetPasswordRequest?
    var lastResetPasswordToken: String?

    var checkExistenceCallCount = 0
    var lastCheckEmail: String?
    var lastCheckUsername: String?

    // MARK: - AuthenticationRepositoryProtocol

    func login(req: LoginRequest) async throws -> LoginResponse {
        if let error = errorToThrow { throw error }
        loginCallCount += 1
        lastLoginRequest = req
        return stubbedLoginResponse
    }

    func loginGoogle(idToken: String) async throws -> LoginResponse {
        if let error = errorToThrow { throw error }
        loginGoogleCallCount += 1
        lastLoginGoogleIdToken = idToken
        return stubbedLoginResponse
    }

    func register(req: RegisterRequest, token: String) async throws {
        if let error = errorToThrow { throw error }
        registerCallCount += 1
        lastRegisterRequest = req
        lastRegisterToken = token
    }

    func logout() async throws {
        if let error = errorToThrow { throw error }
    }

    func refreshToken() async throws -> RefreshTokenResponse {
        if let error = errorToThrow { throw error }
        return RefreshTokenResponse(token: "new-token", refreshToken: nil, type: "Bearer", expiresIn: 3600)
    }

    func refreshTokenSilent() async throws -> RefreshTokenResponse {
        if let error = errorToThrow { throw error }
        return RefreshTokenResponse(token: "new-token", refreshToken: nil, type: "Bearer", expiresIn: 3600)
    }

    // MARK: - OTPRepositoryProtocol

    func sendOtp(email: String, purpose: OtpPurpose) async throws {
        if let error = errorToThrow { throw error }
        sendOtpCallCount += 1
        lastSendOtpEmail = email
        lastSendOtpPurpose = purpose
    }

    func verifyOtp(email: String, otp: String, purpose: OtpPurpose) async throws -> VerifyOtpResponse {
        if let error = errorToThrow { throw error }
        verifyOtpCallCount += 1
        lastVerifyOtpEmail = email
        lastVerifyOtpCode = otp
        lastVerifyOtpPurpose = purpose
        return stubbedVerifyOtpResponse
    }

    // MARK: - AccountRepositoryProtocol

    func checkUserExistence(email: String?, username: String?) async throws -> CheckUserExistenceResponse {
        if let error = errorToThrow { throw error }
        checkExistenceCallCount += 1
        lastCheckEmail = email
        lastCheckUsername = username
        return stubbedCheckUserExistence
    }

    func changePassword(req: ChangePasswordRequest) async throws {
        if let error = errorToThrow { throw error }
    }

    func resetPassword(req: ResetPasswordRequest, token: String) async throws {
        if let error = errorToThrow { throw error }
        resetPasswordCallCount += 1
        lastResetPasswordRequest = req
        lastResetPasswordToken = token
    }

    func toggleBiometric(enabled: Bool) async throws {
        if let error = errorToThrow { throw error }
    }

    func deleteAccount(password: String?, token: String) async throws {
        if let error = errorToThrow { throw error }
    }
}

// MARK: - Test Fixtures

extension LoginResponse {
    static func mock(
        email: String = "user@example.com",
        token: String = "eyJhbGciOiJIUzI1NiJ9.mock-token",
        refreshToken: String? = "mock-refresh-token",
        type: String = "Bearer",
        username: String = "testuser",
        expiresIn: Int? = 3600
    ) -> LoginResponse {
        LoginResponse(
            email: email,
            token: token,
            refreshToken: refreshToken,
            type: type,
            username: username,
            expiresIn: expiresIn
        )
    }
}

extension VerifyOtpResponse {
    static func mock(
        message: String = "OTP verified successfully",
        registrationToken: String = "reg-token-abc123"
    ) -> VerifyOtpResponse {
        VerifyOtpResponse(message: message, registrationToken: registrationToken)
    }
}

extension CheckUserExistenceResponse {
    static func mockExists(hasPassword: Bool = true) -> CheckUserExistenceResponse {
        CheckUserExistenceResponse(exists: true, isActive: true, hasPassword: hasPassword, isDeleted: false)
    }

    static func mockNotExists() -> CheckUserExistenceResponse {
        CheckUserExistenceResponse(exists: false, isActive: nil, hasPassword: nil, isDeleted: nil)
    }
}

extension RegisterRequest {
    static func mock(
        username: String = "newuser",
        email: String = "new@example.com",
        password: String = "password123",
        firstName: String? = "Nguyen",
        lastName: String? = "Van A",
        dob: String? = nil
    ) -> RegisterRequest {
        RegisterRequest(
            username: username,
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            dob: dob
        )
    }
}

// MARK: - Mock Error

enum IdentityMockError: Error, Equatable {
    case networkFailure
    case unauthorized
    case serverError(code: Int)
}
