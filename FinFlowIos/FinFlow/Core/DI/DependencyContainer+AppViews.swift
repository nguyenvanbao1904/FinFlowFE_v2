//
//  DependencyContainer+AppViews.swift
//  FinFlowIos
//
//  Created by FinFlow AI.
//

import BotChat
import Dashboard
import FinFlowCore
import Identity
import Investment
import Planning
import Profile
import SwiftUI
import Transaction
import Wealth

// MARK: - App View Factories
extension DependencyContainer {

    @ViewBuilder
    func makeAuthenticationView(router: any AppRouterProtocol) -> some View {
        switch sessionManager.state {
        case .welcomeBack(let email, let firstName, let lastName):
            makeWelcomeBackView(
                router: router, email: email, firstName: firstName, lastName: lastName)
        case .sessionExpired(let email, let firstName, let lastName):
            let displayName = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            makeLoginView(
                router: router, prefillEmail: email,
                userDisplayName: displayName.isEmpty ? nil : displayName)
        default:
            makeLoginView(router: router)
        }
    }

    @MainActor
    func makeLoginView(
        router: any AppRouterProtocol,
        prefillEmail: String? = nil,
        userDisplayName: String? = nil
    ) -> some View {
        let viewModel = makeLoginViewModel(router: router)
        if let email = prefillEmail {
            viewModel.username = email
            viewModel.isSessionExpired = true
            viewModel.userDisplayName = userDisplayName ?? email.components(separatedBy: "@").first
        }
        return LoginView(viewModel: viewModel)
    }

    @MainActor
    func makeRegisterView(router: any AppRouterProtocol) -> some View {
        RegisterView(
            viewModel: makeRegisterViewModel(
                onSuccess: { username in 
                    router.popToRoot()
                    Task {
                        try? await Task.sleep(for: AnimationTiming.navigationDelay)
                        await MainActor.run {
                            router.presentSheet(.createPIN(email: username))
                        }
                    }
                },
                onNavigateToLogin: { router.popToRoot() }
            )
        )
    }

    @MainActor
    func makeForgotPasswordView(router: any AppRouterProtocol) -> some View {
        ForgotPasswordView(
            viewModel: makeForgotPasswordViewModel(
                onSuccess: { email in
                    Task {
                        await self.userDefaultsManager.saveEmailForPrefill(email)
                        await MainActor.run { router.popToRoot() }
                    }
                }
            )
        )
    }

    @MainActor
    func makeWelcomeBackView(
        router: any AppRouterProtocol,
        email: String,
        firstName: String?,
        lastName: String?
    ) -> some View {
        WelcomeBackView(
            viewModel: makeWelcomeBackViewModel(
                email: email,
                firstName: firstName,
                lastName: lastName,
                onSwitchAccount: {
                    Task {
                        await self.sessionManager.logoutCompletely()
                    }
                }
            )
        )
    }

    @MainActor
    func makeLockScreenView(user: UserProfile, biometricAvailable: Bool) -> some View {
        LockScreenView(
            viewModel: makeLockScreenViewModel(user: user, biometricAvailable: biometricAvailable))
    }

    /// Một `HomeViewModel` cho cả phiên dashboard (cache trên `DependencyContainer`).
    @MainActor
    func homeViewModelForDashboard() -> HomeViewModel {
        if let cached = cachedHomeViewModel {
            return cached
        }
        let homeDashboardService = HomeDashboardServiceImpl(
            getTransactionSummary: GetTransactionSummaryUseCase(repository: transactionRepository),
            getBudgets: GetBudgetsUseCase(repository: budgetRepository),
            getPortfolios: GetPortfoliosUseCase(repository: portfolioRepository),
            getPortfolioAssets: GetPortfolioAssetsUseCase(repository: portfolioRepository),
            getPortfolioHealth: GetPortfolioHealthUseCase(repository: portfolioRepository)
        )
        let vm = HomeViewModel(
            dashboardService: homeDashboardService,
            sessionManager: sessionManager
        )
        cachedHomeViewModel = vm
        return vm
    }

