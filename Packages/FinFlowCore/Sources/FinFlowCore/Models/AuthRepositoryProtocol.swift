import Foundation
public protocol AuthRepositoryProtocol: Sendable {
    func login(req: LoginRequest) async throws -> LoginResponse
    func updateProfile(request: UpdateProfileRequest) async throws -> UserProfile
    func loginGoogle(idToken: String) async throws -> LoginResponse
    func getMyProfile() async throws -> UserProfile
    func refreshToken() async throws -> RefreshTokenResponse
    func logout() async throws
    func register(req: RegisterRequest, token: String) async throws
    func sendOtp(email: String, purpose: OtpPurpose) async throws
    func verifyOtp(email: String, otp: String, purpose: OtpPurpose) async throws -> VerifyOtpResponse
    func resetPassword(req: ResetPasswordRequest, token: String) async throws
    func checkUserExistence(email: String) async throws -> Bool
}
