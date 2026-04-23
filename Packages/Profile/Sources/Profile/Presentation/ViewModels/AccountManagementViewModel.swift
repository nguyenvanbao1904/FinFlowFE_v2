import FinFlowCore
import Observation

/// ViewModel cho Account Management section
/// Responsibility: Quản lý password change và account deletion
@MainActor
@Observable
public final class AccountManagementViewModel {
    // MARK: - State
    public var alert: AppErrorAlert?
    public var otpAlert: AppErrorAlert?
    public var showDeleteAccountConfirmation = false

    // Xác nhận mật khẩu trước khi xoá tài khoản (dành cho user có password)
    public var showDeletePasswordConfirmation = false
    public var deletePasswordInput = ""
    public var isLoading = false

    // OTP State
    public var otpCode = "" {
        didSet {
            Task {
                let formatted = await otpHandler.formatInput(otpCode)
                if formatted != otpCode {
                    otpCode = formatted
                }
            }
        }
    }
    public var showOTPInput = false
    public var isSendingOTP = false

    // MARK: - Dependencies
    private let accountManagementUseCase: AccountManagementUseCaseProtocol
    private let otpHandler: OTPInputHandler
    private let router: any AppRouterProtocol
    private let sessionManager: any SessionManagerProtocol
    private let pinManager: any PINManagerProtocol
    private var userEmail: String

    /// True when session was just restored from background.
    public var isSessionRestored: Bool {
        if case .authenticated(_, let isRestored) = sessionManager.state { return isRestored }
        return false
    }

    // MARK: - Initialization
    public init(
        userEmail: String,
        accountManagementUseCase: AccountManagementUseCaseProtocol,
        otpHandler: OTPInputHandler,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol,
        pinManager: any PINManagerProtocol
    ) {
        self.userEmail = userEmail
        self.accountManagementUseCase = accountManagementUseCase
        self.otpHandler = otpHandler
        self.router = router
        self.sessionManager = sessionManager
        self.pinManager = pinManager
    }

    // MARK: - Public Methods

    /// Update user email (when profile changes)
    public func updateUserEmail(_ email: String) {
        self.userEmail = email
    }

    /// Navigate to change password screen
    public func navigateToChangePassword() {
        Task {
            let hasPassword = await sessionManager.hasPassword()
            await MainActor.run {
                router.navigate(to: .changePassword(hasPassword: hasPassword))
            }
        }
    }

    /// Initiate account deletion (show confirmation)
    public func initiateAccountDeletion() {
        Task {
            let hasPassword = await sessionManager.hasPassword()
            await MainActor.run {
                if hasPassword {
                    self.showDeletePasswordConfirmation = true
                } else {
                    self.showDeleteAccountConfirmation = true
                }
            }
        }
    }

    /// Send OTP for account deletion
    public func sendDeleteAccountOTP() async {
        isLoading = true
        isSendingOTP = true

        do {
            try await otpHandler.sendOTP(to: userEmail, purpose: .deleteAccount)
            showDeleteAccountConfirmation = false
            showOTPInput = true
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi gửi mã OTP")
        }

        isLoading = false
        isSendingOTP = false
    }

    /// Confirm delete account with OTP
    public func confirmDeleteAccountWithOTP() async {
        isLoading = true

        do {
            let response = try await otpHandler.verifyOTP(
                email: userEmail,
                code: otpCode,
                purpose: .deleteAccount
            )

            let token = response.registrationToken
            if token.isEmpty { throw AppError.unknown }

            let passwordToSend = deletePasswordInput.isEmpty ? nil : deletePasswordInput
            try await accountManagementUseCase.deleteAccount(
                password: passwordToSend,
                token: token
            )

            Logger.info("Account soft-deleted, performing cleanup", category: "AccountVM")

            otpAlert = .success(
                message: "Tài khoản của bạn sẽ bị xóa vĩnh viễn sau 30 ngày.\n\nNếu bạn đăng nhập lại trong thời gian này, quá trình xóa sẽ bị hủy và tài khoản được khôi phục."
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await self.pinManager.deletePIN(for: self.userEmail)
                    await self.sessionManager.logoutCompletely()
                    self.showOTPInput = false
                    self.otpCode = ""
                    self.deletePasswordInput = ""
                }
            }

        } catch let error as OTPInputHandler.OTPError {
            otpCode = ""
            otpAlert = .auth(message: error.localizedDescription)
        } catch {
            otpCode = ""
            otpAlert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Xác Thực OTP")
        }

        isLoading = false
    }

    /// Cancel account deletion
    public func cancelAccountDeletion() {
        showDeleteAccountConfirmation = false
        showOTPInput = false
        otpCode = ""
        deletePasswordInput = ""
    }

    /// Xác nhận mật khẩu để xoá tài khoản — verify qua UseCase, nếu đúng mở bước OTP
    public func confirmDeletePassword() async {
        guard !deletePasswordInput.isEmpty else { return }

        do {
            try await accountManagementUseCase.verifyPassword(
                email: userEmail,
                password: deletePasswordInput
            )
            showDeletePasswordConfirmation = false
            showDeleteAccountConfirmation = true
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi xác thực")
        }
    }

    /// Logout (soft — chỉ xóa access token)
    public func logout() async {
        Logger.info("Người dùng đăng xuất (Soft Logout)", category: "AccountVM")
        showDeleteAccountConfirmation = false
        showDeletePasswordConfirmation = false
        showOTPInput = false
        otpCode = ""
        deletePasswordInput = ""
        otpAlert = nil
        alert = nil
        router.dismissSheet()
        await sessionManager.logout()
        Logger.info("Soft Logout completed", category: "AccountVM")
    }

    /// Logout completely (clear refresh token)
    public func logoutCompletely() async {
        Logger.info("Người dùng đăng xuất hoàn toàn (switch account)", category: "AccountVM")
        do {
            try await accountManagementUseCase.logout()
            await sessionManager.logoutCompletely()
            Logger.info("Complete logout finished", category: "AccountVM")
        } catch {
            Logger.error("Lỗi khi complete logout: \(error)", category: "AccountVM")
            await sessionManager.logoutCompletely()
        }
    }
}
