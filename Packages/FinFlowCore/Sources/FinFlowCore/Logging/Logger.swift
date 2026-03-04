import Foundation

/// Service logging tập trung cho toàn bộ ứng dụng
public enum Logger {
    public enum Level {
        case debug
        case info
        case warning
        case error
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    /// Log một message với level cụ thể
    public static func log(_ message: String, level: Level = .info, category: String = "App") {
        #if DEBUG
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        // swiftlint:disable:next no_print
        print("\(level.emoji) [\(timestamp)] [\(category)] \(message)")
        #endif
        
        // Analytics integration will go here
    }
    
    /// Log debug - chỉ hiển thị trong DEBUG mode
    public static func debug(_ message: String, category: String = "App") {
        log(message, level: .debug, category: category)
    }
    
    /// Log thông tin
    public static func info(_ message: String, category: String = "App") {
        log(message, level: .info, category: category)
    }
    
    /// Log cảnh báo
    public static func warning(_ message: String, category: String = "App") {
        log(message, level: .warning, category: category)
    }
    
    /// Log lỗi
    public static func error(_ message: String, category: String = "App") {
        log(message, level: .error, category: category)
    }
    
    /// Log API request
    public static func logRequest(_ method: String, url: String, headers: [String: String]? = nil, body: String? = nil) {
        var message = "➡️ \(method) \(url)"
        
        if let headers = headers {
            message += "\n   Headers: \(headers)"
        }
        
        if let body = body {
            message += "\n   Body: \(body)"
        }
        
        log(message, level: .debug, category: "API")
    }
    
    /// Log API response
    public static func logResponse(_ statusCode: Int, url: String, body: String? = nil) {
        var message = "⬅️ Status: \(statusCode) - \(url)"
        
        if let body = body {
            message += "\n   Response: \(body)"
        }
        
        log(message, level: .debug, category: "API")
    }
}

// MARK: - Helper Extensions
private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
