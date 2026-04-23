import FinFlowCore
import Observation

@MainActor
@Observable
public final class LockScreenViewModel {
    // MARK: - Dependencies
    private let sessionManager: any SessionManagerProtocol
    private let pinManager: any PINManagerProtocol
    private let biometricHandler: FinFlowCore.BiometricAuthHandler
    
    // MARK: - State
    public var pin: String = ""
    public var errorMessage: String?
    public var isLoading: Bool = false
    public let user: UserProfile
    public let canUseBiometrics: Bool
    
    // MARK: - Init
    public init(
        sessionManager: any SessionManagerProtocol,
        pinManager: any PINManagerProtocol,
        user: UserProfile,
        biometricAvailable: Bool
    ) {
        self.sessionManager = sessionManager
        self.pinManager = pinManager
        self.user = user
        self.biometricHandler = FinFlowCore.BiometricAuthHandler()
        self.canUseBiometrics = biometricAvailable && biometricHandler.isBiometricAvailable()
        
        Logger.info("🔒 LockScreenViewModel initialized for \(user.username)", category: "LockScreen")
    }
    
    deinit {
        Logger.debug("♻️ Deinit: LockScreenViewModel", category: "Memory")
    }
    
    // MARK: - Actions
    
    public func handlePINEntry(_ newPin: String) async {
        self.pin = newPin
        
        // Auto submit if 4 or 6 digits (depending on config, usually 6)
        // Adjust length based on your PIN config. Assuming 6 for now or matching Login flow.
        if newPin.count == 6 {
            await verifyPIN()
        }
    }
    
    public func verifyPIN() async {
        guard !isLoading else { return }
        
        guard pin.count == 6 else {
            errorMessage = "Vui lòng nhập đủ 6 số"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let isCorrect = await pinManager.verifyPIN(pin, for: user.email)
        
        if isCorrect {
            Logger.info("✅ PIN verified on Lock Screen", category: "LockScreen")
            // ✅ Reset fail counter
            await sessionManager.resetPINFailCounter(for: user.email)
            // ✅ Unlock
            await sessionManager.unlockSession()
        } else {
            Logger.warning("❌ Incorrect PIN on Lock Screen", category: "LockScreen")
            errorMessage = "Mã PIN không đúng"
            pin = "" // Clear PIN
            
            // Increment fail counter handled inside PINManager if needed via handleFailedPIN, 
            // but here we just verified. We should probably use incrementPINFailCounter from SessionManager 
            // if we want to enforce locking/wiping, but simpler flow for now:
            let (allowed, attempts, max) = await sessionManager.incrementPINFailCounter(for: user.email)
            if !allowed {
                 // Too many attempts -> Wipe data or force logout?
                 // SessionManager logic handles this usually.
                 errorMessage = "Nhập sai quá \(max) lần. Vui lòng đăng nhập lại."
                 await sessionManager.logoutCompletely()
            } else {
                 errorMessage = "Mã PIN không đúng (Còn lại \(max - attempts) lần)"
            }
        }
        
        isLoading = false
    }
    
    public func requestBiometricUnlock() async {
        guard canUseBiometrics else { return }
        
        isLoading = true
        let success = await biometricHandler.verifyBiometric(reason: "Mở khóa ứng dụng")
        
        if success {
            Logger.info("✅ Biometric verified on Lock Screen", category: "LockScreen")
            await sessionManager.unlockSession()
        } else {
            Logger.warning("❌ Biometric failed", category: "LockScreen")
            // Don't show error message for checking, just fallback to PIN
        }
        isLoading = false
    }
    
    public func signOut() async {
        await sessionManager.logoutCompletely()
    }
}
