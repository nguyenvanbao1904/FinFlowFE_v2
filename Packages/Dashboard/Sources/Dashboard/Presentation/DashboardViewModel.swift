//
//  DashboardViewModel.swift
//  Dashboard
//

import Combine
import FinFlowCore
import Identity

@MainActor
@Observable
public class DashboardViewModel {
    public var profile: UserProfile?
    public var alert: AppErrorAlert?
    public var isLoading = false
    public var isRefreshing = false
    public var shouldShowUpdateProfile = false

    private let getProfileUseCase: GetProfileUseCaseProtocol
    private let authRepository: AuthRepositoryProtocol
    private let logoutUseCase: LogoutUseCaseProtocol
    private let sessionManager: SessionManager
    private let router: any AppRouterProtocol

    public init(
        getProfileUseCase: GetProfileUseCaseProtocol,
        authRepository: AuthRepositoryProtocol,
        logoutUseCase: LogoutUseCaseProtocol,
        sessionManager: SessionManager,
        router: any AppRouterProtocol
    ) {
        self.getProfileUseCase = getProfileUseCase
        self.authRepository = authRepository
        self.logoutUseCase = logoutUseCase
        self.sessionManager = sessionManager
        self.router = router
    }

    public func makeUpdateProfileViewModel() -> UpdateProfileViewModel {
        return UpdateProfileViewModel(authRepository: self.authRepository, currentProfile: self.profile)
    }

    public func loadProfile() async {
        // Try SessionManager cache first
        if !isRefreshing, let cachedUser = sessionManager.currentUser {
            Logger.info("Using cached profile", category: "Dashboard")
            profile = cachedUser
            checkProfileForCompletion(cachedUser)
            return
        }

        Logger.info("Fetching profile from API...", category: "Dashboard")

        if !isRefreshing {
            isLoading = true
        }

        do {
            let fetchedProfile = try await getProfileUseCase.execute()
            profile = fetchedProfile
            sessionManager.updateCurrentUser(fetchedProfile)
            checkProfileForCompletion(fetchedProfile)
        } catch {
            Logger.error("Lỗi tải profile: \(error)", category: "Dashboard")

            if profile == nil {
                if let appError = error as? AppError {
                    self.alert = .data(message: appError.localizedDescription)
                } else {
                    self.alert = .general(title: "Lỗi tải dữ liệu", message: error.localizedDescription)
                }
            } else {
                Logger.warning("Không thể refresh, hiển thị dữ liệu đã lưu", category: "Dashboard")
            }
        }

        isLoading = false
        isRefreshing = false
    }

    public func refresh() async {
        isRefreshing = true
        await loadProfile()
    }

    private func checkProfileForCompletion(_ profile: UserProfile) {
        if profile.firstName == nil || profile.lastName == nil || profile.dob == nil {
            shouldShowUpdateProfile = true
        } else {
            shouldShowUpdateProfile = false
        }
    }

    public func logout() async {
        Logger.info("Người dùng đăng xuất", category: "Dashboard")
        do {
            try await logoutUseCase.execute()
            await sessionManager.logout()
            Logger.info("Logout completed", category: "Dashboard")
        } catch {
            Logger.error("Lỗi khi logout: \(error)", category: "Dashboard")
            await sessionManager.logout()
        }
    }

    public func navigateToProfile() {
        router.navigate(to: .profile)
    }

    public func navigateToSettings() {
        router.navigate(to: .settings)
    }
}
