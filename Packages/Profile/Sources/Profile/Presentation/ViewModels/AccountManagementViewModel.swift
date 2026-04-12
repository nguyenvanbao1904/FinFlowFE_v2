//
//  AccountManagementViewModel.swift
//  Dashboard
//

import FinFlowCore
import Observation

/// ViewModel cho Account Management section
/// Responsibility: Quản lý password change và account deletion
@MainActor
@Observable
public class AccountManagementViewModel {
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
    private let authRepository: AuthRepositoryProtocol
    private let otpHandler: OTPInputHandler
    private let router: any AppRouterProtocol
    public let sessionManager: any SessionManagerProtocol
    private let pinManager: any PINManagerProtocol
    private var userEmail: String
    
    // MARK: - Initialization
    public init(
        userEmail: String,
        authRepository: AuthRepositoryProtocol,
        otpHandler: OTPInputHandler,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol,
        pinManager: any PINManagerProtocol
    ) {
        self.userEmail = userEmail
        self.authRepository = authRepository
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
        // Kiểm tra xem user hiện tại có mật khẩu không
        Task {
            let hasPassword = await sessionManager.hasPassword()
            
            await MainActor.run {
                if hasPassword {
                    // User có password -> yêu cầu nhập mật khẩu trước
                    self.showDeletePasswordConfirmation = true
                } else {
                    // User social (không có password) -> đi thẳng tới bước gửi OTP
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
            showOTPInput = true // Show OTP Sheet
        } catch {
            if let appError = error as? AppError {
                alert = .auth(message: appError.localizedDescription)
            } else {
                alert = .general(title: "Lỗi gửi mã OTP", message: error.localizedDescription)
            }
        }
        
        isLoading = false
        isSendingOTP = false
    }
    
    /// Confirm delete account with OTP
    public func confirmDeleteAccountWithOTP() async {
        isLoading = true
        
        do {
            // Verify OTP -> Get Token
            let response = try await otpHandler.verifyOTP(
                email: userEmail,
                code: otpCode,
                purpose: .deleteAccount
            )
            
            let token = response.registrationToken
            if token.isEmpty {
                 throw AppError.unknown
            }
            
            // Delete Account with Token + Password (nếu có)
            let passwordToSend = deletePasswordInput.isEmpty ? nil : deletePasswordInput
            try await authRepository.deleteAccount(password: passwordToSend, token: token)
            
            Logger.info("Account soft-deleted, performing cleanup", category: "AccountVM")
            
            // Show success alert on OTP sheet
            otpAlert = .success(
                message: "Tài khoản của bạn sẽ bị xóa vĩnh viễn sau 30 ngày.\n\nNếu bạn đăng nhập lại trong thời gian này, quá trình xóa sẽ bị hủy và tài khoản được khôi phục."
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    
                    // Cleanup AFTER user confirms
                    try? await self.pinManager.deletePIN(for: self.userEmail)
                    await self.sessionManager.logoutCompletely()
                    
                    self.showOTPInput = false
                    self.otpCode = ""
                    self.deletePasswordInput = ""
                }
            }
            
        } catch let error as OTPInputHandler.OTPError {
            // Show error on OTP sheet, clear OTP but KEEP sheet open for retry
            otpCode = ""  // Clear for retry
            otpAlert = .auth(message: error.localizedDescription)
        } catch {
            // Show error on OTP sheet, clear OTP but KEEP sheet open for retry
            otpCode = ""  // Clear for retry
            
            if let appError = error as? AppError {
                otpAlert = .auth(message: appError.localizedDescription)
            } else {
                otpAlert = .general(title: "Lỗi xác thực OTP", message: error.localizedDescription)
            }
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

    /// Xử lý khi user xác nhận mật khẩu để xoá tài khoản
    /// Verify password bằng login API, nếu đúng thì mở bước gửi OTP
    public func confirmDeletePassword() async {
        guard !deletePasswordInput.isEmpty else { return }

        do {
            let request = LoginRequest(username: userEmail, password: deletePasswordInput)
            _ = try await authRepository.login(req: request)
            // Mật khẩu đúng -> đóng sheet, mở alert xác nhận gửi OTP
            showDeletePasswordConfirmation = false
            showDeleteAccountConfirmation = true
        } catch {
            // Sai mật khẩu -> hiển thị qua alertHandler
            alert = error.toAppAlert(defaultTitle: "Lỗi xác thực")
        }
    }
    
    /// Logout (keep refresh token)
    public func logout() async {
        Logger.info("Người dùng đăng xuất (Soft Logout)", category: "AccountVM")
        // Close any active account-related UI before session transition.
        showDeleteAccountConfirmation = false
        showDeletePasswordConfirmation = false
        showOTPInput = false
        otpCode = ""
        deletePasswordInput = ""
        otpAlert = nil
        alert = nil
        router.dismissSheet()
        // We only clear access token locally.
        await sessionManager.logout()
        Logger.info("Soft Logout completed", category: "AccountVM")
    }
    
    /// Logout completely (clear refresh token)
    public func logoutCompletely() async {
        Logger.info("Người dùng đăng xuất hoàn toàn (switch account)", category: "AccountVM")
        do {
            try await authRepository.logout()
            await sessionManager.logoutCompletely()
            Logger.info("Complete logout finished", category: "AccountVM")
        } catch {
            Logger.error("Lỗi khi complete logout: \(error)", category: "AccountVM")
            await sessionManager.logoutCompletely()
        }
    }
}
