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
}
