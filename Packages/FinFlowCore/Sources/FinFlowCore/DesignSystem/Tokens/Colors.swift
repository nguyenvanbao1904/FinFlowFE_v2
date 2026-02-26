//
//  Colors.swift
//  FinFlowCore
//
//  Centralized color palette for consistent theming
//

import SwiftUI

/// Centralized color palette for consistent theming
public enum AppColors {
    /// Primary brand color - Navy Blue (#3e7bff)
    /// Note: In Production, consider using Asset Catalog (Color Set) for automatic Dark/Light mode support.
    public static let primary = Color(red: 62 / 255, green: 123 / 255, blue: 255 / 255)

    /// Social media brand colors
    public static let google = Color.red
    public static let apple = Color(red: 24 / 255, green: 119 / 255, blue: 242 / 255)

    /// Background gradients
    public static let backgroundDark = [
        Color(red: 5 / 255, green: 7 / 255, blue: 10 / 255),
        Color(red: 10 / 255, green: 16 / 255, blue: 26 / 255),
    ]

    public static let backgroundLight = [
        Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255),
        Color.white,
    ]
}
