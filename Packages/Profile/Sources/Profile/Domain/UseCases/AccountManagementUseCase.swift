import FinFlowCore

// MARK: - Account Management Use Case

public protocol AccountManagementUseCaseProtocol: Sendable {
    /// Xác minh mật khẩu bằng cách thử login. Throw nếu sai.
    func verifyPassword(email: String, password: String) async throws

    /// Xóa tài khoản với OTP token (và mật khẩu nếu user có password).
    func deleteAccount(password: String?, token: String) async throws

    /// Đăng xuất mềm — chỉ xóa access token local.
    func logout() async throws
}

public struct AccountManagementUseCase: AccountManagementUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func verifyPassword(email: String, password: String) async throws {
        // Dùng login API để verify — nếu sai password sẽ throw AppError.serverError
        let request = LoginRequest(username: email, password: password)
        _ = try await repository.login(req: request)
    }

    public func deleteAccount(password: String?, token: String) async throws {
        try await repository.deleteAccount(password: password, token: token)
    }

    public func logout() async throws {
        try await repository.logout()
    }
}
