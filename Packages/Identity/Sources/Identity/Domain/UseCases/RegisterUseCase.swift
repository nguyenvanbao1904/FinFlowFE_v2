import FinFlowCore
import Foundation

// MARK: - Register Use Case

public protocol RegisterUseCaseProtocol: Sendable {
    func execute(request: RegisterRequest) async throws
}

public struct RegisterUseCase: RegisterUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(request: RegisterRequest) async throws {
        // Validation logic
        guard !request.username.isEmpty, 
              !request.password.isEmpty, 
              !request.email.isEmpty else {
            throw AppError.serverError(1003, "Vui lòng điền đầy đủ thông tin")
        }
        
        // Trim inputs
        let cleanRequest = RegisterRequest(
            username: request.username.trimmingCharacters(in: .whitespacesAndNewlines),
            email: request.email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: request.password, // Password should potentially not be trimmed or handled carefully
            firstName: request.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: request.lastName?.trimmingCharacters(in: .whitespacesAndNewlines),
            dob: request.dob
        )

        Logger.info("Executing register use case", category: "UseCase")
        try await repository.register(req: cleanRequest)
        Logger.info("Register use case completed", category: "UseCase")
    }
}
