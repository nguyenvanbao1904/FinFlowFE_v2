import FinFlowCore
import Foundation

// MARK: - Logout Use Case

/// Use Case: Logout User
///
/// Protocol defined in FinFlowCore to allow usage across feature modules without circular dependency.
/// Implementation here in Identity module.
public struct LogoutUseCase: LogoutUseCaseProtocol {
    private let repository: AuthenticationRepositoryProtocol

    public init(repository: AuthenticationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws {
        Logger.info("🔓 Executing logout", category: "UseCase")
        try await repository.logout()
        Logger.info("✅ Logout completed", category: "UseCase")
    }
}
