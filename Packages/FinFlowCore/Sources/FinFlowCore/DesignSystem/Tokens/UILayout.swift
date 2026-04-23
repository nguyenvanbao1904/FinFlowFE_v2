//
//  UILayout.swift
//  FinFlowCore
//
//  UI Layout Constants - Fixed dimensions for icons, cells, and UI elements
//  Separate from Spacing tokens (which are for content padding/margins)
//

import Foundation

/// Fixed UI layout dimensions for consistent sizing across components
public enum UILayout {

    // MARK: - Icon Sizes

    /// Standard icon size in text fields and form controls
    public static let iconSize: CGFloat = 25

    /// Small icon size (checkmarks, indicators)
    public static let iconSmall: CGFloat = 16

    /// Icon size inside social login buttons
    public static let socialIconSize: CGFloat = 28

    // MARK: - Profile & Logo

    /// Large logo/profile image size (lock screen, profile avatars)
    public static let logoLarge: CGFloat = 80

    /// Large decorative circle (PIN welcome screen)
    public static let logoCircleLarge: CGFloat = 140

    /// Standard avatar size (profile cards, user initials)
    public static let avatarSize: CGFloat = 60

    /// Feature icon background circle
    public static let featureIconBackground: CGFloat = 50

    /// Biometric authentication button size
    public static let biometricButtonSize: CGFloat = 56

    // MARK: - PIN Input

    /// PIN cell dimensions (square-ish aspect)
    public static let pinCellWidth: CGFloat = 50
    public static let pinCellHeight: CGFloat = 60

    /// PIN cursor dimensions
    public static let pinCursorWidth: CGFloat = 2
    public static let pinCursorHeight: CGFloat = 24

    /// Hidden cursor hack (1x1 transparent)
    public static let hiddenCursorSize: CGFloat = 1

    // MARK: - Buttons

    /// Social login button dimensions
    public static let socialButtonWidth: CGFloat = 80
    public static let socialButtonHeight: CGFloat = 55

    /// Small toolbar/action button (chart zoom, reset)
    public static let toolbarButton: CGFloat = 28

    /// Profile / account chip in navigation bar (inner circle behind SF Symbol)
    public static let navBarProfileIconChip: CGFloat = 36

    // MARK: - Chart

    /// Legend dot — standard size
    public static let chartLegendDot: CGFloat = 12

    /// Legend dot — medium variant (used in chart/donut legends)
    public static let chartLegendDotMedium: CGFloat = 8

    /// Legend dot — compact/small variant
    public static let chartLegendDotSmall: CGFloat = 6

    // MARK: - Chart Sizes

    /// Compact chart height (dividend history, small inline charts)
    public static let chartHeightCompact: CGFloat = 160

    /// Donut/pie chart frame size (square)
    public static let donutChartSize: CGFloat = 130

    // MARK: - Picker Sizes

    /// Segmented picker width (year/quarter toggle)
    public static let segmentedPickerWidth: CGFloat = 140

    /// Wheel picker — narrow column (quarter picker)
    public static let wheelPickerNarrow: CGFloat = 52

    /// Wheel picker — wide column (year picker)
    public static let wheelPickerWide: CGFloat = 78

    /// Wheel picker row height
    public static let wheelPickerHeight: CGFloat = 92

    /// Maximum height for suggestion/autocomplete dropdown lists
    public static let suggestionListMaxHeight: CGFloat = 260

    /// Symbol/ticker column width in suggestion lists
    public static let symbolColumnWidth: CGFloat = 64

    // MARK: - Layout Clearance

    /// Bottom clearance for fixed action bars overlaying scroll content
    public static let fixedBottomBarClearance: CGFloat = 80
}
