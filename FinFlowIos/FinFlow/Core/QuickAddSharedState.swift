//
//  QuickAddSharedState.swift
//  FinFlowIos
//
//  Shared state giữa Widget và Main App qua App Groups UserDefaults.
//

import FinFlowCore
import Foundation

/// Shared state giữa Widget và Main App qua App Groups UserDefaults.
/// App Group ID phải được enable trong Xcode Signing & Capabilities cho cả 2 targets.
enum QuickAddSharedState {
    static let appGroupID = "group.nvb.FinFlowIos.widget"

    private static let pendingInputModeKey = "widget.pendingInputMode"
    private static let todayExpenseKey = "widget.todayExpense"
    private static let todayIncomeKey = "widget.todayIncome"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Widget → App

    static func setPendingInputMode(_ mode: WidgetInputMode) {
        sharedDefaults?.set(mode.rawValue, forKey: pendingInputModeKey)
        sharedDefaults?.synchronize()
    }

    /// Đọc và xóa chế độ nhập sau khi consume.
    static func consumePendingInputMode() -> WidgetInputMode? {
        guard let rawValue = sharedDefaults?.string(forKey: pendingInputModeKey),
              let mode = WidgetInputMode(rawValue: rawValue) else {
            return nil
        }
        sharedDefaults?.removeObject(forKey: pendingInputModeKey)
        sharedDefaults?.synchronize()
        return mode
    }

    // MARK: - App → Widget

    static func setTodaySummary(expense: Double, income: Double) {
        sharedDefaults?.set(expense, forKey: todayExpenseKey)
        sharedDefaults?.set(income, forKey: todayIncomeKey)
        sharedDefaults?.synchronize()
    }

    static func getTodayExpense() -> Double {
        sharedDefaults?.double(forKey: todayExpenseKey) ?? 0
    }

    static func getTodayIncome() -> Double {
        sharedDefaults?.double(forKey: todayIncomeKey) ?? 0
    }
}
