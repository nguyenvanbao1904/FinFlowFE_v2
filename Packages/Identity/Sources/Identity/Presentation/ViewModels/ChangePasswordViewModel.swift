import FinFlowCore
import Observation
import SwiftUI

@MainActor
@Observable
public final class ChangePasswordViewModel {
    public var oldPassword = ""
    public var newPassword = ""
    public var confirmPassword = ""
    public var isLoading = false
    public var alert: AppErrorAlert?
    public var isSuccess = false
    public let isCreatingPassword: Bool

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol
    private let sessionManager: any SessionManagerProtocol
    private let onSuccess: () -> Void

    public init(
        changePasswordUseCase: ChangePasswordUseCaseProtocol,
        sessionManager: any SessionManagerProtocol,
        isCreatingPassword: Bool = false,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.changePasswordUseCase = changePasswordUseCase
        self.sessionManager = sessionManager
        self.isCreatingPassword = isCreatingPassword
        self.onSuccess = onSuccess
    }

    public func changePassword() async {
        // UI-level guard: oldPassword chỉ required khi user đã có password
        if !isCreatingPassword && oldPassword.isEmpty {
            alert = .general(title: "Thông báo", message: "Vui lòng nhập mật khẩu cũ")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await changePasswordUseCase.execute(
                oldPassword: isCreatingPassword ? nil : oldPassword,
                newPassword: newPassword,
                confirmPassword: confirmPassword
            )

            Logger.info("Change password success", category: "Auth")

            // Reload user profile để sync `hasPassword` state
            await sessionManager.loadCurrentUser()

            isSuccess = true
            alert = .success(message: "Đổi mật khẩu thành công") { [weak self] in
                Task { @MainActor in
                    self?.onSuccess()
                }
            }
        } catch {
            Logger.error("Change password failed: \(error)", category: "Auth")
            alert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Đổi Mật Khẩu")
        }
    }
}
