//
//  ProfileViewModel.swift
//  Dashboard
//

import FinFlowCore
import Observation

/// ViewModel cho Profile section
/// Responsibility: Quản lý hiển thị và cập nhật profile
@MainActor
@Observable
public final class ProfileViewModel {
    // MARK: - State
    public var profile: UserProfile?
    public var alert: AppErrorAlert?
    public var isLoading = false
    public var isRefreshing = false
    public var hasLoadError = false
    /// True khi session hết hạn (401) — dùng để hiển thị ProfileAuthExpiredStateView.
    public var hasAuthExpiredError = false
    
    // MARK: - Dependencies
    private let getProfileUseCase: GetProfileUseCaseProtocol
    private let authRepository: AuthRepositoryProtocol
    private let router: any AppRouterProtocol
    public let sessionManager: any SessionManagerProtocol
    @ObservationIgnored
    private var hasRequestedInitialLoad = false
    
    // MARK: - Initialization
    public init(
        getProfileUseCase: GetProfileUseCaseProtocol,
        authRepository: AuthRepositoryProtocol,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getProfileUseCase = getProfileUseCase
        self.authRepository = authRepository
        self.router = router
        self.sessionManager = sessionManager
        
        // Pre-populate profile to avoid 1-frame empty UI flash
        self.profile = sessionManager.currentUser
    }
    
    // MARK: - Public Methods
    
    /// Load profile from API or cache
    public func loadProfile(force: Bool = false) async {
        // Nếu session không còn authenticated/sessionExpired thì không gọi API để tránh stuck
        if case .unauthenticated = sessionManager.state { return }
        if case .sessionExpired = sessionManager.state { return }

        if !force, !isRefreshing {
            if hasRequestedInitialLoad {
                return
            }
            hasRequestedInitialLoad = true
        }
        
        // Try SessionManager cache first
        if !isRefreshing, let cachedUser = sessionManager.currentUser {
            Logger.info("Using cached profile", category: "ProfileVM")
            profile = cachedUser
            checkProfileForCompletion(cachedUser)
            return
        }
        
        Logger.info("Fetching profile from API...", category: "ProfileVM")
        
        if !isRefreshing {
            isLoading = true
        }
        
        do {
            let fetchedProfile = try await getProfileUseCase.execute()
            profile = fetchedProfile
            sessionManager.updateCurrentUser(fetchedProfile)
            checkProfileForCompletion(fetchedProfile)
            hasLoadError = false
            hasAuthExpiredError = false
        } catch {
            if error is CancellationError {
                // Ignore task cancellation gracefully without showing an alert
                Logger.info("Profile tải bị huỷ do chuyển trang", category: "ProfileVM")
                isLoading = false
                isRefreshing = false
                return
            }

            Logger.error("Lỗi tải profile: \(error)", category: "ProfileVM")

            let handled = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi tải dữ liệu")

            if profile == nil {
                // Chưa có data nào → hiển thị alert hoặc auth expired state
                alert = handled
                hasAuthExpiredError = handled?.isUnauthorized == true
                hasLoadError = handled?.isUnauthorized == false
            } else {
                // Đã có cached data → silent fail, không làm phiền user
                Logger.warning("Không thể refresh, hiển thị dữ liệu đã lưu", category: "ProfileVM")
                // Vẫn handle 401 dù đang có cache (session hết hạn cần logout)
                if handled?.isUnauthorized == true {
                    alert = handled
                    hasAuthExpiredError = true
                }
            }
        }
        
        isLoading = false
        isRefreshing = false
    }
    
    /// Refresh profile (force reload)
    public func refresh() async {
        // Tránh bấm Thử lại nhiều lần khi đang gọi API
        if isLoading || isRefreshing { return }
        isRefreshing = true
        isLoading = true
        hasLoadError = false
        hasAuthExpiredError = false
        await loadProfile(force: true)
    }
    
    /// Navigate to Update Profile
    public func navigateToUpdateProfile() {
        if let profile = profile {
            router.navigate(to: .updateProfile(profile))
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if profile is complete, navigate to update if needed
    private func checkProfileForCompletion(_ profile: UserProfile) {
        if profile.firstName == nil || profile.lastName == nil || profile.dob == nil {
            // Force Update Profile
            router.navigate(to: .updateProfile(profile))
        }
    }
}
