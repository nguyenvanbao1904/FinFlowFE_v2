import FinFlowCore
import Observation
import SwiftUI

@MainActor
@Observable
public final class AddBudgetViewModel {
    public var selectedCategory: CategoryResponse?
    public var targetAmount: String = ""
    public var startDate: Date = AddBudgetViewModel.computeDefaultStartDate()
    public var endDate: Date = AddBudgetViewModel.computeDefaultEndDate()
    public var isRecurring: Bool = true
    public var categories: [CategoryResponse] = []
    public var isLoading: Bool = false
    public var loadError: AppErrorAlert?

    public var expenseCategories: [CategoryResponse] {
        categories.filter { $0.type == .expense }
    }

    private let createBudgetUseCase: CreateBudgetUseCase
    private let updateBudgetUseCase: UpdateBudgetUseCase
    private let getCategoriesUseCase: any GetCategoriesUseCaseProtocol
    private let sessionManager: any SessionManagerProtocol
    private let budgetToEdit: BudgetResponse?
    private let onSuccess: () -> Void

    public var isEditing: Bool { budgetToEdit != nil }

    private static func computeDefaultStartDate() -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private static func computeDefaultEndDate() -> Date {
        let cal = Calendar.current
        let start = computeDefaultStartDate()
        return cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
    }

    private nonisolated(unsafe) static let periodSummaryFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeZone = TimeZone.current
        return f
    }()

    /// Summary e.g. "10 ngày" or "Từ 1 thg 3 đến 10 thg 3, 2026".
    public var budgetPeriodSummary: String {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let dayCount = max(0, days) + 1
        return "\(dayCount) ngày · \(Self.periodSummaryFormatter.string(from: startDate)) – \(Self.periodSummaryFormatter.string(from: endDate))"
    }

    public var isValid: Bool {
        selectedCategory != nil && !targetAmount.isEmpty
    }

    public init(
        createBudgetUseCase: CreateBudgetUseCase,
        updateBudgetUseCase: UpdateBudgetUseCase,
        getCategoriesUseCase: any GetCategoriesUseCaseProtocol,
        sessionManager: any SessionManagerProtocol,
        budgetToEdit: BudgetResponse? = nil,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.createBudgetUseCase = createBudgetUseCase
        self.updateBudgetUseCase = updateBudgetUseCase
        self.getCategoriesUseCase = getCategoriesUseCase
        self.sessionManager = sessionManager
        self.budgetToEdit = budgetToEdit
        self.onSuccess = onSuccess
        if let budget = budgetToEdit {
            loadBudgetData(budget)
        }
    }

    private func loadBudgetData(_ budget: BudgetResponse) {
        targetAmount = CurrencyFormatter.formatInput(
            String(Int(budget.targetAmount)), allowNegative: false)
        isRecurring = budget.isRecurring
        selectedCategory = budget.category
        if let start = budget.startDate.asDateFromYYYYMMDD() {
            startDate = start
        }
        if let end = budget.endDate.asDateFromYYYYMMDD() {
            endDate = end
        }
    }

    public func loadCategories() async {
        if !categories.isEmpty { return }
        if isLoading { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            categories = try await getCategoriesUseCase.execute()
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi tải danh mục")
        }
    }

    public func saveBudget() async {
        guard isValid,
            let category = selectedCategory
        else { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            if let existing = budgetToEdit {
                _ = try await updateBudgetUseCase.execute(
                    id: existing.id,
                    categoryId: category.id,
                    targetAmountString: targetAmount,
                    startDate: startDate,
                    endDate: endDate,
                    isRecurring: isRecurring
                )
            } else {
                _ = try await createBudgetUseCase.execute(
                    categoryId: category.id,
                    targetAmountString: targetAmount,
                    startDate: startDate,
                    endDate: endDate,
                    isRecurring: isRecurring
                )
            }
            NotificationCenter.default.post(name: .budgetDidSave, object: nil)
            onSuccess()
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi lưu ngân sách")
        }
    }
}

private let _yyyyMMddFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone.current
    return f
}()

extension String {
    fileprivate func asDateFromYYYYMMDD() -> Date? {
        _yyyyMMddFormatter.date(from: self)
    }
}
