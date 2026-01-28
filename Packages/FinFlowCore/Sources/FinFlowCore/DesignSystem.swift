//
//  DesignSystem.swift
//  FinFlowCore
//

import SwiftUI

// MARK: - Colors

/// Centralized color palette for consistent theming
public enum AppColors {
    /// Primary brand color - Navy Blue (#3e7bff)
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

// MARK: - Typography

/// Centralized typography styles
public enum AppTypography {
    public static let largeTitle = Font.system(size: 42, weight: .bold, design: .rounded)
    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let body = Font.system(size: 15)
    public static let caption = Font.caption
    public static let buttonTitle = Font.system(size: 14, weight: .medium)
}

// MARK: - Spacing

/// Consistent spacing values throughout the app
public enum Spacing {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 15
    public static let md: CGFloat = 20
    public static let lg: CGFloat = 30
    public static let xl: CGFloat = 40
}

// MARK: - Corner Radius

/// Consistent corner radius values
public enum CornerRadius {
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 20
}

// MARK: - Shadow

/// Consistent shadow styles
public enum ShadowStyle {
    public static func primary(opacity: Double = 0.4) -> (
        color: Color, radius: CGFloat, x: CGFloat, y: CGFloat
    ) {
        (color: AppColors.primary.opacity(opacity), radius: 12, x: 0, y: 6)
    }

    public static func soft(opacity: Double = 0.3) -> (
        color: Color, radius: CGFloat, x: CGFloat, y: CGFloat
    ) {
        (color: AppColors.primary.opacity(opacity), radius: 10, x: 0, y: 0)
    }
}

// MARK: - Assets

/// Centralized asset names to avoid typos
public enum AppAssets {
    // App branding
    public static let appLogo = "AppLogo"  // Add to Assets.xcassets

    // Social login logos
    public static let googleLogo = "GoogleLogo"  // Add to Assets.xcassets
    public static let appleLogo = "AppleLogo"  // Add to Assets.xcassets

    // SF Symbols fallbacks
    public static let personIcon = "person.fill"
    public static let lockIcon = "lock.fill"
    public static let chartIcon = "chart.pie.fill"
    public static let googleIconFallback = "g.circle.fill"
    public static let appleIconFallback = "f.circle.fill"
}

// MARK: - Reusable Components

/// Modern glassmorphism-styled text field with icon
public struct GlassyTextField: View {
    public let icon: String
    public let placeholder: String
    @Binding public var text: String
    public var isSecure: Bool
    public var keyboardType: UIKeyboardType

    public init(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 25)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.none)
                    .keyboardType(keyboardType)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.sm)
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

/// Primary action button with loading state support
public struct PrimaryButton: View {
    public let title: String
    public let isLoading: Bool
    public let action: () -> Void

    public init(
        title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(AppTypography.headline)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.primary.gradient)
            .foregroundColor(.white)
            .cornerRadius(CornerRadius.medium)
            .shadow(
                color: ShadowStyle.primary().color,
                radius: ShadowStyle.primary().radius,
                x: ShadowStyle.primary().x,
                y: ShadowStyle.primary().y
            )
        }
        .disabled(isLoading)
    }
}

/// Social media login button with brand colors
public struct SocialLoginButton: View {
    public enum Provider {
        case google
        case apple

        public var color: Color {
            switch self {
            case .google: return AppColors.google
            case .apple: return AppColors.apple
            }
        }

        public var logoAsset: String {
            switch self {
            case .google: return AppAssets.googleLogo
            case .apple: return AppAssets.appleLogo
            }
        }

        public var iconFallback: String {
            switch self {
            case .google: return AppAssets.googleIconFallback
            case .apple: return AppAssets.appleIconFallback
            }
        }
    }

    public let provider: Provider
    public let action: () -> Void

    public init(provider: Provider, action: @escaping () -> Void) {
        self.provider = provider
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if UIImage(named: provider.logoAsset) != nil {
                    Image(provider.logoAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: provider.iconFallback)
                        .font(.system(size: 30))
                        .foregroundColor(provider.color)
                }
            }
            .frame(width: 80, height: 55)
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}

/// Horizontal divider with centered text
public struct DividerWithText: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack {
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.secondary.opacity(0.2))

            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(.secondary)

            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.secondary.opacity(0.2))
        }
    }
}
