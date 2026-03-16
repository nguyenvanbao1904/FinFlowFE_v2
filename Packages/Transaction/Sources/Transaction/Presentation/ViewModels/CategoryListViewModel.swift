import FinFlowCore
import Foundation

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

    public init(
        repository: any TransactionRepositoryProtocol,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol
    ) {
        self.repository = repository
        self.router = router
        self.sessionManager = sessionManager
    }

    public func loadCategories() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            categories = try await repository.getCategories()
        } catch {
            if let appError = error as? AppError, case .unauthorized = appError {
                loadError = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    Task { @MainActor in
                        await self.sessionManager.clearExpiredSession()
                    }
                }
            } else {
                loadError = error.toAppAlert()
            }
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
            await loadCategories()
            return true
        } catch {
            if let appError = error as? AppError, case .unauthorized = appError {
                alert = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    Task { @MainActor in
                        await self.sessionManager.clearExpiredSession()
                    }
                }
            } else {
                alert = error.toAppAlert()
            }
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
            await loadCategories()
            return true
        } catch {
            if let appError = error as? AppError, case .unauthorized = appError {
                alert = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    Task { @MainActor in
                        await self.sessionManager.clearExpiredSession()
                    }
                }
            } else {
                alert = error.toAppAlert()
            }
            return false
        }
    }

    public func deleteCategory(id: String) async {
        do {
            try await repository.deleteCategory(id: id)
            await loadCategories()
        } catch {
            if let appError = error as? AppError, case .unauthorized = appError {
                alert = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    Task { @MainActor in
                        await self.sessionManager.clearExpiredSession()
                    }
                }
            } else {
                alert = error.toAppAlert()
            }
        }
    }
}
