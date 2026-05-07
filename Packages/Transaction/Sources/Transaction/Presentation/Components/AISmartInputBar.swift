//
//  AISmartInputBar.swift
//  Transaction
//
//  AI-powered smart input bar with voice and camera support.
//

import FinFlowCore
import SwiftUI

/// Smart input bar with AI sparkle icon, voice, and camera buttons.
struct AISmartInputBar: View {
    @Binding var text: String
    @Binding var isAnalyzing: Bool
    @FocusState private var isFocused: Bool

    var placeholder: String
    var showVoiceButton: Bool
    var showCameraButton: Bool
    var autoFocus: Binding<Bool>?

    var onSubmit: (String) -> Void
    var onVoice: () -> Void
    var onCamera: () -> Void

    init(
        text: Binding<String>,
        isAnalyzing: Binding<Bool>,
        placeholder: String = "Ví dụ: Đổ xăng 50 cành...",
        showVoiceButton: Bool = true,
        showCameraButton: Bool = true,
        autoFocus: Binding<Bool>? = nil,
        onSubmit: @escaping (String) -> Void,
        onVoice: @escaping () -> Void = {},
        onCamera: @escaping () -> Void = {}
    ) {
        self._text = text
        self._isAnalyzing = isAnalyzing
        self.placeholder = placeholder
        self.showVoiceButton = showVoiceButton
        self.showCameraButton = showCameraButton
        self.autoFocus = autoFocus
        self.onSubmit = onSubmit
        self.onVoice = onVoice
        self.onCamera = onCamera
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            inputField

            if showVoiceButton {
                circleButton(
                    systemImage: "mic.fill",
                    iconColor: AppColors.textInverted,
                    fill: AnyShapeStyle(
                        isAnalyzing
                            ? LinearGradient(
                                colors: [AppColors.accent, AppColors.primary],
                                startPoint: .leading, endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [AppColors.primary, AppColors.primary],
                                startPoint: .leading, endPoint: .trailing
                            )
                    ),
                    borderColor: nil,
                    action: onVoice
                )
                .shadow(color: AppColors.primary.opacity(OpacityLevel.low), radius: 5, x: 0, y: 2)
                .accessibilityLabel("Nhập bằng giọng nói")
            }

            if showCameraButton {
                circleButton(
                    systemImage: "camera.viewfinder",
                    iconColor: AppColors.primary,
                    fill: AnyShapeStyle(AppColors.cardBackground),
                    borderColor: AppColors.disabled.opacity(OpacityLevel.medium),
                    action: onCamera
                )
                .accessibilityLabel("Chụp ảnh hoá đơn")
            }
        }
        .onChange(of: autoFocus?.wrappedValue ?? false) { _, shouldFocus in
            if shouldFocus { isFocused = true }
        }
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(isAnalyzing ? AppColors.accent : AppColors.primary)
                .rotationEffect(.degrees(isAnalyzing ? 360 : 0))
                .animation(
                    isAnalyzing
                        ? Animation.linear(duration: 2).repeatForever(autoreverses: false)
                        : .default,
                    value: isAnalyzing
                )

            TextField(placeholder, text: $text)
                .font(AppTypography.body)
                .foregroundStyle(.primary)
                .focused($isFocused)
                .onSubmit {
                    if !text.isEmpty { onSubmit(text) }
                }

            if !text.isEmpty, !isAnalyzing {
                Button { onSubmit(text) } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityLabel("Gửi")
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.pill)
                .stroke(
                    isFocused || isAnalyzing
                        ? LinearGradient(
                            colors: [AppColors.primary, AppColors.accent.opacity(OpacityLevel.high)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                AppColors.disabled.opacity(OpacityLevel.medium),
                                AppColors.disabled.opacity(OpacityLevel.medium)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                    lineWidth: isFocused || isAnalyzing ? BorderWidth.medium : BorderWidth.thin
                )
        )
        .shadow(
            color: isFocused || isAnalyzing
                ? AppColors.accent.opacity(OpacityLevel.low) : .clear,
            radius: Spacing.xs, x: 0, y: Spacing.xs / 2
        )
    }

    // MARK: - Circle Action Button

    private func circleButton(
        systemImage: String,
        iconColor: Color,
        fill: AnyShapeStyle,
        borderColor: Color?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTypography.iconMedium)
                .foregroundStyle(iconColor)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(fill)
                .clipShape(Circle())
                .overlay {
                    if let borderColor {
                        Circle().stroke(borderColor, lineWidth: BorderWidth.thin)
                    }
                }
        }
    }
}
