import Testing
import Foundation
@testable import Identity
import FinFlowCore

// MARK: - ForgotPasswordUseCase Tests
// ForgotPasswordUseCase có business logic:
// 1. resetPassword: validate password match + length >= 6
// 2. sendOtp: forward email + purpose=resetPassword
// 3. verifyOtp: forward với purpose=resetPassword

@Suite("ForgotPasswordUseCase")
struct ForgotPasswordUseCaseTests {

    private func makeSUT(
        repository: MockAuthRepository = MockAuthRepository()
    ) -> (sut: ForgotPasswordUseCase, repository: MockAuthRepository) {
        let sut = ForgotPasswordUseCase(repository: repository)
        return (sut, repository)
    }

    // MARK: - sendOtp

    @Test("sendOtp gọi repository với email và purpose=resetPassword")
    func sendOtp_forwardsEmailAndResetPasswordPurpose() async throws {
        let (sut, repository) = makeSUT()

        try await sut.sendOtp(email: "user@example.com")

        #expect(repository.sendOtpCallCount == 1)
        #expect(repository.lastSendOtpEmail == "user@example.com")
        #expect(repository.lastSendOtpPurpose == .resetPassword)
    }

    @Test("sendOtp không dùng purpose=register (phân biệt với RegisterUseCase)")
    func sendOtp_doesNotUsePurposeRegister() async throws {
        let (sut, repository) = makeSUT()

        try await sut.sendOtp(email: "user@example.com")

        #expect(repository.lastSendOtpPurpose != .register)
    }

    @Test("sendOtp khi repository throw → propagate error")
    func sendOtp_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = IdentityMockError.networkFailure

        await #expect(throws: IdentityMockError.networkFailure) {
            try await sut.sendOtp(email: "user@example.com")
        }
    }

    // MARK: - verifyOtp

    @Test("verifyOtp gọi repository với email, otp, purpose=resetPassword")
    func verifyOtp_forwardsEmailOtpAndResetPasswordPurpose() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.verifyOtp(email: "user@example.com", otp: "123456")

        #expect(repository.verifyOtpCallCount == 1)
        #expect(repository.lastVerifyOtpEmail == "user@example.com")
        #expect(repository.lastVerifyOtpCode == "123456")
        #expect(repository.lastVerifyOtpPurpose == .resetPassword)
    }

    @Test("verifyOtp trả về VerifyOtpResponse từ repository")
    func verifyOtp_returnsResponseFromRepository() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedVerifyOtpResponse = VerifyOtpResponse.mock(
            message: "Xác minh OTP thành công",
            registrationToken: "reset-token-xyz"
        )

        let result = try await sut.verifyOtp(email: "user@example.com", otp: "654321")

        #expect(result.message == "Xác minh OTP thành công")
        #expect(result.registrationToken == "reset-token-xyz")
    }

    @Test("verifyOtp không dùng purpose=register")
    func verifyOtp_doesNotUsePurposeRegister() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.verifyOtp(email: "user@example.com", otp: "000000")

        #expect(repository.lastVerifyOtpPurpose != .register)
    }

    @Test("verifyOtp khi repository throw → propagate error")
    func verifyOtp_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = IdentityMockError.serverError(code: 400)

        await #expect(throws: IdentityMockError.serverError(code: 400)) {
            _ = try await sut.verifyOtp(email: "user@example.com", otp: "wrong")
        }
    }

    // MARK: - resetPassword (Business Logic)

    @Test("resetPassword với password hợp lệ gọi repository đúng 1 lần")
    func resetPassword_withValidPassword_callsRepositoryOnce() async throws {
        let (sut, repository) = makeSUT()

        try await sut.resetPassword(password: "newpass123", confirmPassword: "newpass123", token: "reset-token")

        #expect(repository.resetPasswordCallCount == 1)
    }

    @Test("resetPassword truyền đúng token xuống repository")
    func resetPassword_forwardsTokenToRepository() async throws {
        let (sut, repository) = makeSUT()

        try await sut.resetPassword(password: "pass123", confirmPassword: "pass123", token: "my-reset-token")

        #expect(repository.lastResetPasswordToken == "my-reset-token")
    }

    @Test("resetPassword truyền đúng password xuống repository")
    func resetPassword_forwardsPasswordToRepository() async throws {
        let (sut, repository) = makeSUT()

        try await sut.resetPassword(password: "securePass99", confirmPassword: "securePass99", token: "token")

        let captured = try #require(repository.lastResetPasswordRequest)
        #expect(captured.password == "securePass99")
        #expect(captured.confirmPassword == "securePass99")
    }

    @Test("resetPassword khi password != confirmPassword → throw validationError, không gọi repository")
    func resetPassword_whenPasswordMismatch_throwsValidationErrorWithoutCallingRepository() async throws {
        let (sut, repository) = makeSUT()

        await #expect(throws: AppError.self) {
            try await sut.resetPassword(password: "pass123", confirmPassword: "different456", token: "token")
        }
        #expect(repository.resetPasswordCallCount == 0)
    }

    @Test("resetPassword khi password < 6 ký tự → throw validationError")
    func resetPassword_whenPasswordTooShort_throwsValidationError() async throws {
        let (sut, repository) = makeSUT()

        await #expect(throws: AppError.self) {
            try await sut.resetPassword(password: "12345", confirmPassword: "12345", token: "token")
        }
        #expect(repository.resetPasswordCallCount == 0)
    }

    @Test("resetPassword khi password đúng 6 ký tự → hợp lệ, gọi repository")
    func resetPassword_withExactly6CharPassword_isValid() async throws {
        let (sut, repository) = makeSUT()

        try await sut.resetPassword(password: "abc123", confirmPassword: "abc123", token: "token")

        #expect(repository.resetPasswordCallCount == 1)
    }

    @Test("resetPassword khi repository throw → propagate error")
    func resetPassword_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = IdentityMockError.networkFailure

        await #expect(throws: IdentityMockError.networkFailure) {
            try await sut.resetPassword(password: "validPass123", confirmPassword: "validPass123", token: "token")
        }
    }

    // MARK: - checkUserExistence

    @Test("checkUserExistence trả về đúng kết quả từ repository")
    func checkUserExistence_returnsResponseFromRepository() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCheckUserExistence = CheckUserExistenceResponse.mockExists()

        let result = try await sut.checkUserExistence(email: "existing@example.com")

        #expect(result.exists == true)
        #expect(result.isActive == true)
    }

    @Test("checkUserExistence khi user không tồn tại → trả về exists=false")
    func checkUserExistence_whenUserNotExists_returnsFalse() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCheckUserExistence = CheckUserExistenceResponse.mockNotExists()

        let result = try await sut.checkUserExistence(email: "new@example.com")

        #expect(result.exists == false)
    }

    @Test("checkUserExistence khi repository throw → propagate error")
    func checkUserExistence_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = IdentityMockError.networkFailure

        await #expect(throws: IdentityMockError.networkFailure) {
            _ = try await sut.checkUserExistence(email: "user@example.com")
        }
    }
}
