//
//  ProfileViewModel.swift
//  Dashboard
//

import FinFlowCore
import Identity

/// ViewModel cho Profile section
/// Responsibility: Quản lý hiển thị và cập nhật profile
@MainActor
@Observable
public class ProfileViewModel {
    // MARK: - State
    public var profile: UserProfile?
    public var alert: AppErrorAlert?
    public var isLoading = false
    public var isRefreshing = false
    public var shouldShowUpdateProfile = false
    public var hasLoadError = false
    public var hasAuthExpiredError = false
    
    // MARK: - Dependencies
    private let getProfileUseCase: GetProfileUseCaseProtocol
    private let authRepository: AuthRepositoryProtocol
    public let sessionManager: any SessionManagerProtocol
    
    // MARK: - Initialization
    public init(
        getProfileUseCase: GetProfileUseCaseProtocol,
        authRepository: AuthRepositoryProtocol,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getProfileUseCase = getProfileUseCase
        self.authRepository = authRepository
        self.sessionManager = sessionManager
    }
    
    // MARK: - Public Methods
    
    /// Load profile from API or cache
    public func loadProfile() async {
        // Nếu session không còn authenticated/sessionExpired thì không gọi API để tránh stuck
        if case .unauthenticated = sessionManager.state { return }
        if case .sessionExpired = sessionManager.state { return }
        
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
            Logger.error("Lỗi tải profile: \(error)", category: "ProfileVM")
            
            // Nếu token hết hạn/401, yêu cầu user đăng nhập lại
            if let appError = error as? AppError, case .unauthorized = appError {
                // Dừng trạng thái loading để UI chuyển sang màn hình chờ
                isLoading = false
                isRefreshing = false
                hasAuthExpiredError = true
                
                alert = .authWithAction(message: "Phiên đăng nhập đã hết hạn hoặc không còn hiệu lực. Vui lòng đăng nhập lại.") { [sessionManager] in
                    Task { @MainActor in
                        await sessionManager.clearExpiredSession()
                    }
                }
                return
            }
            
            if profile == nil {
                if let appError = error as? AppError {
                    self.alert = .data(message: appError.localizedDescription)
                } else {
                    self.alert = .general(
                        title: "Lỗi tải dữ liệu", message: error.localizedDescription)
                }
                hasLoadError = true
                hasAuthExpiredError = false
            } else {
                Logger.warning("Không thể refresh, hiển thị dữ liệu đã lưu", category: "ProfileVM")
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
        await loadProfile()
    }
    
    /// Make UpdateProfileViewModel
    public func makeUpdateProfileViewModel() -> UpdateProfileViewModel {
        return UpdateProfileViewModel(
            authRepository: self.authRepository,
            sessionManager: self.sessionManager,
            currentProfile: self.profile
        ) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                // Close sheet and force reload to refresh completeness flags
                self.shouldShowUpdateProfile = false
                self.isRefreshing = true
                await self.loadProfile()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if profile is complete, show update sheet if needed
    private func checkProfileForCompletion(_ profile: UserProfile) {
        if profile.firstName == nil || profile.lastName == nil || profile.dob == nil {
            shouldShowUpdateProfile = true
        } else {
            shouldShowUpdateProfile = false
        }
    }
}
