//
//  AppError.swift
//  FinFlowCore
//
//  Created by Nguyễn Văn Bảo on 26/12/25.
//

@_exported import Foundation

/// Application-wide error types
/// Frontend CHỈ HIỂN THỊ message từ backend, KHÔNG tự format
public enum AppError: Error, LocalizedError, Sendable {
    case networkError(String)
    case serverError(Int, String)  // Error code và message từ backend
    case decodingError
    case unauthorized(String)  // 401 - Token invalid/expired with server message
    case validationError(String) // Local validation error
    case unknown

    public var errorDescription: String? {
        switch self {
        case .networkError(let msg):
            return "Lỗi kết nối: \(msg)"
        case .serverError(_, let msg):
            return msg
        case .decodingError:
            return "Lỗi xử lý dữ liệu"
        case .unauthorized(let msg):
            return msg
        case .validationError(let msg):
            return msg
        case .unknown:
            return "Lỗi không xác định"
        }
    }

    /// HTTP status code cho error
    public var httpStatusCode: Int? {
        switch self {
        case .serverError(let code, _):
            switch code {
            case 1006, 1010, 1011: return 401
            case 1007: return 403
            case 1002: return 404
            default: return 400
            }
        case .unauthorized: return 401
        default: return nil
        }
    }
}