    /// Builds the main tab view. Accepts the concrete `AppRouter` so that `@Bindable`
    /// bindings for tab selection and navigation paths can be derived without a runtime cast.
    func makeMainTabView<Destination: View>(
        router: AppRouter,
        @ViewBuilder destinationFactory: @escaping (AppRoute) -> Destination
    ) -> some View {
        @Bindable var observableRouter = router

        return MainTabView(
            router: router,
            activeTab: $observableRouter.activeTab,
            homePath: $observableRouter.homePath,
            transactionPath: $observableRouter.transactionPath,
            planningPath: $observableRouter.planningPath,
            wealthPath: $observableRouter.wealthPath,
            investmentPath: $observableRouter.investmentPath,
            homeView: HomeView(router: router, viewModel: homeViewModelForDashboard()),
            transactionView: makeTransactionListView(router: router),
            planningView: makePlanningView(router: router),
            wealthView: makeWealthView(router: router),
            investmentView: makeInvestmentView(router: router),
            destinationFactory: destinationFactory
        )
    }

    @MainActor
    func makePlanningView(router: any AppRouterProtocol) -> some View {
        let budgetListViewModel = BudgetListViewModel(
            router: router,
            getBudgetsUseCase: GetBudgetsUseCase(repository: budgetRepository),
            deleteBudgetUseCase: DeleteBudgetUseCase(repository: budgetRepository),
            sessionManager: sessionManager
        )
        return PlanningView(budgetListViewModel: budgetListViewModel)
    }

    @MainActor
    func makeChatThreadListView() -> some View {
        let gateway = botChatGateway
        let vm = ChatThreadListViewModel(gateway: gateway)
        return ChatThreadListView(viewModel: vm) { [weak self] threadId, initialPrompt in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(self.makeFinFlowBotChatView(threadId: threadId, initialPrompt: initialPrompt))
        }
    }

    @MainActor
    func makeFinFlowBotChatView(threadId: String?, initialPrompt: String? = nil) -> some View {
        let gateway = botChatGateway
        return BotChatCreatorView(
            gateway: gateway,
            threadId: threadId,
            initialPrompt: initialPrompt
        )
    }

    @MainActor
    func wealthListViewModelForDashboard() -> WealthListViewModel {
        if let cached = cachedWealthListViewModel { return cached }
        let vm = WealthListViewModel(
            getWealthAccountsUseCase: GetWealthAccountsUseCase(repository: wealthAccountRepository),
            getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase(repository: wealthAccountRepository),
            createWealthAccountUseCase: CreateWealthAccountUseCase(repository: wealthAccountRepository),
            updateWealthAccountUseCase: UpdateWealthAccountUseCase(repository: wealthAccountRepository),
            deleteWealthAccountUseCase: DeleteWealthAccountUseCase(repository: wealthAccountRepository),
            sessionManager: sessionManager
        )
        cachedWealthListViewModel = vm
        return vm
    }

    @MainActor
    func makeWealthView(router: any AppRouterProtocol) -> some View {
        return WealthListView(viewModel: wealthListViewModelForDashboard())
    }

