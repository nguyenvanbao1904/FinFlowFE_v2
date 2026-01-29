import FinFlowCore
import Foundation

// MARK: - Register Use Case

public protocol RegisterUseCaseProtocol: Sendable {
    func execute(request: RegisterRequest, registrationToken: String) async throws
    func sendOtp(email: String) async throws
    func verifyOtp(email: String, otp: String) async throws -> VerifyOtpResponse
}

public struct RegisterUseCase: RegisterUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(request: RegisterRequest, registrationToken: String) async throws {
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
            password: request.password, 
            firstName: request.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: request.lastName?.trimmingCharacters(in: .whitespacesAndNewlines),
            dob: request.dob
        )

        Logger.info("Executing register use case", category: "UseCase")
        try await repository.register(req: cleanRequest, token: registrationToken)
        Logger.info("Register use case completed", category: "UseCase")
    }

    public func sendOtp(email: String) async throws {
        Logger.info("Sending OTP to \(email)", category: "UseCase")
        try await repository.sendOtp(email: email, purpose: .register)
    }

    public func verifyOtp(email: String, otp: String) async throws -> VerifyOtpResponse {
        Logger.info("Verifying OTP for \(email)", category: "UseCase")
        return try await repository.verifyOtp(email: email, otp: otp, purpose: .register)
    }
}
