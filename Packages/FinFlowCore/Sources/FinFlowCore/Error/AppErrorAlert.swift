import SwiftUI

public enum AppErrorAlert: AppAlert, Equatable, Sendable, Identifiable {

    /// Thông báo thống nhất khi phiên đăng nhập hết hạn (401 / refresh fail). Dùng chung toàn app.
    public static let sessionExpiredMessage = "Phiên đăng nhập đã hết hạn hoặc không còn hiệu lực. Vui lòng đăng nhập lại."

    case network(onRetry: @Sendable () -> Void)
    case general(title: String, message: String)
    case auth(message: String)
    case authWithAction(message: String, onOK: @Sendable () -> Void)
    case data(message: String)
    case validation(message: String)
    case success(message: String, onOK: @Sendable () -> Void)

    public var title: String {
        switch self {
        case .network:
            return "Mất kết nối"
        case .general(let title, _):
            return title
        case .auth:
            return "Lỗi xác thực"
        case .authWithAction:
            return "Lỗi xác thực"
        case .data:
            return "Lỗi dữ liệu"
        case .validation:
            return "Thông báo"
        case .success:
            return "Thành công"
        }
    }

    public var id: String { title + (subtitle ?? "") }

    public var message: String {
        return subtitle ?? ""
    }

    public var subtitle: String? {
        switch self {
        case .network:
            return "Vui lòng kiểm tra kết nối Internet và thử lại."
        case .general(_, let message):
            return message
        case .auth(let message):
            return message
        case .authWithAction(let message, _):
            return message
        case .data(let message):
            return message
        case .validation(let message):
            return message
        case .success(let message, _):
            return message
        }
    }

    public enum AlertType {
        case error
        case success
        case warning
        case info
    }
    
    /// Type-safe alert type detection based on enum case
    public var alertType: AlertType {
        switch self {
        case .network, .data:
            return .error
        case .general:
            return .info
        case .auth, .authWithAction:
            return .error
        case .validation:
            return .warning
        case .success:
            return .success
        }
    }

    public var buttons: AnyView {
        switch self {
        case .network(let onRetry):
            return AnyView(
                Group {
                    Button("Thử lại", action: onRetry)
                    Button("Hủy", role: .cancel) {}
                }
            )
        case .authWithAction(_, let onOK):
            return AnyView(
                Button("OK", role: .cancel, action: onOK)
            )
        case .success(_, let onOK):
            return AnyView(
                Button("OK", role: .cancel, action: onOK)
            )
        default:
            return AnyView(
                Button("OK", role: .cancel) {}
            )
        }
    }

    // Equatable conformance
    public static func == (lhs: AppErrorAlert, rhs: AppErrorAlert) -> Bool {
        switch (lhs, rhs) {
        case (.network, .network): return true
        case (.auth(let m1), .auth(let m2)): return m1 == m2
        case (.authWithAction(let m1, _), .authWithAction(let m2, _)): return m1 == m2
        case (.data(let m1), .data(let m2)): return m1 == m2
        case (.validation(let m1), .validation(let m2)): return m1 == m2
        case (.general(let t1, let m1), .general(let t2, let m2)): return t1 == t2 && m1 == m2
        case (.success(let m1, _), .success(let m2, _)): return m1 == m2
        default: return false
        }
    }
}
