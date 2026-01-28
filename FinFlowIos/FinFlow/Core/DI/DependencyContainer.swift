//
//  DependencyContainer.swift
//  FinFlowIos
//
//  Created by Nguyễn Văn Bảo on 26/12/25.
//

import Dashboard
import FinFlowCore
import Foundation
import Identity

@MainActor
public class DependencyContainer {
    public static let shared = DependencyContainer()

    // 1. Hạ tầng (Infrastructure)
    private let networkConfig: any NetworkConfigProtocol
    private let tokenStore: any TokenStoreProtocol
    private let httpClient: any HTTPClientProtocol
    private let cacheService: any CacheServiceProtocol

    // 2. Services

    // 🆕 Global State Management
    public let sessionManager: SessionManager

    // 3. (Repositories)
    private let authRepository: AuthRepositoryProtocol

    // 4. Use Cases
    private let loginUseCase: LoginUseCaseProtocol
    private let logoutUseCase: LogoutUseCaseProtocol
    private let getProfileUseCase: GetProfileUseCaseProtocol
    private let registerUseCase: RegisterUseCaseProtocol

    private init() {
        let config = AppConfig.shared
        // ... (existing helper setup)
        
        let networkConfig = config.networkConfig
        self.networkConfig = networkConfig

        // Dùng KeychainTokenStore thay vì InMemoryTokenStore cho production
        let tokenStore = KeychainTokenStore()
        self.tokenStore = tokenStore

        // Khởi tạo cache service
        let cacheService: any CacheServiceProtocol
        do {
            cacheService = try FileCacheService()
            Logger.info("CacheService initialized", category: "App")
        } catch {
            // Fallback nếu không tạo được cache service
            fatalError("Failed to initialize CacheService: \(error)")
        }
        self.cacheService = cacheService

        // Tạo APIClient
        let apiClient = APIClient(
            config: networkConfig,
            tokenStore: tokenStore,
            apiVersion: config.apiVersion
            // refreshHandler và onUnauthorized sẽ được config sau để tránh vòng phụ thuộc
        )
        self.httpClient = apiClient

        let concreteAuthRepository = AuthRepository(
            apiClient: apiClient,
            tokenStore: tokenStore,
            cacheService: cacheService
        )
        self.authRepository = concreteAuthRepository

        // 🔗 Config Auth Hooks (Break Circular Dependency)
        Task { [weak concreteAuthRepository, tokenStore] in
            await apiClient.configureAuthHooks(
                refreshHandler: { [weak concreteAuthRepository] in
                    guard let repository = concreteAuthRepository else {
                        throw AppError.networkError("AuthRepository deallocated")
                    }
                    let response = try await repository.refreshToken()
                    return response.token
                },
                onUnauthorized: { [tokenStore] in
                    await tokenStore.clearToken()
                }
            )
        }

        // Initialize SessionManager (Centralized State)
        self.sessionManager = SessionManager(
            tokenStore: tokenStore,
            authRepository: concreteAuthRepository
        )

        // Khởi tạo Use Cases với Repository
        self.loginUseCase = LoginUseCase(repository: concreteAuthRepository)
        self.logoutUseCase = LogoutUseCase(repository: concreteAuthRepository)
        self.getProfileUseCase = GetProfileUseCase(repository: concreteAuthRepository)
        self.registerUseCase = RegisterUseCase(repository: concreteAuthRepository)
    }

    // MARK: - ViewModel Factories

    func makeLoginViewModel(router: any AppRouterProtocol) -> LoginViewModel {
        return LoginViewModel(
            loginUseCase: loginUseCase,
            sessionManager: sessionManager,
            router: router
        )
    }

    func makeRegisterViewModel() -> RegisterViewModel {
        return RegisterViewModel(
            registerUseCase: registerUseCase,
            loginUseCase: loginUseCase,
            sessionManager: sessionManager
        )
    }

    func makeDashboardViewModel(router: any AppRouterProtocol) -> DashboardViewModel {
        return DashboardViewModel(
            getProfileUseCase: getProfileUseCase,
            authRepository: authRepository,
            logoutUseCase: logoutUseCase,
            sessionManager: sessionManager,
            router: router
        )
    }

    // MARK: - Use Case Factories (để Coordinators có thể tạo fresh instances)
    func makeLoginUseCase() -> LoginUseCaseProtocol {
        return loginUseCase
    }

    func makeLogoutUseCase() -> LogoutUseCaseProtocol {
        return logoutUseCase
    }

    // MARK: - Repository Factories

    func makeAuthRepository() -> AuthRepositoryProtocol {
        return authRepository
    }

    // MARK: - Auth State

    func isUserAuthenticated() async -> Bool {
        return sessionManager.state.isAuthenticated
    }
}
