import Testing
import Foundation
@testable import Identity
import FinFlowCore

// MARK: - RegisterUseCase Tests
// RegisterUseCase có business logic:
// 1. Validate required fields không rỗng
// 2. Trim whitespace cho username, email, firstName, lastName
// 3. Forward clean request + registrationToken đến repository

@Suite("RegisterUseCase")
struct RegisterUseCaseTests {

    // RegisterUseCase cần repository conform 3 protocols cùng lúc
    private func makeSUT(
        repository: MockAuthRepository = MockAuthRepository()
    ) -> (sut: RegisterUseCase, repository: MockAuthRepository) {
        let sut = RegisterUseCase(repository: repository)
        return (sut, repository)
    }

    private func makeRequest(
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

    // MARK: - Success Path

    @Test("execute với valid request gọi repository đúng 1 lần")
    func execute_withValidRequest_callsRepositoryOnce() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(request: makeRequest(), registrationToken: "reg-token")

        #expect(repository.registerCallCount == 1)
    }

    @Test("execute truyền đúng registrationToken xuống repository")
    func execute_forwardsRegistrationTokenToRepository() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(request: makeRequest(), registrationToken: "my-reg-token-abc")

        #expect(repository.lastRegisterToken == "my-reg-token-abc")
    }

    // MARK: - Input Sanitization

    @Test("execute trim whitespace từ username")
    func execute_trimsUsernameWhitespace() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(
            request: makeRequest(username: "  newuser  "),
            registrationToken: "token"
        )

        let captured = try #require(repository.lastRegisterRequest)
        #expect(captured.username == "newuser")
    }

    @Test("execute trim whitespace từ email")
    func execute_trimsEmailWhitespace() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(
            request: makeRequest(email: "  user@example.com  "),
            registrationToken: "token"
        )

        let captured = try #require(repository.lastRegisterRequest)
        #expect(captured.email == "user@example.com")
    }

    @Test("execute trim whitespace từ firstName khi có giá trị")
    func execute_trimsFirstNameWhitespace() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(
            request: makeRequest(firstName: "  Nguyen  "),
            registrationToken: "token"
        )

        let captured = try #require(repository.lastRegisterRequest)
        #expect(captured.firstName == "Nguyen")
    }

    @Test("execute trim whitespace từ lastName khi có giá trị")
    func execute_trimsLastNameWhitespace() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(
            request: makeRequest(lastName: "  Van A  "),
            registrationToken: "token"
        )

        let captured = try #require(repository.lastRegisterRequest)
        #expect(captured.lastName == "Van A")
    }

    @Test("execute khi firstName = nil → vẫn forward nil (không crash)")
    func execute_withNilFirstName_forwardsNil() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(
            request: makeRequest(firstName: nil, lastName: nil),
            registrationToken: "token"
        )

        let captured = try #require(repository.lastRegisterRequest)
        #expect(captured.firstName == nil)
        #expect(captured.lastName == nil)
    }

    @Test("execute không thay đổi password (không trim password)")
    func execute_doesNotModifyPassword() async throws {
        let (sut, repository) = makeSUT()

        try await sut.execute(
            request: makeRequest(password: "pass with spaces"),
            registrationToken: "token"
        )

        let captured = try #require(repository.lastRegisterRequest)
        #expect(captured.password == "pass with spaces")
    }

    // MARK: - Validation

    @Test("execute với username rỗng → throw serverError, không gọi repository")
    func execute_withEmptyUsername_throwsServerError() async throws {
        let (sut, repository) = makeSUT()

        await #expect(throws: AppError.self) {
            try await sut.execute(request: makeRequest(username: ""), registrationToken: "token")
        }
        #expect(repository.registerCallCount == 0)
    }

    @Test("execute với password rỗng → throw serverError, không gọi repository")
    func execute_withEmptyPassword_throwsServerError() async throws {
        let (sut, repository) = makeSUT()

        await #expect(throws: AppError.self) {
            try await sut.execute(request: makeRequest(password: ""), registrationToken: "token")
        }
        #expect(repository.registerCallCount == 0)
    }

    @Test("execute với email rỗng → throw serverError, không gọi repository")
    func execute_withEmptyEmail_throwsServerError() async throws {
        let (sut, repository) = makeSUT()

        await #expect(throws: AppError.self) {
            try await sut.execute(request: makeRequest(email: ""), registrationToken: "token")
        }
        #expect(repository.registerCallCount == 0)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw networkError → propagate error")
    func execute_whenRepositoryThrowsNetworkError_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = IdentityMockError.networkFailure

        await #expect(throws: IdentityMockError.networkFailure) {
            try await sut.execute(request: makeRequest(), registrationToken: "token")
        }
    }

    @Test("execute khi repository throw serverError (email đã tồn tại) → propagate error")
    func execute_whenEmailAlreadyExists_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = AppError.serverError(1002, "Email đã tồn tại")

        await #expect(throws: AppError.self) {
            try await sut.execute(request: makeRequest(), registrationToken: "token")
        }
    }

    // MARK: - sendOtp

    @Test("sendOtp gọi repository với email và purpose=register")
    func sendOtp_forwardsEmailAndRegisterPurpose() async throws {
        let (sut, repository) = makeSUT()

        try await sut.sendOtp(email: "new@example.com")

        #expect(repository.sendOtpCallCount == 1)
        #expect(repository.lastSendOtpEmail == "new@example.com")
        #expect(repository.lastSendOtpPurpose == .register)
    }

    @Test("sendOtp không dùng purpose=resetPassword (phân biệt với ForgotPasswordUseCase)")
    func sendOtp_doesNotUsePurposeResetPassword() async throws {
        let (sut, repository) = makeSUT()

        try await sut.sendOtp(email: "new@example.com")

        #expect(repository.lastSendOtpPurpose != .resetPassword)
    }

    // MARK: - verifyOtp

    @Test("verifyOtp gọi repository với email, otp, purpose=register")
    func verifyOtp_forwardsEmailOtpAndRegisterPurpose() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.verifyOtp(email: "new@example.com", otp: "789012")

        #expect(repository.verifyOtpCallCount == 1)
        #expect(repository.lastVerifyOtpEmail == "new@example.com")
        #expect(repository.lastVerifyOtpCode == "789012")
        #expect(repository.lastVerifyOtpPurpose == .register)
    }

    @Test("verifyOtp trả về VerifyOtpResponse từ repository")
    func verifyOtp_returnsRegistrationToken() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedVerifyOtpResponse = VerifyOtpResponse.mock(registrationToken: "reg-token-xyz")

        let result = try await sut.verifyOtp(email: "new@example.com", otp: "123456")

        #expect(result.registrationToken == "reg-token-xyz")
    }

    // MARK: - checkEmailExists

    @Test("checkEmailExists trả về true khi email tồn tại")
    func checkEmailExists_whenEmailExists_returnsTrue() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCheckUserExistence = CheckUserExistenceResponse.mockExists()

        let exists = try await sut.checkEmailExists(email: "existing@example.com")

        #expect(exists == true)
    }

    @Test("checkEmailExists trả về false khi email chưa tồn tại")
    func checkEmailExists_whenEmailNotExists_returnsFalse() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCheckUserExistence = CheckUserExistenceResponse.mockNotExists()

        let exists = try await sut.checkEmailExists(email: "new@example.com")

        #expect(exists == false)
    }

    // MARK: - checkUsernameExists

    @Test("checkUsernameExists trả về true khi username tồn tại")
    func checkUsernameExists_whenUsernameExists_returnsTrue() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCheckUserExistence = CheckUserExistenceResponse.mockExists()

        let exists = try await sut.checkUsernameExists(username: "takenuser")

        #expect(exists == true)
    }

    @Test("checkUsernameExists trả về false khi username chưa tồn tại")
    func checkUsernameExists_whenUsernameNotExists_returnsFalse() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCheckUserExistence = CheckUserExistenceResponse.mockNotExists()

        let exists = try await sut.checkUsernameExists(username: "freshuser")

        #expect(exists == false)
    }
}
