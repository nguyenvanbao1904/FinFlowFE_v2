//
//  SecuritySettingsViewModel.swift
//  Dashboard
//
//

import FinFlowCore
import LocalAuthentication
import Observation

/// ViewModel cho Security Settings section
/// Responsibility: Quản lý PIN và Biometric authentication
@MainActor
@Observable
public final class SecuritySettingsViewModel {
    // MARK: - State
    public var pinAlert: AppErrorAlert?
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
    private let router: any AppRouterProtocol
    private let sessionManager: any SessionManagerProtocol
    private let otpHandler: OTPInputHandler
    private var userEmail: String
    
    // MARK: - Initialization
    public init(
        userEmail: String,
        pinManager: any PINManagerProtocol,
        authRepository: AuthRepositoryProtocol,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol,
        otpHandler: OTPInputHandler
    ) {
        self.userEmail = userEmail
        self.pinManager = pinManager
        self.authRepository = authRepository
        self.router = router
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
            // Navigate to Create PIN screen
            router.navigate(to: .createPIN(email: userEmail))
        } else {
            Logger.info("Đã có PIN", category: "SecurityVM")
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
            pinAlert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi")
        }
    }
    
    /// Handle forgot PIN for settings changes
    public func forgotPINForSettings() {
        // Close PIN input first to avoid stacked/hovering modal transitions on small screens.
        showPINVerification = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            self.showForgotPINAlert = true
        }
    }

    /// Send OTP to reset PIN
    public func sendResetPinOTP() async {
        isLoading = true
        isSendingResetPinOTP = true
        otpErrorMessage = nil
        
        do {
            try await otpHandler.sendOTP(to: userEmail, purpose: .resetPin)
            showForgotPINAlert = false
            showPINVerification = false
            // Keep transition stable between alert -> sheet on iPhone small heights.
            try? await Task.sleep(for: .milliseconds(250))
            showResetPinOtpInput = true
        } catch {
            pinAlert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi gửi mã OTP")
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
            _ = try await otpHandler.verifyOTP(email: userEmail, code: resetPinOtpCode, purpose: .resetPin)
            
            // 2. Delete PIN
            try await pinManager.deletePIN(for: userEmail)
            
            // 3. Cleanup UI
            showResetPinOtpInput = false
            resetPinOtpCode = ""
            
            // 4. Trigger Create PIN flow
            router.navigate(to: .createPIN(email: userEmail))
            
            pinAlert = .general(title: "Thành công", message: "Mã PIN đã được xóa. Vui lòng tạo mã PIN mới.")
            
        } catch {
            pinAlert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi xác thực OTP")
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
