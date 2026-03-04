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
    public static let disabled = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255).opacity(0.3)

    // MARK: - Social

    public static let google = Color.red
    public static let apple = Color(red: 24 / 255, green: 119 / 255, blue: 242 / 255)

    // MARK: - Background Gradients

    public static let backgroundDark = [
        Color(red: 5 / 255, green: 7 / 255, blue: 10 / 255),
        Color(red: 10 / 255, green: 16 / 255, blue: 26 / 255)
    ]

    public static let backgroundLight = [
        Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255),
        Color.white
    ]
}
