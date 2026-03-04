//
//  GradientButton.swift
//  FinFlowCore
//

import SwiftUI

/// Gradient Button với nhiều style khác nhau
public struct GradientButton: View {
    public enum Style {
        case primary
        case success
        case disabled

        var colors: [Color] {
            switch self {
            case .primary:
                return [AppColors.primary, AppColors.primary.opacity(0.7)]
            case .success:
                return [AppColors.success, AppColors.accent]
            case .disabled:
                return [AppColors.disabled, AppColors.disabled]
            }
        }

        var shadowColor: Color {
            switch self {
            case .primary:
                return AppColors.primary.opacity(0.5)
            case .success:
                return AppColors.success.opacity(0.5)
            case .disabled:
                return .clear
            }
        }
    }

    public let title: String
    public let icon: String?
    public let style: Style
    public let isLoading: Bool
    public let action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        style: Style = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.backgroundLight[1])
                }
                Text(isLoading ? "Đang xử lý..." : title)
                    .font(AppTypography.headline)
                if !isLoading, let icon = icon {
                    Image(systemName: icon)
                        .font(AppTypography.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm2)
            .background(
                LinearGradient(
                    colors: style.colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(AppColors.backgroundLight[1])
            .cornerRadius(CornerRadius.medium)
            .shadow(color: style.shadowColor, radius: 15, y: 8)
        }
        .disabled(style == .disabled || isLoading)
    }
}
