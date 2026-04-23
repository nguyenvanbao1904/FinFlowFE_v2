import FinFlowCore

// MARK: - Change Password Use Case

public protocol ChangePasswordUseCaseProtocol: Sendable {
    /// Đổi mật khẩu. Validate match + empty trước khi gọi repository.
    /// - Parameters:
    ///   - oldPassword: Mật khẩu cũ (nil nếu user chưa có password — social login).
    ///   - newPassword: Mật khẩu mới.
    ///   - confirmPassword: Xác nhận mật khẩu mới.
    func execute(oldPassword: String?, newPassword: String, confirmPassword: String) async throws
}

public struct ChangePasswordUseCase: ChangePasswordUseCaseProtocol {
    private let repository: AccountRepositoryProtocol

    public init(repository: AccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        oldPassword: String?,
        newPassword: String,
        confirmPassword: String
    ) async throws {
        // Validate: mật khẩu mới không rỗng
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            throw AppError.validationError("Vui lòng nhập mật khẩu mới và xác nhận")
        }

        // Validate: hai mật khẩu khớp nhau
        guard newPassword == confirmPassword else {
            throw AppError.validationError("Mật khẩu xác nhận không khớp")
        }

        let request = ChangePasswordRequest(
            oldPassword: oldPassword,
            newPassword: newPassword
        )
        try await repository.changePassword(req: request)
    }
}
