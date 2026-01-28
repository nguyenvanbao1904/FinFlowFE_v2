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
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(username: String, password: String) async throws -> LoginResponse {
        // Business logic: Validation
        guard !username.isEmpty, !password.isEmpty else {
            throw AppError.serverError(1003, "Username and password are required")
        }

        // Business logic: Data sanitization
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        Logger.info("Executing login use case for user: \(cleanUsername)", category: "UseCase")

        // Call repository with clean data
        let request = LoginRequest(username: cleanUsername, password: cleanPassword)
        let response = try await repository.login(req: request)

        Logger.info("Login use case completed successfully", category: "UseCase")
        return response
    }
    
    public func executeGoogle(idToken: String) async throws -> LoginResponse {
        Logger.info("Executing Google login use case", category: "UseCase")
        let response = try await repository.loginGoogle(idToken: idToken)
        Logger.info("Google login use case completed successfully", category: "UseCase")
        return response
    }
}

// MARK: - Logout Use Case

/// Use Case: Logout User
///
/// Protocol defined in FinFlowCore to allow usage across feature modules without circular dependency.
/// Implementation here in Identity module.
public struct LogoutUseCase: LogoutUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws {
        Logger.info("🔓 Executing logout", category: "UseCase")
        try await repository.logout()
        Logger.info("✅ Logout completed", category: "UseCase")
    }
}
