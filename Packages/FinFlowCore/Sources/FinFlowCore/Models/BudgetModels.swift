//
//  BudgetModels.swift
//  FinFlowCore
//
//  Budget domain models for budget tracking feature (aligned with backend API).
//

import Foundation

// MARK: - Budget Response DTO

/// Budget Response DTO from Backend (GET /api/budgets)
public struct BudgetResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let category: CategoryResponse
    public let targetAmount: Double
    /// Sum of expense transactions in this category within budget period (from API).
    public let spentAmount: Double?
    public let startDate: String   // yyyy-MM-dd
    public let endDate: String     // yyyy-MM-dd
    public let isRecurring: Bool
    public let recurringStartDate: String?  // yyyy-MM-dd, optional
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        category: CategoryResponse,
        targetAmount: Double,
        spentAmount: Double? = nil,
        startDate: String,
        endDate: String,
        isRecurring: Bool,
        recurringStartDate: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.category = category
        self.targetAmount = targetAmount
        self.spentAmount = spentAmount
        self.startDate = startDate
        self.endDate = endDate
        self.isRecurring = isRecurring
        self.recurringStartDate = recurringStartDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var categoryId: String { category.id }
    public var categoryName: String { category.name }
    public var categoryIcon: String { category.icon ?? "tag" }
    public var categoryColor: String { category.color }
}

// MARK: - Budget with Spending DTO

/// Budget with current spending amount (spent from transactions; backend may provide later).
public struct BudgetWithSpending: Identifiable, Hashable, Sendable {
    public let budget: BudgetResponse
    public let spentAmount: Double

    public var id: String { budget.id }

    public var progress: Double {
        guard budget.targetAmount > 0 else { return 0 }
        return spentAmount / budget.targetAmount
    }

    public var isNearLimit: Bool { progress >= 0.9 }
    public var isExceeded: Bool { progress >= 1.0 }

    public init(budget: BudgetResponse, spentAmount: Double) {
        self.budget = budget
        self.spentAmount = spentAmount
    }
}

// MARK: - Create / Update Request DTOs

public struct CreateBudgetRequest: Codable, Sendable {
    public let categoryId: String
    public let targetAmount: Double
    public let startDate: String   // yyyy-MM-dd
    public let endDate: String     // yyyy-MM-dd
    public let isRecurring: Bool?
    public let recurringStartDate: String?  // yyyy-MM-dd, optional

    public init(
        categoryId: String,
        targetAmount: Double,
        startDate: String,
        endDate: String,
        isRecurring: Bool? = nil,
        recurringStartDate: String? = nil
    ) {
        self.categoryId = categoryId
        self.targetAmount = targetAmount
        self.startDate = startDate
        self.endDate = endDate
        self.isRecurring = isRecurring
        self.recurringStartDate = recurringStartDate
    }
}

public struct UpdateBudgetRequest: Codable, Sendable {
    public let categoryId: String
    public let targetAmount: Double
    public let startDate: String
    public let endDate: String
    public let isRecurring: Bool?
    public let recurringStartDate: String?

    public init(
        categoryId: String,
        targetAmount: Double,
        startDate: String,
        endDate: String,
        isRecurring: Bool? = nil,
        recurringStartDate: String? = nil
    ) {
        self.categoryId = categoryId
        self.targetAmount = targetAmount
        self.startDate = startDate
        self.endDate = endDate
        self.isRecurring = isRecurring
        self.recurringStartDate = recurringStartDate
    }
}
