//
//  Spacing.swift
//  FinFlowCore
// swiftlint:disable:next explicit_top_level_acl
//
//  Spacing, Corner Radius, and Shadow tokens
//

import SwiftUI

// MARK: - Spacing

/// Semantic spacing tokens - use these for padding, margins, gaps
/// TIP: Combine for larger sizes (e.g., Spacing.xl * 2)
public enum Spacing {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 15
    public static let sm2: CGFloat = 16
    public static let md: CGFloat = 20
    public static let lg: CGFloat = 30
    public static let xl: CGFloat = 40

    // Icon & touch targets (semantic aliases)
    public static let iconSmall: CGFloat = 24
    public static let iconMedium: CGFloat = 32
    public static let touchTarget: CGFloat = 44  // iOS minimum
}

// MARK: - Corner Radius

public enum CornerRadius {
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 20
    public static let pill: CGFloat = 100
}

// MARK: - Border Width

public enum BorderWidth {
    public static let hairline: CGFloat = 0.5
    public static let thin: CGFloat = 1
    public static let medium: CGFloat = 2
    public static let thick: CGFloat = 3
}

// MARK: - Opacity

/// Semantic opacity levels for consistent transparency across app
public enum OpacityLevel {
    public static let ultraLight: Double = 0.1  // Ultra subtle backgrounds
    public static let light: Double = 0.2  // Light overlays, dividers
    public static let low: Double = 0.3  // Subtle shadows, disabled icons
    public static let medium: Double = 0.4  // Borders, moderate disabled
    public static let strong: Double = 0.5  // Selected/active states
    public static let high: Double = 0.8  // Prominent highlights
}

// MARK: - Layout Constants

/// Common layout dimensions - use sparingly, prefer Spacing for flexibility
public enum Layout {
    public static let chartHeight: CGFloat = 250
    public static let inputRowHeight: CGFloat = 70
}

// MARK: - Shadow

public enum ShadowStyle {
    // swiftlint:disable:next large_tuple
    public static func primary(opacity: Double = 0.4) -> (
        color: Color, radius: CGFloat, x: CGFloat, y: CGFloat
    ) {
        (color: AppColors.primary.opacity(opacity), radius: 12, x: 0, y: 6)
    }

    // swiftlint:disable:next large_tuple
    public static func soft(opacity: Double = 0.3) -> (
        color: Color, radius: CGFloat, x: CGFloat, y: CGFloat
    ) {
        (color: AppColors.primary.opacity(opacity), radius: 10, x: 0, y: 0)
    }
}
