import Foundation

// MARK: - Account Type Option (from GET /api/accounts/types)

/// Account type option for UI pickers; includes transaction-eligibility and debt (balance stored negative).
public struct AccountTypeOptionResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let code: String
    public let displayName: String
    public let icon: String
    public let color: String
    public let transactionEligible: Bool
    /// True when balance is stored as negative (e.g. LOAN). Use for sign when creating/updating.
    public let debt: Bool

    public init(
        id: String,
        code: String,
        displayName: String,
        icon: String,
        color: String,
        transactionEligible: Bool,
        debt: Bool = false
    ) {
        self.id = id
        self.code = code
        self.displayName = displayName
        self.icon = icon
        self.color = color
        self.transactionEligible = transactionEligible
        self.debt = debt
    }
}

// MARK: - Wealth Account Response (from GET /api/wealth/accounts)

public struct WealthAccountResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let accountType: AccountTypeOptionResponse
    public let balance: Double
    public let isSynced: Bool
    public let includeInNetWorth: Bool

    public init(
        id: String,
        name: String,
        accountType: AccountTypeOptionResponse,
        balance: Double,
        isSynced: Bool = false,
        includeInNetWorth: Bool = true
    ) {
        self.id = id
        self.name = name
        self.accountType = accountType
        self.balance = balance
        self.isSynced = isSynced
        self.includeInNetWorth = includeInNetWorth
    }
}

// MARK: - Create / Update Wealth Account Request

public struct CreateWealthAccountRequest: Codable, Sendable {
    public let name: String
    public let accountTypeId: String
    public let balance: Double
    public let includeInNetWorth: Bool

    public init(name: String, accountTypeId: String, balance: Double, includeInNetWorth: Bool = true) {
        self.name = name
        self.accountTypeId = accountTypeId
        self.balance = balance
        self.includeInNetWorth = includeInNetWorth
    }
}

public struct UpdateWealthAccountRequest: Codable, Sendable {
    public let name: String
    public let accountTypeId: String
    public let balance: Double
    public let includeInNetWorth: Bool

    public init(name: String, accountTypeId: String, balance: Double, includeInNetWorth: Bool = true) {
        self.name = name
        self.accountTypeId = accountTypeId
        self.balance = balance
        self.includeInNetWorth = includeInNetWorth
    }
}
