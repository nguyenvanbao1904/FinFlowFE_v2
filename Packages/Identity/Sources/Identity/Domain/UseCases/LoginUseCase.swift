import FinFlowCore
import Foundation

// MARK: - Login Use Case

/// Use Case: Login User
///
/// WHY UseCase? ✅ VALID theo FEATURE_DEVELOPMENT_GUIDE:
/// - Complex business logic: Input validation + data sanitization (trim whitespace)
/// - Data transformation: Convert raw input to clean LoginRequest
/// - Error handling: Validate empty fields before network call
///
/// Responsibilities:
/// 1. Validate username and password are not empty
/// 2. Sanitize input (trim whitespace from both fields)
/// 3. Create LoginRequest with clean data
/// 4. Call repository to perform authentication
///
/// Pattern: ViewModel → UseCase → Repository → API
/// NOT a wrapper - has genuine business logic (validation + sanitization)
public protocol LoginUseCaseProtocol: Sendable {
    func execute(username: String, password: String) async throws -> LoginResponse
    func executeGoogle(idToken: String) async throws -> LoginResponse
}

public struct LoginUseCase: LoginUseCaseProtocol {
    private let repository: AuthenticationRepositoryProtocol

    public init(repository: AuthenticationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(username: String, password: String) async throws -> LoginResponse {
        guard !username.isEmpty, !password.isEmpty else {
            throw AppError.validationError("Vui lòng nhập đầy đủ tài khoản và mật khẩu")
        }

        // Business logic: Data sanitization
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = LoginRequest(username: cleanUsername, password: cleanPassword)
        return try await repository.login(req: request)
    }

    public func executeGoogle(idToken: String) async throws -> LoginResponse {
        return try await repository.loginGoogle(idToken: idToken)
    }
}
