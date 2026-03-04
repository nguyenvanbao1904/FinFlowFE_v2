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
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(isLoading ? "Đang xử lý..." : title)
                    .font(.headline)
                if !isLoading, let icon = icon {
                    Image(systemName: icon)
                        .font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: style.colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .cornerRadius(CornerRadius.medium)
            .shadow(color: style.shadowColor, radius: 15, y: 8)
        }
        .disabled(style == .disabled || isLoading)
    }
}
