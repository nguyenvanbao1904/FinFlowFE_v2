import Foundation

enum TransactionDateParser {
    private static let fractionalSecondFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS"
    ]

    static func parseBackendLocalDateTime(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

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
