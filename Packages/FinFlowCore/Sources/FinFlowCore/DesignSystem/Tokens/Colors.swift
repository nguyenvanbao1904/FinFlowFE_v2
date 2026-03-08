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

    /// Primary brand color - Navy Blue (#3E7BFF)
    /// Note: In Production, consider using Asset Catalog (Color Set) for automatic Dark/Light mode support.
    public static let primary = Color(red: 62 / 255, green: 123 / 255, blue: 255 / 255)

    // MARK: - Semantic

    /// Success / Confirm actions — Emerald Green
    public static let success = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)

    /// Accent / Highlight color — Sky Blue (charts, secondary highlights)
    public static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)

    /// Disabled state — Neutral Gray
    public static let disabled = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255).opacity(
        0.3)

    /// Text on primary/dark backgrounds
    public static let textInverted = Color.white

    // MARK: - Social

    public static let google = Color.red
    public static let apple = Color(red: 24 / 255, green: 119 / 255, blue: 242 / 255)

    // MARK: - UI Component Tokens

    /// Overlay background for modals/loading (semi-transparent black)
    public static let overlayBackground = Color.black.opacity(0.4)

    /// Default input border color (unfocused state)
    public static let inputBorderDefault = Color.gray.opacity(0.3)

    /// Glass effect border (subtle white overlay)
    public static let glassBorder = Color.white.opacity(0.1)

    /// Glass effect border for focused inputs
    public static let glassBorderFocused = Color.white.opacity(0.6)

    /// Error state border color
    public static let errorBorder = Color.red.opacity(0.3)

    /// Disabled button background
    public static let buttonDisabled = Color.gray.opacity(0.4)

    /// Light background overlay for settings/cards
    public static let settingsCardBackground = Color.gray.opacity(0.1)

    // MARK: - System Backgrounds

    /// Global app background (systemGroupedBackground default)
    public static let appBackground = Color(UIColor.systemGroupedBackground)

    /// Solid card background (secondarySystemGroupedBackground default)
    public static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
}
