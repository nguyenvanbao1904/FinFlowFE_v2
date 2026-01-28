import SwiftUI

public enum AppErrorAlert: AppAlert, Equatable, Sendable, Identifiable {
    case network(onRetry: @Sendable () -> Void)
    case general(title: String, message: String)
    case auth(message: String)
    case data(message: String)

    public var title: String {
        switch self {
        case .network:
            return "Mất kết nối"
        case .general(let title, _):
            return title
        case .auth:
            return "Lỗi xác thực"
        case .data:
            return "Lỗi dữ liệu"
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
        case .data(let message):
            return message
        }
    }

    public var buttons: AnyView {
        switch self {
        case .network(let onRetry):
            return AnyView(
                Group {
                    Button("Thử lại", action: onRetry)
                    Button("Hủy", role: .cancel) { }
                }
            )
        default:
            return AnyView(
                Button("OK", role: .cancel) { }
            )
        }
    }
    
    // Equatable conformance
    public static func == (lhs: AppErrorAlert, rhs: AppErrorAlert) -> Bool {
        switch (lhs, rhs) {
        case (.network, .network): return true
        case (.auth(let m1), .auth(let m2)): return m1 == m2
        case (.data(let m1), .data(let m2)): return m1 == m2
        case (.general(let t1, let m1), .general(let t2, let m2)): return t1 == t2 && m1 == m2
        default: return false
        }
    }
}
