import FinFlowCore
import Foundation

@MainActor
@Observable
public class AddTransactionViewModel {
    public var amount: String = ""
    public var isIncome: Bool = false
    public var selectedCategory: CategoryResponse?
    public var note: String = ""
    public var date: Date = Date()

    public let transactionToEdit: TransactionResponse?
    public var isEditMode: Bool { transactionToEdit != nil }

    public var categories: [CategoryResponse] = []
    public var accounts: [WealthAccountResponse] = []
    public var selectedAccount: WealthAccountResponse?
    public var isLoading: Bool = false
    public var alert: AppErrorAlert?

    private let addUseCase: AddTransactionUseCase
    private let updateUseCase: UpdateTransactionUseCase
    private let getCategoriesUseCase: GetCategoriesUseCase
    private let getWealthAccountsUseCase: GetWealthAccountsUseCase
    private let analyzeUseCase: any AnalyzeTextUseCaseProtocol
    private let router: any AppRouterProtocol
    private let sessionManager: any SessionManagerProtocol

    public init(
        addUseCase: AddTransactionUseCase,
        updateUseCase: UpdateTransactionUseCase,
        getCategoriesUseCase: GetCategoriesUseCase,
        getWealthAccountsUseCase: GetWealthAccountsUseCase,
        analyzeUseCase: any AnalyzeTextUseCaseProtocol,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol,
        transactionToEdit: TransactionResponse? = nil
    ) {
        self.addUseCase = addUseCase
        self.updateUseCase = updateUseCase
        self.getCategoriesUseCase = getCategoriesUseCase
        self.getWealthAccountsUseCase = getWealthAccountsUseCase
        self.analyzeUseCase = analyzeUseCase
        self.router = router
        self.sessionManager = sessionManager
        self.transactionToEdit = transactionToEdit

        if let transaction = transactionToEdit {
            self.amount = String(format: "%.0f", transaction.amount)
            self.isIncome = transaction.type == .income
            self.note = transaction.note ?? ""
        }
    }

    public var transactionEligibleAccounts: [WealthAccountResponse] {
        accounts.filter { $0.accountType.transactionEligible }
    }

    public func fetchCategories() async {
        if !categories.isEmpty && !accounts.isEmpty { return }

        // Avoid duplicate loads if the sheet is presented multiple times quickly
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        do {
            async let categoriesTask = getCategoriesUseCase.execute()
            async let accountsTask = getWealthAccountsUseCase.execute()

            let (fetchedCategories, allAccounts) = try await (categoriesTask, accountsTask)

            self.categories = fetchedCategories
            self.accounts = allAccounts

            if let transaction = transactionToEdit {
                self.selectedCategory = categories.first { $0.id == transaction.category.id }
                self.selectedAccount = accounts.first { $0.id == transaction.accountId }

                if let parsedDate = TransactionDateParser.parseBackendLocalDateTime(
                    transaction.transactionDate) {
                    self.date = parsedDate
                }
            } else if !transactionEligibleAccounts.isEmpty {
                self.selectedAccount = transactionEligibleAccounts.first
            }
        } catch {
            if error is CancellationError {
                return
            }
            handleError(error, defaultTitle: "Lỗi Tải Dữ Liệu")
        }
    }

    public func cancel() {
        router.dismissSheet()
    }

    public var filteredCategories: [CategoryResponse] {
        let typeMatcher: TransactionType = isIncome ? .income : .expense
        return categories.filter { $0.type == typeMatcher }
    }

    public var isSaveEnabled: Bool {
        !amount.isEmpty
            && Double(amount.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
                != nil
            && selectedCategory != nil
    }

    public func saveTransaction() async {
        guard let category = selectedCategory else {
            self.alert = AppError.validationError("Vui lòng chọn danh mục").toAppAlert(
                defaultTitle: "Lỗi Dữ Liệu")
            return
        }

        guard let account = selectedAccount else {
            self.alert = AppError.validationError("Vui lòng chọn tài khoản").toAppAlert(
                defaultTitle: "Lỗi Dữ Liệu")
            return
        }

        let rawAmount = amount.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let numericAmount = Double(rawAmount) else {
            self.alert = AppError.validationError("Số tiền không hợp lệ").toAppAlert(
                defaultTitle: "Lỗi Dữ Liệu")
            return
        }

        let type: TransactionType = isIncome ? .income : .expense

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: date)

        let request = AddTransactionRequest(
            amount: numericAmount,
            type: type,
            categoryId: category.id,
            accountId: account.id,
            note: note.isEmpty ? nil : note,
            transactionDate: dateString
        )

        isLoading = true
        defer { isLoading = false }

        do {
            if let transaction = transactionToEdit {
                _ = try await updateUseCase.execute(id: transaction.id, request: request)
            } else {
                _ = try await addUseCase.execute(request: request)
            }
            NotificationCenter.default.post(name: .transactionDidSave, object: nil)
            router.dismissSheet()
        } catch {
            handleError(error, defaultTitle: "Lỗi Lưu Giao Dịch")
        }
    }

    public func analyzeText(input: String) async {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            let response = try await analyzeUseCase.execute(text: input)

            if let amountValue = response.amount {
                self.amount = String(format: "%.0f", amountValue)
            }
            self.isIncome = response.type == .income
            self.note = response.note ?? input

            if let suggestedCategoryId = response.suggestedCategoryId,
                let cat = categories.first(where: { $0.id == suggestedCategoryId }) {
                self.selectedCategory = cat
            } else {
                self.selectedCategory = filteredCategories.first
            }

            if let suggestedAccountId = response.suggestedAccountId,
                let account = transactionEligibleAccounts.first(where: { $0.id == suggestedAccountId }) {
                self.selectedAccount = account
            }

            if let suggestedTransactionDate = response.transactionDate,
                let parsedDate = TransactionDateParser.parseBackendLocalDateTime(
                    suggestedTransactionDate
                ) {
                self.date = parsedDate
            }
        } catch {
            handleError(error, defaultTitle: "Lỗi Phân Tích")
        }
    }

    private func handleError(_ error: Error, defaultTitle: String) {
        if let appError = error as? AppError, case .unauthorized = appError {
            alert = .authWithAction(
                message: AppErrorAlert.sessionExpiredMessage
            ) { [sessionManager] in
                Task { @MainActor in
                    await sessionManager.clearExpiredSession()
                }
            }
            return
        }
        alert = error.toAppAlert(defaultTitle: defaultTitle)
    }

}
