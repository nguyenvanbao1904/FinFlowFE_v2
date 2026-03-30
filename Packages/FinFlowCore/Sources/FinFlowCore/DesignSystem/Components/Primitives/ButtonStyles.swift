//
//  ButtonStyles.swift
//  FinFlowCore
//
//  Apple HIG compliant button styles
//

import SwiftUI

// MARK: - Primary Button Style

/// Primary action button style with loading state support
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let isLoading: Bool
    
    public init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .tint(AppColors.textInverted)
            } else {
                configuration.label
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            }
        }
        .font(AppTypography.headline)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            isEnabled
                ? AnyShapeStyle(AppColors.primary.gradient)
                : AnyShapeStyle(AppColors.buttonDisabled)
        )
        // Keep disabled button readable (avoid white-on-light-grey).
        .foregroundStyle(isEnabled ? AppColors.textInverted : AppColors.primary)
        .cornerRadius(CornerRadius.medium)
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: configuration.isPressed)
        .opacity(isLoading ? 0.7 : 1.0)
    }
}

// MARK: - Secondary Button Style

/// Secondary action button style
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.cardBackground)
            .foregroundStyle(AppColors.primary)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(AppColors.primary, lineWidth: BorderWidth.thin)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Text Button Style

/// Minimal text-only button style
public struct TextButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body)
            .foregroundStyle(AppColors.primary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply primary button style
    public func primaryButton(isLoading: Bool = false) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
    }
    
    /// Apply secondary button style
    public func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    /// Apply text button style
    public func textButton() -> some View {
        self.buttonStyle(TextButtonStyle())
    }
}
