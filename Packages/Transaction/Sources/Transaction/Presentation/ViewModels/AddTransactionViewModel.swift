import FinFlowCore
import Foundation

@MainActor
@Observable
public class AddTransactionViewModel {
    // UI State
    public var amount: String = ""
    public var isIncome: Bool = false
    public var selectedCategory: CategoryResponse?
    public var note: String = ""
    public var date: Date = Date()

    // Edit Mode
    public let transactionToEdit: TransactionResponse?
    public var isEditMode: Bool { transactionToEdit != nil }

    // System State
    public var categories: [CategoryResponse] = []
    public var isLoading: Bool = false
    public var alert: AppErrorAlert?

    // Dependencies
    private let addUseCase: AddTransactionUseCase
    private let updateUseCase: UpdateTransactionUseCase
    private let getCategoriesUseCase: GetCategoriesUseCase
    private let analyzeUseCase: any AnalyzeTextUseCaseProtocol
    private let router: any AppRouterProtocol
    private let sessionManager: any SessionManagerProtocol

    public init(
        addUseCase: AddTransactionUseCase,
        updateUseCase: UpdateTransactionUseCase,
        getCategoriesUseCase: GetCategoriesUseCase,
        analyzeUseCase: any AnalyzeTextUseCaseProtocol,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol,
        transactionToEdit: TransactionResponse? = nil
    ) {
        self.addUseCase = addUseCase
        self.updateUseCase = updateUseCase
        self.getCategoriesUseCase = getCategoriesUseCase
        self.analyzeUseCase = analyzeUseCase
        self.router = router
        self.sessionManager = sessionManager
        self.transactionToEdit = transactionToEdit

        // Pre-fill fields if editing
        if let transaction = transactionToEdit {
            self.amount = String(format: "%.0f", transaction.amount)
            self.isIncome = transaction.type == .income
            self.note = transaction.note ?? ""
            // Date will be parsed from transaction.transactionDate later in fetchCategories
        }
    }

    public func fetchCategories() async {
        do {
            self.categories = try await getCategoriesUseCase.execute()

            // Pre-select category and parse date if editing
            if let transaction = transactionToEdit {
                self.selectedCategory = categories.first { $0.id == transaction.category.id }

                // Parse transaction date
                if let parsedDate = parseTransactionDate(transaction.transactionDate) {
                    self.date = parsedDate
                }
            }
        } catch {
            handleError(error, defaultTitle: "Lỗi Tải Danh Mục")
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
        return !amount.isEmpty
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
            note: note.isEmpty ? nil : note,
            transactionDate: dateString
        )

        isLoading = true
        defer { isLoading = false }

        do {
            if let transaction = transactionToEdit {
                // Update existing transaction
                _ = try await updateUseCase.execute(id: transaction.id, request: request)
            } else {
                // Add new transaction
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

            // Update fields based on AI response
            self.amount = String(format: "%.0f", response.amount)
            self.isIncome = response.type == .income
            self.note = response.note ?? input

            if let suggestedCategoryId = response.suggestedCategoryId,
                let cat = categories.first(where: { $0.id == suggestedCategoryId }) {
                self.selectedCategory = cat
            } else {
                self.selectedCategory = filteredCategories.first
            }
        } catch {
            handleError(error, defaultTitle: "Lỗi Phân Tích")
        }
    }

    // MARK: - Error Handling (401 + generic)

    private func handleError(_ error: Error, defaultTitle: String) {
        if let appError = error as? AppError, case .unauthorized = appError {
            alert = .authWithAction(
                message: "Phiên đăng nhập đã hết hạn hoặc không còn hiệu lực. Vui lòng đăng nhập lại."
            ) { [sessionManager] in
                Task { @MainActor in
                    await sessionManager.clearExpiredSession()
                }
            }
            return
        }
        alert = error.toAppAlert(defaultTitle: defaultTitle)
    }

    // MARK: - Helper

    private func parseTransactionDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try with milliseconds
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: dateString)
    }
}
