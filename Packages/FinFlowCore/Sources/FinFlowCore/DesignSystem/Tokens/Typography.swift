//
//  Typography.swift
//  FinFlowCore
//
//  Centralized typography styles
//

import SwiftUI

/// Centralized typography styles
/// Updated to support Dynamic Type (Accessibility)
public enum AppTypography {

    // MARK: - Display (Large decorative text, e.g. amounts, hero numbers)

    /// Hero amount display (AddTransaction)
    /// Mapped to .largeTitle. Views should use .dynamicTypeSize or rely on .largeTitle for scaling.
    public static let displayXL = Font.system(.largeTitle, design: .rounded).weight(.bold)

    /// Large title / big number
    public static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)

    /// Prominent section header or balance display
    public static let displayLarge = Font.system(.largeTitle, design: .default).weight(.bold)

    /// Mid-size display (AddTransaction label, LockScreen icon)
    public static let displayMedium = Font.system(.title, design: .rounded).weight(.bold)

    /// Standard title
    public static let title = Font.system(.title, design: .rounded).weight(.bold)

    /// Sub-section title, icon size text, Profile stat header
    public static let displaySmall = Font.system(.title2, design: .default).weight(.bold)

    /// Supporting display text (CreatePIN welcome message)
    public static let displayCaption = Font.system(.title3, design: .default).weight(.regular)

    /// Medium icon / list item icon
    public static let iconMedium = Font.system(.title3, design: .default).weight(.regular)

    // MARK: - System Scaled (auto-scale with Accessibility settings)

    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let caption2 = Font.caption2
    public static let buttonTitle = Font.subheadline.weight(.medium)

    // MARK: - Specialty

    /// Large decorative emoji/icon (CreatePINWelcomeView)
    public static let icon = Font.system(.largeTitle, design: .default).weight(.regular)

    /// PIN digit display
    public static let pinDigit = Font.system(.title2, design: .rounded).weight(.semibold)

    /// Profile stat label / small badge
    public static let profileStat = Font.system(.subheadline, design: .default).weight(.semibold)

    /// Compact label with emphasis (OTP countdown, small badge)
    public static let labelSmall = Font.system(.footnote, design: .default).weight(.bold)
}
