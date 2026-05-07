//
//  WidgetUpdateHelper.swift
//  FinFlowIos
//
//  Helper để update widget data sau mỗi transaction.
//

import Foundation
import WidgetKit

enum WidgetUpdateHelper {
    /// Refresh widget timeline sau khi có transaction mới.
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Update today summary và reload widget.
    static func updateTodaySummary(expense: Double, income: Double) {
        QuickAddSharedState.setTodaySummary(expense: expense, income: income)
        reloadWidgets()
    }
}
