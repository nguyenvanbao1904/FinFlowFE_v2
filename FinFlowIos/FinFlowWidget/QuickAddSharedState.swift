//
//  QuickAddSharedState.swift
//  FinFlowWidget
//
//  Shared state giữa Widget và Main App qua App Groups UserDefaults.
//

import Foundation

/// Chế độ nhập giao dịch từ widget (widget-local copy).
/// Main app dùng `WidgetInputMode` từ FinFlowCore.
enum WidgetInputMode: String, Codable, Sendable {
    case voice
    case text
    case ocr
}

enum QuickAddSharedState: Sendable {
    static let appGroupID = "group.nvb.FinFlowIos.widget"

    private static let pendingInputModeKey = "widget.pendingInputMode"
    private static let todayExpenseKey = "widget.todayExpense"
    private static let todayIncomeKey = "widget.todayIncome"

    private nonisolated static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Widget → App

    nonisolated static func setPendingInputMode(_ mode: WidgetInputMode) {
        sharedDefaults?.set(mode.rawValue, forKey: pendingInputModeKey)
        sharedDefaults?.synchronize()
    }

    // MARK: - App → Widget

    nonisolated static func getTodayExpense() -> Double {
        sharedDefaults?.double(forKey: todayExpenseKey) ?? 0
    }

    nonisolated static func getTodayIncome() -> Double {
        sharedDefaults?.double(forKey: todayIncomeKey) ?? 0
    }
}
