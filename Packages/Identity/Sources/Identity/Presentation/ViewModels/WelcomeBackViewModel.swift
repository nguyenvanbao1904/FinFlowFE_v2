//
//  WelcomeBackViewModel.swift
//  Identity
//

import FinFlowCore
import Foundation
import LocalAuthentication

@MainActor
@Observable
public class WelcomeBackViewModel {
    public var pin: String = ""
    public var isLoading = false
    public var alert: AppErrorAlert?
    public var showPINInput = false
    public var shouldResetFocus = false
    public var canUseBiometric = false
    public var biometricType: LABiometryType = .none
    private var biometricAttempts = 0
    private let maxBiometricAttempts = 3
    private let biometricHandler = BiometricAuthHandler()

    public let email: String
    public let firstName: String?
    public let lastName: String?
    private let sessionManager: any SessionManagerProtocol
    private let authRepository: AuthRepositoryProtocol
    private let otpHandler: OTPInputHandler
    private let onSwitchAccount: () -> Void

    public init(
        email: String,
        firstName: String?,
        lastName: String?,
        sessionManager: any SessionManagerProtocol,
        authRepository: AuthRepositoryProtocol,
        otpHandler: OTPInputHandler,
        onSwitchAccount: @escaping () -> Void
    ) {
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.sessionManager = sessionManager
        self.authRepository = authRepository
        self.otpHandler = otpHandler
        self.onSwitchAccount = onSwitchAccount

        Task {
            await ensurePINExistsOrLogout()
            await checkBiometricAvailability()
        }
    }

