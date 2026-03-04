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

    /// 60pt bold rounded — hero amount display (AddTransaction)
    public static let displayXL = Font.system(size: 60, weight: .bold, design: .rounded)

    /// 42pt bold rounded — large title / big number
    public static let largeTitle = Font.system(size: 42, weight: .bold, design: .rounded)

    /// 34pt bold — prominent section header or balance display
    public static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)

    /// 32pt bold rounded — mid-size display (AddTransaction label, LockScreen icon)
    public static let displayMedium = Font.system(size: 32, weight: .bold, design: .rounded)

    /// 28pt bold rounded — standard title
    public static let title = Font.system(size: 28, weight: .bold, design: .rounded)

    /// 24pt bold — sub-section title, icon size text, Profile stat header
    public static let displaySmall = Font.system(size: 24, weight: .bold, design: .default)

    /// 22pt regular — supporting display text (CreatePIN welcome message)
    public static let displayCaption = Font.system(size: 22, weight: .regular, design: .default)

    /// 20pt regular — medium icon / list item icon
    public static let iconMedium = Font.system(size: 20, weight: .regular, design: .default)

    // MARK: - System Scaled (auto-scale with Accessibility settings)

    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let buttonTitle = Font.subheadline.weight(.medium)

    // MARK: - Specialty

    /// 70pt regular — large decorative emoji/icon (CreatePINWelcomeView)
    public static let icon = Font.system(size: 70, weight: .regular, design: .default)

    /// 24pt semibold rounded — PIN digit display
    public static let pinDigit = Font.system(size: 24, weight: .semibold, design: .rounded)

    /// 14pt semibold — profile stat label / small badge
    public static let profileStat = Font.system(size: 14, weight: .semibold, design: .default)

    /// 13pt bold — compact label with emphasis (OTP countdown, small badge)
    public static let labelSmall = Font.system(size: 13, weight: .bold, design: .default)
}
