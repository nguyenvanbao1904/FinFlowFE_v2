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
import Transaction

@MainActor
public class DependencyContainer {
    public static let shared = DependencyContainer()

    // 1. Hạ tầng (Infrastructure)
    let tokenStore: any TokenStoreProtocol
    let cacheService: any CacheServiceProtocol

    // 2. Services
    let keychainService: KeychainService
    let pinManager: any PINManagerProtocol
    let userDefaultsManager: any UserDefaultsManagerProtocol
    let otpHandler: OTPInputHandler

    // Global State Management
    public let sessionManager: any SessionManagerProtocol

    // 3. (Repositories)
    let authRepository: AuthRepositoryProtocol
    let transactionRepository: TransactionRepositoryProtocol

    // 4. Use Cases - Created on demand (Transient) to avoid Container bloat

    private init() {
        let config = AppConfig.shared

        let networkConfig = config.networkConfig

        // Initialize core services
        self.keychainService = KeychainService()
        self.pinManager = PINManager(keychain: keychainService)
        self.userDefaultsManager = UserDefaultsManager()
        self.tokenStore = AuthTokenStore(keychain: keychainService)

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

        let concreteAuthRepository = AuthRepository(
            client: apiClient,
            tokenStore: tokenStore,
            cacheService: cacheService
        )
        self.authRepository = concreteAuthRepository
        self.otpHandler = OTPInputHandler(repository: concreteAuthRepository)
        
        self.transactionRepository = TransactionRepository(client: apiClient)

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
            authRepository: concreteAuthRepository,
            userDefaultsManager: userDefaultsManager,
            pinManager: pinManager
        )

    }

    // MARK: - Auth State

    func isUserAuthenticated() async -> Bool {
        return sessionManager.state.isAuthenticated
    }
}
