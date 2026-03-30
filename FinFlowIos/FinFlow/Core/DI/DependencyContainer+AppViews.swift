//
//  DependencyContainer+AppViews.swift
//  FinFlowIos
//
//  Created by FinFlow AI.
//

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
                onSuccess: { router.popToRoot() },
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

    // Factory cho Main Tab View
    func makeMainTabView<Destination: View>(
        router: any AppRouterProtocol,
        @ViewBuilder destinationFactory: @escaping (AppRoute) -> Destination
    ) -> some View {
        guard let appRouter = router as? AppRouter else {
            fatalError("Router must be AppRouter")
        }
        @Bindable var observableRouter = appRouter

        let homeViewModel = homeViewModelForDashboard()
        let homeView = HomeView(router: router, viewModel: homeViewModel)

        let transactionView = makeTransactionListView(router: router)

        let planningView = makePlanningView(router: router)
        let wealthView = makeWealthView(router: router)
        let investmentView = makeInvestmentView(router: router)

        return MainTabView(
            router: router,
            activeTab: $observableRouter.activeTab,
            homePath: $observableRouter.homePath,
            transactionPath: $observableRouter.transactionPath,
            planningPath: $observableRouter.planningPath,
            wealthPath: $observableRouter.wealthPath,
            investmentPath: $observableRouter.investmentPath,
            homeView: homeView,
            transactionView: transactionView,
            planningView: planningView,
            wealthView: wealthView,
            investmentView: investmentView,
            destinationFactory: destinationFactory
        )
    }

    @MainActor
    func makePlanningView(router: any AppRouterProtocol) -> some View {
        let getBudgetsUseCase = GetBudgetsUseCase(repository: budgetRepository)
        let deleteBudgetUseCase = DeleteBudgetUseCase(repository: budgetRepository)
        let createBudgetUseCase = CreateBudgetUseCase(repository: budgetRepository)
        let updateBudgetUseCase = UpdateBudgetUseCase(repository: budgetRepository)
        let getCategoriesUseCase = GetCategoriesUseCase(repository: transactionRepository)
        let budgetListViewModel = BudgetListViewModel(
            router: router,
            getBudgetsUseCase: getBudgetsUseCase,
            deleteBudgetUseCase: deleteBudgetUseCase,
            createBudgetUseCase: createBudgetUseCase,
            updateBudgetUseCase: updateBudgetUseCase,
            getCategoriesUseCase: getCategoriesUseCase,
            sessionManager: sessionManager
        )
        return PlanningView(router: router, budgetListViewModel: budgetListViewModel)
    }

    @MainActor
    func makeWealthView(router: any AppRouterProtocol) -> some View {
        let getWealthAccountsUseCase = GetWealthAccountsUseCase(repository: wealthAccountRepository)
        let getWealthAccountTypesUseCase = GetWealthAccountTypesUseCase(
            repository: wealthAccountRepository)
        let createWealthAccountUseCase = CreateWealthAccountUseCase(
            repository: wealthAccountRepository)
        let updateWealthAccountUseCase = UpdateWealthAccountUseCase(
            repository: wealthAccountRepository)
        let deleteWealthAccountUseCase = DeleteWealthAccountUseCase(
            repository: wealthAccountRepository)
        return WealthListView(
            router: router,
            getWealthAccountsUseCase: getWealthAccountsUseCase,
            getWealthAccountTypesUseCase: getWealthAccountTypesUseCase,
            createWealthAccountUseCase: createWealthAccountUseCase,
            updateWealthAccountUseCase: updateWealthAccountUseCase,
            deleteWealthAccountUseCase: deleteWealthAccountUseCase,
            sessionManager: sessionManager
        )
    }

    @MainActor
    func makeInvestmentView(router: any AppRouterProtocol) -> some View {
        let getStockAnalysisUseCase = GetStockAnalysisUseCase(repository: investmentRepository)
        let getCompanyIndustriesUseCase = GetCompanyIndustriesUseCase(repository: investmentRepository)
        let suggestCompaniesUseCase = SuggestCompaniesUseCase(repository: investmentRepository)
        let getPortfoliosUseCase = GetPortfoliosUseCase(repository: portfolioRepository)
        let getPortfolioAssetsUseCase = GetPortfolioAssetsUseCase(repository: portfolioRepository)
        let createPortfolioUseCase = CreatePortfolioUseCase(repository: portfolioRepository)
        let createTradeTransactionUseCase = CreateTradeTransactionUseCase(repository: portfolioRepository)
        let importPortfolioSnapshotUseCase = ImportPortfolioSnapshotUseCase(repository: portfolioRepository)
        let getPortfolioHealthUseCase = GetPortfolioHealthUseCase(repository: portfolioRepository)
        let getPortfolioVsMarketUseCase = GetPortfolioVsMarketUseCase(repository: portfolioRepository)
        let getPortfolioPerformanceUseCase = GetPortfolioPerformanceUseCase(repository: portfolioRepository)
        return InvestmentView(
            getStockAnalysisUseCase: getStockAnalysisUseCase,
            getCompanyIndustriesUseCase: getCompanyIndustriesUseCase,
            suggestCompaniesUseCase: suggestCompaniesUseCase,
            getPortfoliosUseCase: getPortfoliosUseCase,
            getPortfolioAssetsUseCase: getPortfolioAssetsUseCase,
            createPortfolioUseCase: createPortfolioUseCase,
            createTradeTransactionUseCase: createTradeTransactionUseCase,
            importPortfolioSnapshotUseCase: importPortfolioSnapshotUseCase,
            getPortfolioHealthUseCase: getPortfolioHealthUseCase,
            getPortfolioVsMarketUseCase: getPortfolioVsMarketUseCase,
            getPortfolioPerformanceUseCase: getPortfolioPerformanceUseCase,
            sessionManager: sessionManager
        )
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
            authRepository: authRepository,
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
                authRepository: authRepository,
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
                authRepository: authRepository,
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
                onCompletion: {
                    router.pop()
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

    @MainActor
    func makeTransactionListView(router: any AppRouterProtocol) -> some View {
        let getTransactionsUseCase = GetTransactionsUseCase(repository: transactionRepository)
        let getSummaryUseCase = GetTransactionSummaryUseCase(repository: transactionRepository)
        let getChartUseCase = GetTransactionChartUseCase(repository: transactionRepository)
        let deleteTransactionUseCase = DeleteTransactionUseCase(repository: transactionRepository)
        let viewModel = TransactionListViewModel(
            getTransactionsUseCase: getTransactionsUseCase,
            getSummaryUseCase: getSummaryUseCase,
            getChartUseCase: getChartUseCase,
            deleteTransactionUseCase: deleteTransactionUseCase,
            router: router,
            sessionManager: sessionManager
        )
        return TransactionListView(viewModel: viewModel)
    }

    @MainActor
    func makeCategoryListView(router: any AppRouterProtocol) -> some View {
        let viewModel = CategoryListViewModel(
            repository: transactionRepository,
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
            router: router,
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
