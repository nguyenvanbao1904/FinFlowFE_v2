import FinFlowCore
import Foundation
import Observation

@MainActor
@Observable
public final class CategoryListViewModel {
    public var categories: [CategoryResponse] = []
    public var isLoading = false
    public var loadError: AppErrorAlert?
    public var alert: AppErrorAlert?

    private let repository: any TransactionRepositoryProtocol
    private let router: any AppRouterProtocol
    private let sessionManager: any SessionManagerProtocol
    @ObservationIgnored
    private var hasRequestedInitialLoad = false

    public init(
        repository: any TransactionRepositoryProtocol,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol
    ) {
        self.repository = repository
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
            categories = try await repository.getCategories()
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager)
        }
    }

    /// Returns true if create succeeded (caller can dismiss).
    public func createCategory(name: String, type: TransactionType, icon: String?, color: String?) async -> Bool {
        let request = CreateCategoryRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            icon: icon?.isEmpty == true ? nil : icon,
            color: color?.isEmpty == true ? nil : color
        )
        do {
            _ = try await repository.createCategory(request: request)
            await loadCategories(force: true)
            return true
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
            return false
        }
    }

    /// Returns true if update succeeded (caller can dismiss).
    public func updateCategory(id: String, name: String, icon: String?, color: String?) async -> Bool {
        let request = UpdateCategoryRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon?.isEmpty == true ? nil : icon,
            color: color?.isEmpty == true ? nil : color
        )
        do {
            _ = try await repository.updateCategory(id: id, request: request)
            await loadCategories(force: true)
            return true
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
            return false
        }
    }

    public func deleteCategory(id: String) async {
        do {
            try await repository.deleteCategory(id: id)
            await loadCategories(force: true)
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
        }
    }
}
