import Foundation

enum TransactionDateParser {
    private static let fractionalSecondFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS"
    ]

    private static let posixFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    static func parseBackendLocalDateTime(_ value: String) -> Date? {
        let formatter = Self.posixFormatter
        for format in fractionalSecondFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value)
    }
}
