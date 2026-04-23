import FinFlowCore
import Observation

@MainActor
@Observable
public final class CategoryListViewModel {
    public var categories: [CategoryResponse] = []
    public var isLoading = false
    public var loadError: AppErrorAlert?
    public var alert: AppErrorAlert?

    private let getCategoriesUseCase: GetCategoriesUseCase
    private let createCategoryUseCase: CreateCategoryUseCase
    private let updateCategoryUseCase: UpdateCategoryUseCase
    private let deleteCategoryUseCase: DeleteCategoryUseCase
    private let router: any AppRouterProtocol
    private let sessionManager: any SessionManagerProtocol
    @ObservationIgnored
    private var hasRequestedInitialLoad = false

    public init(
        getCategoriesUseCase: GetCategoriesUseCase,
        createCategoryUseCase: CreateCategoryUseCase,
        updateCategoryUseCase: UpdateCategoryUseCase,
        deleteCategoryUseCase: DeleteCategoryUseCase,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getCategoriesUseCase = getCategoriesUseCase
        self.createCategoryUseCase = createCategoryUseCase
        self.updateCategoryUseCase = updateCategoryUseCase
        self.deleteCategoryUseCase = deleteCategoryUseCase
        self.router = router
        self.sessionManager = sessionManager
    }

    public func loadCategories(force: Bool = false) async {
        if !force {
            if hasRequestedInitialLoad {
                return
            }
            hasRequestedInitialLoad = true
        }

        // Prevent concurrent loads (.task + .refreshable)
        if isLoading { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            categories = try await getCategoriesUseCase.execute()
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager)
        }
    }

    /// Returns true if create succeeded (caller can dismiss).
    public func createCategory(name: String, type: TransactionType, icon: String?, color: String?) async -> Bool {
        do {
            _ = try await createCategoryUseCase.execute(name: name, type: type, icon: icon, color: color)
            await loadCategories(force: true)
            return true
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
            return false
        }
    }

    /// Returns true if update succeeded (caller can dismiss).
    public func updateCategory(id: String, name: String, icon: String?, color: String?) async -> Bool {
        do {
            _ = try await updateCategoryUseCase.execute(id: id, name: name, icon: icon, color: color)
            await loadCategories(force: true)
            return true
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
            return false
        }
    }

    public func deleteCategory(id: String) async {
        do {
            try await deleteCategoryUseCase.execute(id: id)
            await loadCategories(force: true)
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
        }
    }
}
