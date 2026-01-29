import FinFlowCore
import Foundation

/// Quản lý cấu hình môi trường. Có thể mở rộng khi thêm staging/uat.
struct AppConfig {
    enum Environment {
        case development
        case production
    }

    static let shared = AppConfig()

    // MARK: - API Versioning
    /// API version to use for all requests.
    /// Change this to "2" when migrating to v2 API.
    /// Backend default: "1" if header not present
    let apiVersion: String = "1"

    private let environment: Environment = {
        #if DEBUG
            return .development
        #else
            return .production
        #endif
    }()

    var networkConfig: NetworkConfig {
        switch environment {
        case .development:
            return NetworkConfig(baseURL: "http://10.221.29.126:8080/api")
        case .production:
            return NetworkConfig(baseURL: "https://api.finflow.com/api")
        }
    }
}
