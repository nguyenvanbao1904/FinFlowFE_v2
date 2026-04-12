import Foundation

// MARK: - Centralized Error Handling

/// Converts any thrown error into an `AppErrorAlert`, centralizing the repeated pattern of:
/// - Ignoring CancellationError (task cancelled by navigation)
/// - Mapping AppError.unauthorized to a session-expiry action alert
/// - Falling back to a generic alert for all other errors
///
/// Usage in ViewModels:
/// ```swift
/// catch {
///     alert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi")
/// }
/// ```
public extension Error {
    @MainActor
    func toHandledAlert(
        sessionManager: any SessionManagerProtocol,
        defaultTitle: String = ""
    ) -> AppErrorAlert? {
        if self is CancellationError {
            return nil
        }
        if let appError = self as? AppError, case .unauthorized = appError {
            return .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                Task { @MainActor in
                    await sessionManager.clearExpiredSession()
                }
            }
        }
        // Also catch 401 returned as httpStatusCode (e.g. serverError with status 401)
        if let appError = self as? AppError, appError.httpStatusCode == 401 {
            return .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                Task { @MainActor in
                    await sessionManager.clearExpiredSession()
                }
            }
        }
        return toAppAlert(defaultTitle: defaultTitle)
    }
}