    // Computed properties
    public var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        } else if let first = firstName {
            return first
        } else if let last = lastName {
            return last
        } else {
            return email.components(separatedBy: "@").first ?? email
        }
    }

    public var canSubmitPIN: Bool {
        return pin.count == 6 && !isLoading
    }

    // Actions
    public func showPINInputScreen() {
        showPINInput = true
    }

    public func authenticateWithPIN() async {
        guard canSubmitPIN else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await sessionManager.authenticateWithPIN(pin, email: email)
            if success {
                Logger.info("✅ Welcome back authentication successful", category: "Auth")
                await sessionManager.resetPINFailCounter(for: email)
            }
        } catch {
            Logger.error("❌ Welcome back authentication failed: \(error)", category: "Auth")
            pin = ""

            // Nếu refresh token hỏng (401), hiển thị alert và chỉ khi bấm OK mới chuyển về login
            if let appError = error as? AppError, case .unauthorized = appError {
                alert = .authWithAction(message: "Phiên đăng nhập đã hết hạn hoặc không còn hiệu lực. Vui lòng đăng nhập lại.") { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        // ✅ Fix: Clear expired tokens so we go to Login
                        await self.sessionManager.clearExpiredSession()
                        self.showPINInput = false
                    }
                }
                return
            }

            let result = await sessionManager.incrementPINFailCounter(for: email)
            Logger.warning("PIN failed: allowed=\(result.allowed), attempts=\(result.attempts)/\(result.max)", category: "Security")
            if result.allowed {
                alert = .auth(
                    message:
                        "Mã PIN không đúng. Bạn đã nhập sai \(result.attempts)/\(result.max). Sai \(result.max) lần sẽ bị xóa PIN và đăng xuất.")
            } else {
                alert = .authWithAction(
                    message:
                        "Bạn đã nhập sai \(result.max) lần. PIN và phiên đăng nhập sẽ bị xóa. Nhấn OK để đăng nhập lại."
                ) { [sessionManager] in
                    Task { @MainActor in
                        await sessionManager.resetPINFailCounter(for: self.email)
                        await sessionManager.deletePIN(for: self.email)
                        // ✅ Fix: Full cleanup
                        await sessionManager.clearExpiredSession()
                        self.showPINInput = false
                    }
                }
            }
            // ✅ FIX: Trigger focus reset để user có thể nhập lại
            shouldResetFocus = true
        }
    }

    /// Nếu chưa có PIN cho email này thì logout hoàn toàn (tránh kẹt ở màn hình PIN)
    private func ensurePINExistsOrLogout() async {
        let hasPIN = await sessionManager.hasPIN(for: email)
        if !hasPIN {
            Logger.warning("No PIN set for \(email); logging out to login flow", category: "Auth")
            await sessionManager.logoutCompletely()
        }
    }

    public func switchAccount() {
        Logger.info("User switching to different account", category: "Auth")
        onSwitchAccount()
    }

    // MARK: - Forgot PIN
    // MARK: - Forgot PIN
    public var showPasswordForReset = false
    public var resetPasswordInput = ""
    
    // OTP State for Social Users
    public var showOtpInput = false
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
    public var isSendingOTP = false
    public var otpErrorMessage: String?

    public func forgotPIN() {
        Task {
            let hasPassword = await sessionManager.hasPassword()
            
            // Fix: Dismiss PIN sheet first to allow subsequent alerts/sheets to present correctly
            await MainActor.run {
                self.showPINInput = false
            }
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay for animation
            
            await MainActor.run {
                if hasPassword {
                    self.showPasswordForReset = true
                } else {
                    // Social User -> Start OTP Flow
                    // Note: sendPinResetOTP also has sheet dismissal logic, but it's safe to be redundant or we can clean it up inside sendPinResetOTP
                    Task { await self.sendPinResetOTP() }
                }
            }
        }
    }
    
    public func sendPinResetOTP() async {
        isLoading = true
        isSendingOTP = true
        otpErrorMessage = nil
        
        do {
            try await otpHandler.sendOTP(to: email, purpose: .resetPin)
            
            // Fix: Dismiss PIN sheet first to allow OTP sheet to present correctly
            await MainActor.run {
                self.showPINInput = false
            }
            // Small delay to allow dismissal animation
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            
            await MainActor.run {
                self.showOtpInput = true
            }
        } catch {
            alert = error.toAppAlert(defaultTitle: "Lỗi gửi mã OTP")
        }
        
        isLoading = false
        isSendingOTP = false
    }
    
    public func verifyPinResetOTP() async {
        isLoading = true
        otpErrorMessage = nil
        
        do {
            // 1. Verify OTP
            _ = try await otpHandler.verifyOTP(
                email: email,
                code: otpCode,
                purpose: .resetPin
            )
            
            Logger.info("✅ OTP verified for PIN reset", category: "Auth")
            
            // 2. Clear old PIN & Fail Counter
            await sessionManager.deletePIN(for: email)
            await sessionManager.resetPINFailCounter(for: email)
            
            // 3. Unlock Session (Refresh Token) 
            // This allows the user to enter the app without a PIN
            try await sessionManager.refreshSession()
            
            // 4. Close UI
            showOtpInput = false
            showPINInput = false
            otpCode = ""
            
        } catch let error as OTPInputHandler.OTPError {
            otpErrorMessage = error.localizedDescription
        } catch {
            if let appError = error as? AppError {
                otpErrorMessage = appError.localizedDescription
            } else {
                otpErrorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }

    public func verifyPasswordAndResetPIN() {
        guard !resetPasswordInput.isEmpty else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                // Verify password by logging in
                let request = LoginRequest(username: email, password: resetPasswordInput)
                let response = try await authRepository.login(req: request)
                Logger.info("✅ Password verified for PIN reset", category: "Auth")
                
                // Clear old PIN
                await sessionManager.deletePIN(for: email)
                await sessionManager.resetPINFailCounter(for: email)
                
                // Update session with new token (effectively logging in)
                await sessionManager.login(response: response)
                
                // Close sheets
                showPasswordForReset = false
                showPINInput = false
                resetPasswordInput = ""
                
            } catch {
                alert = error.toAppAlert(defaultTitle: "Lỗi xác thực")
            }
        }
    }

    // MARK: - Biometric Authentication

    public func checkBiometricAvailability() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else {
            canUseBiometric = false
            return
        }

        biometricType = context.biometryType
        canUseBiometric = true
    }

    private func ensureBiometricAvailableNow() -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            canUseBiometric = false
            alert = .general(
                title: "Thiết bị không hỗ trợ",
                message: "Thiết bị của bạn không hỗ trợ Face ID / Touch ID."
            )
            return false
        }
        biometricType = context.biometryType
        canUseBiometric = true
        return true
    }

    public func loginWithBiometric() async {
        // Re-check mỗi lần bấm để báo ngay khi không hỗ trợ
        guard ensureBiometricAvailableNow() else { return }

        // Hiển thị loading trong lúc Face ID/Touch ID + refresh token silent
        isLoading = true
        defer { isLoading = false }

        // Tăng số lần thử
        biometricAttempts += 1
        Logger.info(
            "🔐 Biometric attempt \(biometricAttempts)/\(maxBiometricAttempts)", category: "Auth")

        // Nếu đã thử quá 3 lần, chuyển sang nhập PIN
        if biometricAttempts > maxBiometricAttempts {
            Logger.info("⚠️ Max biometric attempts reached, switching to PIN", category: "Auth")
            biometricAttempts = 0  // Reset counter
            showPINInputScreen()
            return
        }

        let alertResult = await biometricHandler.authenticate(
            sessionManager: sessionManager,
            userDefaults: UserDefaultsManager(),
            options: BiometricAuthHandler.Copy.welcomeBack
        )

        if let alertResult {
            alert = alertResult
        } else {
            Logger.info("✅ Biometric login successful", category: "Auth")
            biometricAttempts = 0
        }
    }
}
