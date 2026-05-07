//
//  WidgetInputMode.swift
//  FinFlowCore
//
//  Chế độ nhập giao dịch khi mở app từ widget.
//

import Foundation

/// Chế độ nhập tự động khi `AddTransactionView` được mở từ widget.
public enum WidgetInputMode: String, Codable, Sendable {
    case voice      // Tự động bắt đầu ghi âm
    case text       // Focus vào AI text field
    case ocr        // Tự động mở camera/photo picker
}
