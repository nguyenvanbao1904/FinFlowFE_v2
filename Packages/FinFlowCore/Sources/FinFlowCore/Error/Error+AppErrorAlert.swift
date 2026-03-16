import Foundation

public extension Error {
    /// Map any Error to AppErrorAlert with sensible defaults.
    /// - Parameter defaultTitle: fallback title for non-AppError cases.
    func toAppAlert(defaultTitle: String = "Lỗi") -> AppErrorAlert {
        if let appError = self as? AppError {
            switch appError {
            case .unauthorized:
                return .auth(message: AppErrorAlert.sessionExpiredMessage)
            case .validationError(let message):
                return .validation(message: message)
            case .networkError(let message):
                return .general(title: "Lỗi kết nối", message: message)
            case .serverError(_, let message):
                return .data(message: message)
            case .decodingError:
                return .data(message: "Lỗi xử lý dữ liệu")
            case .unknown:
                return .general(title: defaultTitle, message: "Lỗi không xác định")
            }
        }

        return .general(title: defaultTitle, message: localizedDescription)
    }
}
