//
//  DesignSystem.swift
//  FinFlowCore
//

import SwiftUI
import UIKit

// MARK: - Colors

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

// MARK: - Typography

/// Centralized typography styles
/// Updated to support Dynamic Type (Accessibility)
public enum AppTypography {
    // Sử dụng relativeTo để font 42pt này vẫn có thể scale nếu người dùng chọn chữ cực lớn
    public static let largeTitle = Font.system(size: 42, weight: .bold, design: .rounded)

    // Các font dưới đây tự động scale theo hệ thống
    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let buttonTitle = Font.subheadline.weight(.medium)
}

// MARK: - Spacing

public enum Spacing {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 15
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

public enum AppAssets {
    public static let appLogo = "AppLogo"
    public static let googleLogo = "GoogleLogo"
    public static let appleLogo = "AppleLogo"

    // SF Symbols fallbacks
    public static let personIcon = "person.fill"
    public static let lockIcon = "lock.fill"
    public static let chartIcon = "chart.pie.fill"
    public static let googleIconFallback = "g.circle.fill"
    public static let appleIconFallback = "apple.logo"  // Sửa lại icon chuẩn SF Symbol cho Apple
}

// MARK: - Extensions

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable Components

/// Modern glassmorphism-styled text field with icon & Focus state
public struct GlassTextField: View {
    public let icon: String
    public let placeholder: String
    @Binding public var text: String
    public var keyboardType: UIKeyboardType

    // ✅ NEW: Track focus state để highlight viền
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        icon: String,
        keyboardType: UIKeyboardType = .default
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.keyboardType = keyboardType
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 25)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.none)
                .keyboardType(keyboardType)
                .focused($isFocused)  // Bind focus
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.sm)
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                // ✅ Highlight viền khi đang nhập liệu
                .stroke(
                    isFocused ? AppColors.primary.opacity(0.6) : Color.white.opacity(0.1),
                    lineWidth: isFocused ? 1 : 0.5
                )
        )
        // ✅ Animation mượt mà
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

/// Modern glassmorphism-styled secure field with icon
public struct GlassSecureField: View {
    public let icon: String
    public let placeholder: String
    @Binding public var text: String
    @State private var isSecured: Bool = true

    // ✅ NEW: Track focus
    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, placeholder: String, icon: String) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 25)

            Group {
                if isSecured {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isFocused)
                }
            }

            Button(action: { isSecured.toggle() }) {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                    .contentTransition(.symbolEffect(.replace))  // iOS 17 Animation
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.sm)
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isFocused ? AppColors.primary.opacity(0.6) : Color.white.opacity(0.1),
                    lineWidth: isFocused ? 1 : 0.5
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

/// Primary action button with loading state support
public struct PrimaryButton: View {
    public let title: String
    public let isLoading: Bool
    public let action: () -> Void

    public init(title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
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
            // Hiệu ứng mờ đi khi đang loading
            .opacity(isLoading ? 0.7 : 1.0)
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
            // ✅ Performance Fix: Không check UIImage(named:) trong body
            // Ưu tiên hiển thị Image Asset, nếu lỗi thì hiển thị System Icon
            // (Thực tế nên đảm bảo Assets có đủ ảnh)
            ZStack {
                Image(provider.logoAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                // Fallback layer (Optional - only visible if image fails to load/is transparent)
                // Trong thực tế, bạn nên đảm bảo file Assets.xcassets có ảnh
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
