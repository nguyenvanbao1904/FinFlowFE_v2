//
//  DashboardContainerViewModel.swift
//  Dashboard
//

import FinFlowCore
import Identity

/// Container ViewModel cho Dashboard
/// Responsibility: Quản lý và điều phối các child ViewModels (Profile, Security, Account)
@MainActor
@Observable
public class DashboardContainerViewModel {
    // MARK: - Child ViewModels
    public let profileVM: ProfileViewModel
    public let securityVM: SecuritySettingsViewModel
    public let accountVM: AccountManagementViewModel
    
    // MARK: - Dependencies  
    private let logoutUseCase: LogoutUseCaseProtocol
    private let router: any AppRouterProtocol
    public let sessionManager: any SessionManagerProtocol
    private let pinManager: any PINManagerProtocol
    
    // MARK: - Initialization
    public init(
        getProfileUseCase: GetProfileUseCaseProtocol,
        authRepository: AuthRepositoryProtocol,
        logoutUseCase: LogoutUseCaseProtocol,
        sessionManager: any SessionManagerProtocol,
        router: any AppRouterProtocol,
        pinManager: any PINManagerProtocol,
        otpHandler: OTPInputHandler
    ) {
        self.logoutUseCase = logoutUseCase
        self.router = router
        self.sessionManager = sessionManager
        self.pinManager = pinManager
        
        // Initialize child ViewModels
        self.profileVM = ProfileViewModel(
            getProfileUseCase: getProfileUseCase,
            authRepository: authRepository,
            sessionManager: sessionManager
        )
        
        // Get email from profile or session manager
        let email = sessionManager.currentUser?.email ?? ""
        
        self.securityVM = SecuritySettingsViewModel(
            userEmail: email,
            pinManager: pinManager,
            authRepository: authRepository,
            sessionManager: sessionManager,
            otpHandler: otpHandler
        )
        
        self.accountVM = AccountManagementViewModel(
            userEmail: email,
            authRepository: authRepository,
            otpHandler: otpHandler,
            router: router,
            sessionManager: sessionManager,
            pinManager: pinManager
        )
    }
    
    // MARK: - Public Methods
    
    /// Load initial data
    public func loadInitialData() async {
        await profileVM.loadProfile()
        
        // Update child VMs when profile loads
        if let profile = profileVM.profile {
            securityVM.updateUserEmail(profile.email)
            securityVM.isBiometricEnabled = profile.isBiometricEnabled ?? false
            accountVM.updateUserEmail(profile.email)
            
            // Check PIN requirement after profile is complete
            if profile.firstName != nil && profile.lastName != nil && profile.dob != nil {
                await securityVM.checkPINRequirement()
            }
        }
    }
    
    /// Logout (keep refresh token)
    public func logout() async {
        Logger.info("Người dùng đăng xuất (Soft Logout)", category: "Dashboard")
        // ✅ Fix: Soft Logout should NOT revoke token on server
        // We only clear access token locally.
        await sessionManager.logout()
        Logger.info("Soft Logout completed", category: "Dashboard")
    }
    
    /// Logout completely (clear refresh token)
    public func logoutCompletely() async {
        Logger.info("Người dùng đăng xuất hoàn toàn (switch account)", category: "Dashboard")
        do {
            try await logoutUseCase.execute()
            await sessionManager.logoutCompletely()
            Logger.info("Complete logout finished", category: "Dashboard")
        } catch {
            Logger.error("Lỗi khi complete logout: \(error)", category: "Dashboard")
            await sessionManager.logoutCompletely()
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Debug: Log tất cả dữ liệu storage (UserDefaults + Keychain)
    public func debugLogAllStorage() async {
#if DEBUG
        Logger.debug(String(repeating: "=", count: 60), category: "Debug")
        Logger.debug("🔍 DEBUG: LOGGING ALL STORAGE DATA", category: "Debug")
        Logger.debug(String(repeating: "=", count: 60), category: "Debug")
        
        await sessionManager.logAllStorageData()
        
        // Log PIN status
        if let email = profileVM.profile?.email {
            await pinManager.logPINStatus(for: email)
        }
        
        Logger.debug(String(repeating: "=", count: 60), category: "Debug")
        Logger.debug("✅ DEBUG LOG COMPLETE", category: "Debug")
        Logger.debug(String(repeating: "=", count: 60), category: "Debug")
#else
        Logger.debug("debugLogAllStorage is disabled in non-DEBUG builds", category: "Debug")
#endif
    }
}
