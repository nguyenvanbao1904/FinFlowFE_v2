//
//  BudgetListViewModel.swift
//  Planning
//
//  ViewModel for budget list screen (loads from API, delete with confirmation).
//

import FinFlowCore
import Foundation
import Observation

@MainActor
@Observable
public final class BudgetListViewModel {
    public var budgets: [BudgetWithSpending] = []
    public var isLoading = false
    public var error: AppError?
    public var loadError: AppErrorAlert?

    let router: any AppRouterProtocol
    private let getBudgetsUseCase: GetBudgetsUseCase
    private let deleteBudgetUseCase: DeleteBudgetUseCase
    let createBudgetUseCase: CreateBudgetUseCase
    let updateBudgetUseCase: UpdateBudgetUseCase
    let getCategoriesUseCase: any GetCategoriesUseCaseProtocol
    let sessionManager: any SessionManagerProtocol
    @ObservationIgnored
    private var hasRequestedInitialLoad = false

    public init(
        router: any AppRouterProtocol,
        getBudgetsUseCase: GetBudgetsUseCase,
        deleteBudgetUseCase: DeleteBudgetUseCase,
        createBudgetUseCase: CreateBudgetUseCase,
        updateBudgetUseCase: UpdateBudgetUseCase,
        getCategoriesUseCase: any GetCategoriesUseCaseProtocol,
        sessionManager: any SessionManagerProtocol
    ) {
        self.router = router
        self.getBudgetsUseCase = getBudgetsUseCase
        self.deleteBudgetUseCase = deleteBudgetUseCase
        self.createBudgetUseCase = createBudgetUseCase
        self.updateBudgetUseCase = updateBudgetUseCase
        self.getCategoriesUseCase = getCategoriesUseCase
        self.sessionManager = sessionManager
    }

    public func loadBudgets(force: Bool = false) async {
        // Avoid repeated auto-load loops when the view is recreated/appears rapidly.
        if !force {
            if hasRequestedInitialLoad {
                return
            }
            hasRequestedInitialLoad = true
        }

        // Prevent concurrent loads when user switches tabs quickly or triggers refresh repeatedly.
        if isLoading {
            return
        }

        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let list = try await getBudgetsUseCase.execute()
            budgets = list.map { BudgetWithSpending(budget: $0, spentAmount: $0.spentAmount ?? 0) }
        } catch {
            // Khi user chuyển tab / rời màn hình, Task có thể bị hủy.
            // Không hiển thị alert cho CancellationError.
            if error is CancellationError {
                return
            }
            if let appError = error as? AppError, case .unauthorized = appError {
                loadError = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                [sessionManager] in
                    Task { @MainActor in await sessionManager.clearExpiredSession() }
                }
            } else {
                loadError = error.toAppAlert()
            }
        }
    }

    public func deleteBudget(_ budget: BudgetResponse) async {
        do {
            try await deleteBudgetUseCase.execute(id: budget.id)
            budgets.removeAll { $0.budget.id == budget.id }
        } catch {
            loadError = error.toAppAlert()
        }
    }

    public func presentAddBudget() {
        router.presentSheet(.addBudget)
    }

    public func presentEditBudget(_ budget: BudgetResponse) {
        router.presentSheet(.editBudget(budget))
    }

    public var totalBudget: Double {
        budgets.reduce(0) { $0 + $1.budget.targetAmount }
    }

    public var totalSpent: Double {
        budgets.reduce(0) { $0 + $1.spentAmount }
    }

    public var overallProgress: Double {
        guard totalBudget > 0 else { return 0 }
        return totalSpent / totalBudget
    }

    public var hasExceededBudgets: Bool {
        budgets.contains { $0.isExceeded }
    }

    public var hasWarningBudgets: Bool {
        budgets.contains { $0.isNearLimit }
    }
}