    @MainActor
    func makeInvestmentView(router: any AppRouterProtocol) -> some View {
        let wealthVM = wealthListViewModelForDashboard()
        var view = InvestmentView(
            dependencies: InvestmentViewDependencies(
                getStockAnalysisUseCase: GetStockAnalysisUseCase(repository: investmentRepository),
                getCompanyIndustriesUseCase: GetCompanyIndustriesUseCase(repository: investmentRepository),
                suggestCompaniesUseCase: SuggestCompaniesUseCase(repository: investmentRepository),
                getPortfoliosUseCase: GetPortfoliosUseCase(repository: portfolioRepository),
                getPortfolioAssetsUseCase: GetPortfolioAssetsUseCase(repository: portfolioRepository),
                createPortfolioUseCase: CreatePortfolioUseCase(repository: portfolioRepository),
                updatePortfolioUseCase: UpdatePortfolioUseCase(repository: portfolioRepository),
                deletePortfolioUseCase: DeletePortfolioUseCase(repository: portfolioRepository),
                createTradeTransactionUseCase: CreateTradeTransactionUseCase(repository: portfolioRepository),
                importPortfolioSnapshotUseCase: ImportPortfolioSnapshotUseCase(repository: portfolioRepository),
                getPortfolioHealthUseCase: GetPortfolioHealthUseCase(repository: portfolioRepository),
                getPortfolioVsMarketUseCase: GetPortfolioVsMarketUseCase(repository: portfolioRepository),
                getTradeTransactionsUseCase: GetTradeTransactionsUseCase(repository: portfolioRepository),
                sessionManager: sessionManager,
                netWorthProvider: { [weak wealthVM] in wealthVM?.netWorth ?? 0 },
                liquidAssetsProvider: { [weak wealthVM] in
                    wealthVM?.accounts
                        .filter { $0.accountType.group == "LIQUID" }
                        .reduce(0) { $0 + $1.balance } ?? 0
                }
            )
        )
        view.onAskAI = { [weak router] prompt in
            router?.presentSheet(.finFlowBotChat(threadId: nil, initialPrompt: prompt))
        }
        return view
    }

    @MainActor
    func makeProfileView(router: any AppRouterProtocol) -> ProfileView {
        let email = sessionManager.currentUser?.email ?? ""

        let profileVM = ProfileViewModel(
            getProfileUseCase: GetProfileUseCase(repository: authRepository),
            authRepository: authRepository,
            router: router,
            sessionManager: sessionManager
        )

        let securityVM = SecuritySettingsViewModel(
            userEmail: email,
            pinManager: pinManager,
            authRepository: authRepository,
            router: router,
            sessionManager: sessionManager,
            otpHandler: otpHandler
        )

        let accountVM = AccountManagementViewModel(
            userEmail: email,
            accountManagementUseCase: AccountManagementUseCase(repository: authRepository),
            otpHandler: otpHandler,
            router: router,
            sessionManager: sessionManager,
            pinManager: pinManager
        )

        return ProfileView(
            profileVM: profileVM,
            securityVM: securityVM,
            accountVM: accountVM
        )
    }

    @MainActor
    func makeUpdateProfileView(profile: UserProfile, router: any AppRouterProtocol) -> some View {
        UpdateProfileView(
            viewModel: UpdateProfileViewModel(
                updateProfileUseCase: UpdateProfileUseCase(repository: authRepository),
                sessionManager: sessionManager,
                currentProfile: profile,
                onSuccess: {
                    router.pop()
                }
            )
        )
    }

    @MainActor
    func makeChangePasswordView(hasPassword: Bool, router: any AppRouterProtocol) -> some View {
        ChangePasswordView(
            viewModel: ChangePasswordViewModel(
                changePasswordUseCase: ChangePasswordUseCase(repository: authRepository),
                sessionManager: sessionManager,
                isCreatingPassword: !hasPassword,
                onSuccess: {
                    router.pop()
                }
            )
        )
    }

    @MainActor
    func makeCreatePINView(email: String, router: any AppRouterProtocol) -> some View {
        CreatePINView(
            viewModel: CreatePINViewModel(
                email: email,
                pinManager: pinManager,
                sessionManager: sessionManager,
                onCompletion: {
                    if router.presentedSheet != nil {
                        router.dismissSheet()
                    } else {
                        router.pop()
                    }
                }
            )
        )
    }

