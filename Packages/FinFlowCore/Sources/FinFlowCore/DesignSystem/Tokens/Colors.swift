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
}
