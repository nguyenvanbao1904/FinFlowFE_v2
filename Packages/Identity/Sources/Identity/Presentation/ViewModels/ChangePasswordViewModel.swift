import FinFlowCore
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public class ChangePasswordViewModel {
    public var oldPassword = ""
    public var newPassword = ""
    public var confirmPassword = ""
    public var isLoading = false
    public var alert: AppErrorAlert?
    public var isSuccess = false
    public let isCreatingPassword: Bool

    private let authRepository: AuthRepositoryProtocol
    private let sessionManager: any SessionManagerProtocol
    private let onSuccess: () -> Void

    public init(
        authRepository: AuthRepositoryProtocol,
        sessionManager: any SessionManagerProtocol,
        isCreatingPassword: Bool = false,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.authRepository = authRepository
        self.sessionManager = sessionManager
        self.isCreatingPassword = isCreatingPassword
        self.onSuccess = onSuccess
    }

    public func changePassword() async {
        // Validate inputs
        if !isCreatingPassword && oldPassword.isEmpty {
            alert = .general(title: "Thông báo", message: "Vui lòng nhập mật khẩu cũ")
            return
        }
        
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            alert = .general(title: "Thông báo", message: "Vui lòng nhập mật khẩu mới và xác nhận")
            return
        }

        guard newPassword == confirmPassword else {
            alert = .general(title: "Lỗi", message: "Mật khẩu xác nhận không khớp")
            return
        }

        // Password length check removed to rely on backend validation
        // guard newPassword.count >= 6 else { ... }

        isLoading = true
        defer { isLoading = false }

        do {
            let request = ChangePasswordRequest(
                oldPassword: isCreatingPassword ? nil : oldPassword,
                newPassword: newPassword
            )
            try await authRepository.changePassword(req: request)
            
            Logger.info("Change password success", category: "Auth")
            
            // ✅ FIX: Reload user profile to sync `hasPassword` state locally
            await sessionManager.loadCurrentUser()
            
            isSuccess = true
            
            // ✅ FIX: Show alert with OK button, triggering dismiss only when user taps OK
            alert = .success(message: "Đổi mật khẩu thành công") { [weak self] in
                Task { @MainActor in
                    self?.onSuccess()
                }
            }
            
        } catch {
            Logger.error("Change password failed: \(error)", category: "Auth")
            if let appError = error as? AppError {
                alert = .auth(message: appError.localizedDescription)
            } else {
                alert = .general(title: "Lỗi", message: error.localizedDescription)
            }
        }
    }
}
