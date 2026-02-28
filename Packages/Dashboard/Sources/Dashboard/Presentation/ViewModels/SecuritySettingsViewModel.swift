//
//  SecuritySettingsViewModel.swift
//  Dashboard
//

import FinFlowCore
import LocalAuthentication

/// ViewModel cho Security Settings section
/// Responsibility: Quản lý PIN và Biometric authentication
@MainActor
@Observable
public class SecuritySettingsViewModel {
    // MARK: - State
    public var pinAlert: AppErrorAlert?
    public var shouldShowCreatePIN = false
    public var showPINVerification = false
    public var isBiometricEnabled = false
    public var pendingBiometricToggle: Bool?
    public var showForgotPINAlert = false
    
    // Reset PIN State
    public var showResetPinOtpInput = false
    public var resetPinOtpCode = ""
    public var isSendingResetPinOTP = false
    public var otpErrorMessage: String?
    public var isLoading = false
    
    // MARK: - Dependencies
    private let pinManager: any PINManagerProtocol
    private let authRepository: AuthRepositoryProtocol
    public let sessionManager: any SessionManagerProtocol
    private let otpHandler: OTPInputHandler
    private var userEmail: String
    
    // MARK: - Initialization
    public init(
        userEmail: String,
        pinManager: any PINManagerProtocol,
        authRepository: AuthRepositoryProtocol,
        sessionManager: any SessionManagerProtocol,
        otpHandler: OTPInputHandler
    ) {
        self.userEmail = userEmail
        self.pinManager = pinManager
        self.authRepository = authRepository
        self.sessionManager = sessionManager
        self.otpHandler = otpHandler
    }
    
    // MARK: - Public Methods
    
    /// Update user email (when profile changes)
    public func updateUserEmail(_ email: String) {
        self.userEmail = email
    }
    
    /// Check if PIN exists and update UI
    public func checkPINRequirement() async {
        let hasPIN = await pinManager.hasPIN(for: userEmail)
        if !hasPIN {
            Logger.info("Chưa có PIN, yêu cầu tạo mới", category: "SecurityVM")
            shouldShowCreatePIN = true
        } else {
            Logger.info("Đã có PIN", category: "SecurityVM")
            shouldShowCreatePIN = false
        }
    }
    
    public func makeCreatePINViewModel() -> CreatePINViewModel {
        return CreatePINViewModel(email: userEmail, pinManager: pinManager) { [weak self] in
            Task { @MainActor in
                self?.shouldShowCreatePIN = false
            }
        }
    }
    
    /// Toggle biometric (shows PIN verification)
    public func toggleBiometric(_ enabled: Bool) {
        if enabled {
            guard checkBiometricCapability() else {
                pinAlert = .general(
                    title: "Không hỗ trợ",
                    message: "Thiết bị không hỗ trợ hoặc chưa cài đặt Face ID / Touch ID."
                )
                return
            }
        }
        pendingBiometricToggle = enabled
        showPINVerification = true
    }
    
    /// Verify PIN and toggle biometric
    public func verifyPINAndToggleBiometric(pin: String) async {
        guard let enabled = pendingBiometricToggle else { return }
        
        do {
            let isPINCorrect = await pinManager.verifyPIN(pin, for: userEmail)
            
            guard isPINCorrect else {
                pinAlert = .auth(message: "Mã PIN không đúng")
                return
            }
            
            try await authRepository.toggleBiometric(enabled: enabled)
            
            // Update UI State immediately
            Task { @MainActor in
                self.isBiometricEnabled = enabled
                self.showPINVerification = false
                self.pendingBiometricToggle = nil
                self.pinAlert = nil // Clear any previous alerts
                
                // ✅ Manually update local user profile to persist biometric state
                if let currentUser = self.sessionManager.currentUser {
                    let updatedUser = currentUser.copy(isBiometricEnabled: enabled)
                    self.sessionManager.updateCurrentUser(updatedUser)
                }
            }
            
            Logger.info("✅ Biometric toggled: \(enabled)", category: "SecurityVM")
        } catch {
            // Nếu session hết hạn/refresh token hỏng -> yêu cầu user đăng nhập lại
            if let appError = error as? AppError, case .unauthorized = appError {
                pinAlert = .authWithAction(message: "Phiên đăng nhập đã hết hạn hoặc không còn hiệu lực. Vui lòng đăng nhập lại.") { [sessionManager] in
                    Task { @MainActor in
                        await sessionManager.clearExpiredSession()
                    }
                }
            } else {
                pinAlert = error.toAppAlert(defaultTitle: "Lỗi")
            }
        }
    }
    
    /// Handle forgot PIN for settings changes
    public func forgotPINForSettings() {
        showForgotPINAlert = true
    }
    
    /// Send OTP to reset PIN
    public func sendResetPinOTP() async {
        isLoading = true
        isSendingResetPinOTP = true
        otpErrorMessage = nil
        
        do {
            try await otpHandler.sendOTP(to: userEmail, purpose: .resetPin)
            showForgotPINAlert = false // Close the alert
            showPINVerification = false // Close the PIN sheet
            showResetPinOtpInput = true // Show OTP Sheet
        } catch {
            pinAlert = error.toAppAlert(defaultTitle: "Lỗi gửi mã OTP")
        }
        
        isLoading = false
        isSendingResetPinOTP = false
    }
    
    /// Confirm reset PIN with OTP
    public func confirmResetPinWithOTP() async {
        guard resetPinOtpCode.count >= 6 else { return }
        
        isLoading = true
        otpErrorMessage = nil
        
        do {
            // 1. Verify OTP
            let _ = try await otpHandler.verifyOTP(email: userEmail, code: resetPinOtpCode, purpose: .resetPin)
            
            // 2. Delete PIN
            try await pinManager.deletePIN(for: userEmail)
            
            // 3. Cleanup UI
            showResetPinOtpInput = false
            resetPinOtpCode = ""
            
            // 4. Trigger Create PIN flow
            shouldShowCreatePIN = true
            
            pinAlert = .general(title: "Thành công", message: "Mã PIN đã được xóa. Vui lòng tạo mã PIN mới.")
            
        } catch {
            otpErrorMessage = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
        
        isLoading = false
    }

    // MARK: - Private Methods

    /// Check if device supports biometric
    private func checkBiometricCapability() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}
