//
//  Colors.swift
//  FinFlowCore
//
//  Centralized color palette for consistent theming
//

import SwiftUI

/// Centralized color palette for consistent theming
public enum AppColors {
    // MARK: - Brand

    /// Primary brand color - mapped to native accentColor to support Dark/Light out of the box
    public static let primary = Color.accentColor

    // MARK: - Semantic

    /// Success / Confirm actions — System Green
    public static let success = Color.green

    /// Error / Validation failure — System Red
    public static let error = Color.red

    /// Accent / Highlight color — System Blue (charts, secondary highlights)
    public static let accent = Color.blue

    /// Disabled state — Semantic system label color for disabled items
    public static let disabled = Color(UIColor.tertiaryLabel)

    /// Text on primary/dark backgrounds
    public static let textInverted = Color.white

    // MARK: - Social

    public static let google = Color.red
    /// Semantic alias — used for expense amounts and destructive actions
    public static let expense = google
    public static let destructive = google
    /// Adapted for dark mode instead of hardcoded hex
    public static let apple = Color.primary

    // MARK: - UI Component Tokens

    /// Overlay background for modals/loading (semi-transparent black)
    public static let overlayBackground = Color.black.opacity(0.4)

    /// Default input border color (unfocused state)
    public static let inputBorderDefault = Color(UIColor.separator)

    /// Glass effect border (subtle white overlay)
    public static let glassBorder = Color.white.opacity(0.1)

    /// Glass effect border for focused inputs
    public static let glassBorderFocused = Color.white.opacity(0.6)

    /// Error state border color
    public static let errorBorder = Color.red.opacity(0.3)

    /// Disabled button background
    public static let buttonDisabled = Color(UIColor.tertiarySystemFill)

    /// Light background overlay for settings/cards
    public static let settingsCardBackground = Color(UIColor.secondarySystemGroupedBackground)

    // MARK: - System Backgrounds

    /// Global app background (systemGroupedBackground default)
    public static let appBackground = Color(UIColor.systemGroupedBackground)

    /// Solid card background (secondarySystemGroupedBackground default)
    public static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)

    // MARK: - Chart Tokens

    /// Subtle grid line for chart axes.
    public static let chartGridLine = Color(UIColor.separator).opacity(0.28)

    /// Cột doanh thu / series doanh thu — RGB ổn định để đọc được trên dark mode (cyan hệ thống quá tối).
    public static let chartRevenue = Color(red: 0.35, green: 0.92, blue: 1.0)
    /// Cột LNST — xanh lá sáng, tách khỏi nền grouped dark.
    public static let chartProfit = Color(red: 0.28, green: 0.9, blue: 0.52)

    /// Thu nhập lãi thuần & series tương tự — thay indigo hệ thống (gần như biến mất trên nền đen).
    public static let chartIncomeInterest = Color(red: 0.52, green: 0.62, blue: 1.0)
    public static let chartIncomeFee = Color.teal
    public static let chartIncomeOther = Color.purple

    public static let chartAssetLoans = Color.indigo
    public static let chartAssetInvestmentSecurities = Color.purple
    public static let chartAssetInterbank = Color.cyan
    public static let chartAssetCash = Color.teal
    public static let chartAssetTrading = Color.pink
    public static let chartAssetFixed = Color.indigo
    public static let chartAssetReceivables = Color.orange
    public static let chartAssetShortTermInvestments = Color.blue
    public static let chartAssetInventory = Color.pink

    /// Hàng tồn kho (cơ cấu tài sản) — tách biệt rõ khỏi Tiền (teal) và Phải thu NH (pink).
    public static let chartInventory = Color.mint

    public static let chartCapitalDeposits = Color.blue
    public static let chartCapitalEquity = Color.purple
    public static let chartCapitalPapers = Color.orange
    public static let chartCapitalGovernmentDebt = Color.pink
    public static let chartCapitalShortTermLoan = Color.blue
    public static let chartCapitalLongTermLoan = Color.orange
    public static let chartCapitalCustomerAdvances = Color.teal

    public static let chartGrowthStrong = Color.green
    public static let chartGrowthStable = Color.orange
}
