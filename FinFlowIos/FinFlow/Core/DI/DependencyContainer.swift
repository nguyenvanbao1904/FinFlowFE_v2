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
import Investment
import Planning
import Transaction
import Wealth

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
    let wealthAccountRepository: WealthAccountRepositoryProtocol
    let budgetRepository: BudgetRepositoryProtocol
    let investmentRepository: InvestmentRepositoryProtocol
    let portfolioRepository: PortfolioRepositoryProtocol
    let chatRepository: any ChatRepositoryProtocol
    let botChatGateway: BotChatGateway

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
        self.wealthAccountRepository = WealthAccountRepository(client: apiClient)
        self.budgetRepository = BudgetRepository(client: apiClient)
        self.investmentRepository = InvestmentRepository(client: apiClient)
        self.portfolioRepository = PortfolioRepository(client: apiClient)
        let chatRepository = ChatRepository(client: apiClient)
        self.chatRepository = chatRepository
        self.botChatGateway = BotChatGateway(chatRepository: chatRepository)

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

    // MARK: - Dashboard (cache ViewModel)

    /// Một `HomeViewModel` cho phiên dashboard. `AppRootView` render lại khi mở sheet / đổi router — nếu tạo VM mới mỗi lần sẽ mất `snapshot` (task load có thể bị cancel).
    var cachedHomeViewModel: HomeViewModel?

    /// Cùng lý do: mở sheet "Thêm giao dịch" đổi `presentedSheet` → body `AppRootView` rebuild → `makeMainTabView` gọi lại. Không cache thì `TransactionListViewModel` mới + `.task` fetch lại toàn bộ danh sách (spinner 5–10 phút nếu API chậm).
    var cachedTransactionListViewModel: TransactionListViewModel?

    func resetCachedHomeViewModel() {
        cachedHomeViewModel = nil
    }

    func resetCachedTransactionListViewModel() {
        cachedTransactionListViewModel = nil
    }

    // MARK: - Auth State

    func isUserAuthenticated() async -> Bool {
        return sessionManager.state.isAuthenticated
    }
}

