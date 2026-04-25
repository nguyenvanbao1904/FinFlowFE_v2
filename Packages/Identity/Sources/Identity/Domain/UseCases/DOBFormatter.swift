import Foundation

/// Shared "yyyy-MM-dd" formatter for date-of-birth fields.
/// Reused by RegisterUseCase and UpdateProfileUseCase to avoid duplication.
enum DOBFormatter {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Format Date thành "yyyy-MM-dd" (yêu cầu của backend).
    static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
