//
//  PrimaryButton.swift
//  FinFlowCore
//
//  Primary action button
//

import SwiftUI

/// Primary action button with loading state support
public struct PrimaryButton: View {
    @Environment(\.isEnabled) private var isEnabled

    public let title: String
    public let isLoading: Bool
    public let action: () -> Void

    public init(title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button {
            // Block taps when disabled or loading
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(AppColors.backgroundLight[1])
                } else {
                    Text(title)
                        .font(AppTypography.headline)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm2)
            // Use AnyShapeStyle to unify gradient / color types
            .background(
                isEnabled
                    ? AnyShapeStyle(AppColors.primary.gradient)
                    : AnyShapeStyle(Color.gray.opacity(0.4))
            )
            .foregroundStyle(AppColors.backgroundLight[1])
            .cornerRadius(CornerRadius.medium)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
}
