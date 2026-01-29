import FinFlowCore
import Foundation

// MARK: - Forgot Password Use Case

public protocol ForgotPasswordUseCaseProtocol: Sendable {
    func sendOtp(email: String) async throws
    func verifyOtp(email: String, otp: String) async throws -> VerifyOtpResponse
    func resetPassword(password: String, confirmPassword: String, token: String) async throws
    func checkUserExistence(email: String) async throws -> Bool
}

public struct ForgotPasswordUseCase: ForgotPasswordUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func sendOtp(email: String) async throws {
        Logger.info("Sending Reset Password OTP to \(email)", category: "UseCase")
        try await repository.sendOtp(email: email, purpose: .resetPassword)
    }

    public func verifyOtp(email: String, otp: String) async throws -> VerifyOtpResponse {
        Logger.info("Verifying Reset Password OTP for \(email)", category: "UseCase")
        return try await repository.verifyOtp(email: email, otp: otp, purpose: .resetPassword)
    }
    
    public func resetPassword(password: String, confirmPassword: String, token: String) async throws {
        // Business logic validation for password match
        guard password == confirmPassword else {
            throw AppError.validationError("Mật khẩu xác nhận không khớp")
        }
        
        guard password.count >= 6 else {
            throw AppError.validationError("Mật khẩu phải có ít nhất 6 ký tự")
        }
    
        Logger.info("Resetting password", category: "UseCase")
        let request = ResetPasswordRequest(password: password, confirmPassword: confirmPassword)
        try await repository.resetPassword(req: request, token: token)
    }

    public func checkUserExistence(email: String) async throws -> Bool {
        return try await repository.checkUserExistence(email: email)
    }
}