    @MainActor
    func makeAddTransactionView(
        router: any AppRouterProtocol,
        transactionToEdit: TransactionResponse? = nil
    ) -> some View {
        let addUseCase = AddTransactionUseCase(repository: transactionRepository)
        let updateUseCase = UpdateTransactionUseCase(repository: transactionRepository)
        let getCategoriesUseCase = GetCategoriesUseCase(repository: transactionRepository)
        let analyzeUseCase = AnalyzeTextUseCase(repository: transactionRepository)
        let getWealthAccountsUseCase = GetWealthAccountsUseCase(repository: wealthAccountRepository)
        let viewModel = AddTransactionViewModel(
            addUseCase: addUseCase,
            updateUseCase: updateUseCase,
            getCategoriesUseCase: getCategoriesUseCase,
            getWealthAccountsUseCase: getWealthAccountsUseCase,
            analyzeUseCase: analyzeUseCase,
            router: router,
            sessionManager: sessionManager,
            transactionToEdit: transactionToEdit
        )
        return AddTransactionView(viewModel: viewModel)
    }

    /// Một `TransactionListViewModel` cho cả phiên dashboard (cache trên `DependencyContainer`).
    /// Tránh tạo VM mới mỗi lần `AppRootView` rebuild khi mở/đóng sheet — nếu không, `.task { fetchInitialDataIfNeeded }` chạy lại và xóa + tải lại cả danh sách.
    @MainActor
    func transactionListViewModelForDashboard(router: any AppRouterProtocol) -> TransactionListViewModel {
        if let cached = cachedTransactionListViewModel {
            return cached
        }
        let getTransactionsUseCase = GetTransactionsUseCase(repository: transactionRepository)
        let getSummaryUseCase = GetTransactionSummaryUseCase(repository: transactionRepository)
        let getChartUseCase = GetTransactionChartUseCase(repository: transactionRepository)
        let getAnalyticsInsightsUseCase = GetTransactionAnalyticsInsightsUseCase(
            repository: transactionRepository)
        let deleteTransactionUseCase = DeleteTransactionUseCase(repository: transactionRepository)
        let vm = TransactionListViewModel(
            getTransactionsUseCase: getTransactionsUseCase,
            getSummaryUseCase: getSummaryUseCase,
            getChartUseCase: getChartUseCase,
            getAnalyticsInsightsUseCase: getAnalyticsInsightsUseCase,
            deleteTransactionUseCase: deleteTransactionUseCase,
            router: router,
            sessionManager: sessionManager
        )
        cachedTransactionListViewModel = vm
        return vm
    }

    @MainActor
    func makeTransactionListView(router: any AppRouterProtocol) -> some View {
        TransactionListView(viewModel: transactionListViewModelForDashboard(router: router))
    }

    @MainActor
    func makeCategoryListView(router: any AppRouterProtocol) -> some View {
        let viewModel = CategoryListViewModel(
            getCategoriesUseCase: GetCategoriesUseCase(repository: transactionRepository),
            createCategoryUseCase: CreateCategoryUseCase(repository: transactionRepository),
            updateCategoryUseCase: UpdateCategoryUseCase(repository: transactionRepository),
            deleteCategoryUseCase: DeleteCategoryUseCase(repository: transactionRepository),
            router: router,
            sessionManager: sessionManager
        )
        return CategoryListView(viewModel: viewModel)
    }

    @MainActor
    func makeAddBudgetView(
        router: any AppRouterProtocol,
        budgetToEdit: BudgetResponse? = nil
    ) -> some View {
        let createBudgetUseCase = CreateBudgetUseCase(repository: budgetRepository)
        let updateBudgetUseCase = UpdateBudgetUseCase(repository: budgetRepository)
        let getCategoriesUseCase = GetCategoriesUseCase(repository: transactionRepository)
        let viewModel = AddBudgetViewModel(
            createBudgetUseCase: createBudgetUseCase,
            updateBudgetUseCase: updateBudgetUseCase,
            getCategoriesUseCase: getCategoriesUseCase,
            sessionManager: sessionManager,
            budgetToEdit: budgetToEdit,
            onSuccess: {
                router.dismissSheet()
            }
        )
        return AddBudgetView(viewModel: viewModel)
    }
}
