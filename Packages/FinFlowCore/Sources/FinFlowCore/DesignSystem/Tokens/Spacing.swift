//
//  Spacing.swift
//  FinFlowCore
// swiftlint:disable:next explicit_top_level_acl
//
//  Spacing, Corner Radius, and Shadow tokens
//

import SwiftUI

// MARK: - Spacing

public enum Spacing {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 15
    public static let sm2: CGFloat = 16
    public static let md: CGFloat = 20
    public static let lg: CGFloat = 30
    public static let xl: CGFloat = 40
}

// MARK: - Corner Radius

public enum CornerRadius {
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 20
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
