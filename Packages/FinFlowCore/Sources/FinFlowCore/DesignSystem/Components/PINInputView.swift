//
//  PINInputView.swift
//  FinFlowCore
//
//  Reusable PIN input component with title and subtitle
//

import SwiftUI

public struct PINInputView: View {
    @Binding public var pin: String
    @FocusState.Binding public var isFocused: Bool

    public let title: String
    public let subtitle: String?
    public let showConfirmButton: Bool
    public let isLoading: Bool
    public let displayMode: PINCodeInput.DisplayMode
    public let onComplete: (String) -> Void
    public let onCancel: (() -> Void)?
    public let onForgotPIN: (() -> Void)?

    public init(
        pin: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        title: String = "Nhập mã PIN",
        subtitle: String? = nil,
        showConfirmButton: Bool = false,
        isLoading: Bool = false,
        displayMode: PINCodeInput.DisplayMode = .dots,
        onComplete: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil,
        onForgotPIN: (() -> Void)? = nil
    ) {
        self._pin = pin
        self._isFocused = isFocused
        self.title = title
        self.subtitle = subtitle
        self.showConfirmButton = showConfirmButton
        self.isLoading = isLoading
        self.displayMode = displayMode
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onForgotPIN = onForgotPIN
    }

    public var body: some View {
        VStack(spacing: Spacing.xl) {
            // Title & Subtitle
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(AppTypography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }
            }

            // PIN Input
            PINCodeInput(pin: $pin, isFocused: $isFocused, displayMode: displayMode)
                .onChange(of: pin) { _, newValue in
                    if newValue.count > 6 {
                        pin = String(newValue.prefix(6))
                    }
                    if pin.count == 6 && !isLoading {
                        onComplete(pin)
                    }
                }

            // Loading indicator (for slow network / refresh token)
            if isLoading {
                ProgressView()
                    .tint(AppColors.primary)
            }

            // Buttons
            HStack(spacing: Spacing.md) {
                if let onCancel = onCancel {
                    Button("Hủy", action: onCancel)
                        .buttonStyle(.bordered)
                }

                if showConfirmButton {
                    Button("Xác nhận") {
                        onComplete(pin)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pin.count != 6 || isLoading)
                }
            }
            
            // Forgot PIN Link
            if let onForgotPIN = onForgotPIN {
                Button(action: onForgotPIN) {
                    Text("Quên mã PIN?")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }
                .padding(.top, Spacing.sm)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}
