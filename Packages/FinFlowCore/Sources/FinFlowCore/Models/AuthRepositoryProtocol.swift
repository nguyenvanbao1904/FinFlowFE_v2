import Foundation
public protocol AuthRepositoryProtocol: Sendable {
    func login(req: LoginRequest) async throws -> LoginResponse
    func updateProfile(request: UpdateProfileRequest) async throws -> UserProfile
    func loginGoogle(idToken: String) async throws -> LoginResponse
    func getMyProfile() async throws -> UserProfile
    func refreshToken() async throws -> RefreshTokenResponse
    func logout() async throws
    func register(req: RegisterRequest) async throws
}
