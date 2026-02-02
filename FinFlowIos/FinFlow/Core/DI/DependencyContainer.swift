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
    let networkConfig: any NetworkConfigProtocol
    let tokenStore: any TokenStoreProtocol
    let httpClient: any HTTPClientProtocol
    let cacheService: any CacheServiceProtocol

    // 2. Services

    // 🆕 Global State Management
    public let sessionManager: SessionManager

    // 3. (Repositories)
    let authRepository: AuthRepositoryProtocol

    // 4. Use Cases - Created on demand (Transient) to avoid Container bloat

    private init() {
        let config = AppConfig.shared
        // ... (existing helper setup)
        
        let networkConfig = config.networkConfig
        self.networkConfig = networkConfig

        // Dùng AuthTokenStore mới (gộp cả Access & Refresh Token)
        let tokenStore = AuthTokenStore()
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

    }

    // MARK: - ViewModel Factories
    
    // Factories are now modularized in extensions:
    // - DependencyContainer+Identity.swift
    // - DependencyContainer+Dashboard.swift

    // MARK: - Auth State

    func isUserAuthenticated() async -> Bool {
        return sessionManager.state.isAuthenticated
    }
}
