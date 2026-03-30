import Foundation

// MARK: - Transaction Domain Models

/// Enum representing the type of transaction
public enum TransactionType: String, Codable, Sendable, CaseIterable {
    case income = "INCOME"
    case expense = "EXPENSE"
}

/// Category Response DTO from Backend
public struct CategoryResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let type: TransactionType
    public let icon: String?
    public let color: String
    public let systemCategory: Bool

    public init(
        id: String,
        name: String,
        type: TransactionType,
        icon: String?,
        color: String,
        systemCategory: Bool
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.color = color
        self.systemCategory = systemCategory
    }
}

/// Transaction Response DTO from Backend
public struct TransactionResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let amount: Double
    public let type: TransactionType
    public let category: CategoryResponse
    public let note: String?
    public let accountId: String
    public let transactionDate: String  // ISO8601 string
    public let createdAt: String

    public init(
        id: String,
        amount: Double,
        type: TransactionType,
        category: CategoryResponse,
        note: String?,
        accountId: String,
        transactionDate: String,
        createdAt: String
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.note = note
        self.accountId = accountId
        self.transactionDate = transactionDate
        self.createdAt = createdAt
    }
}

/// Transaction Summary Response DTO from Backend
public struct TransactionSummaryResponse: Codable, Sendable {
    public let totalBalance: Double
    public let totalIncome: Double
    public let totalExpense: Double

    public init(totalBalance: Double, totalIncome: Double, totalExpense: Double) {
        self.totalBalance = totalBalance
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
    }
}

/// Generic Paginated Response wrapper
public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let content: [T]
    public let totalElements: Int
    public let totalPages: Int
    public let size: Int
    public let number: Int

    public init(content: [T], totalElements: Int, totalPages: Int, size: Int, number: Int) {
        self.content = content
        self.totalElements = totalElements
        self.totalPages = totalPages
        self.size = size
        self.number = number
    }
}

// MARK: - Transaction Request Models

public struct AddTransactionRequest: Codable, Sendable {
    public let amount: Double
    public let type: TransactionType
    public let categoryId: String
    public let accountId: String
    public let note: String?
    public let transactionDate: String  // ISO8601 target

    public init(
        amount: Double,
        type: TransactionType,
        categoryId: String,
        accountId: String,
        note: String?,
        transactionDate: String
    ) {
        self.amount = amount
        self.type = type
        self.categoryId = categoryId
        self.accountId = accountId
        self.note = note
        self.transactionDate = transactionDate
    }
}

public struct AnalyzeTransactionRequest: Codable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct AnalyzeTransactionResponse: Codable, Sendable {
    public let amount: Double?
    public let type: TransactionType
    public let suggestedCategoryId: String?
    public let note: String?
    public let transactionDate: String?

    public init(
        amount: Double?, type: TransactionType, suggestedCategoryId: String?, note: String?,
        transactionDate: String?
    ) {
        self.amount = amount
        self.type = type
        self.suggestedCategoryId = suggestedCategoryId
        self.note = note
        self.transactionDate = transactionDate
    }
}

extension Notification.Name {
    /// Đăng sau khi thêm/sửa giao dịch thành công, hoặc sau khi xóa (ảnh hưởng chi tiêu / ngân sách).
    public static let transactionDidSave = Notification.Name("transactionDidSave")
}

// MARK: - Category Request (user-created categories)

public struct CreateCategoryRequest: Codable, Sendable {
    public let name: String
    public let type: TransactionType
    public let icon: String?
    public let color: String?

    public init(name: String, type: TransactionType, icon: String? = nil, color: String? = nil) {
        self.name = name
        self.type = type
        self.icon = icon
        self.color = color
    }
}

public struct UpdateCategoryRequest: Codable, Sendable {
    public let name: String
    public let icon: String?
    public let color: String?

    public init(name: String, icon: String? = nil, color: String? = nil) {
        self.name = name
        self.icon = icon
        self.color = color
    }
}

// MARK: - Chart Models

public enum ChartRange: String, CaseIterable, Codable, Sendable {
    case week = "WEEK"
    case month = "MONTH"
    case quarter = "QUARTER"
    case year = "YEAR"

    /// Short label for segmented control (fits iPhone SE)
    public var shortName: String {
        switch self {
        case .week: return "T"
        case .month: return "Th"
        case .quarter: return "Q"
        case .year: return "N"
        }
    }
    /// Full label for display elsewhere
    public var fullName: String {
        switch self {
        case .week: return "Tuần"
        case .month: return "Tháng"
        case .quarter: return "Quý"
        case .year: return "Năm"
        }
    }
}

public struct TransactionChartResponse: Codable, Sendable {
    public let dataPoints: [ChartDataPoint]
    public let periodLabel: String
    public let hasNext: Bool

    public struct ChartDataPoint: Codable, Sendable, Identifiable {
        public var id: String { label }
        public let label: String
        public let income: Double
        public let expense: Double

        public init(label: String, income: Double, expense: Double) {
            self.label = label
            self.income = income
            self.expense = expense
        }
    }

    public init(dataPoints: [ChartDataPoint], periodLabel: String, hasNext: Bool) {
        self.dataPoints = dataPoints
        self.periodLabel = periodLabel
        self.hasNext = hasNext
    }
}
