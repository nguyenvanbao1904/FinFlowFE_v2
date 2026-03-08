//
//  AISmartInputBar.swift
//  FinFlowCore
//
//  AI-powered smart input bar with voice and camera support
//

import SwiftUI

/// Smart input bar with AI sparkle icon, voice, and camera buttons
/// Reusable across Transaction, Budget, Goals, and Dashboard modules
public struct AISmartInputBar: View {
    // Text binding
    @Binding public var text: String
    @Binding public var isAnalyzing: Bool
    @FocusState private var isFocused: Bool

    // Configuration
    public var placeholder: String
    public var showVoiceButton: Bool
    public var showCameraButton: Bool

    // Callbacks
    public var onSubmit: (String) -> Void
    public var onVoice: () -> Void
    public var onCamera: () -> Void

    public init(
        text: Binding<String>,
        isAnalyzing: Binding<Bool>,
        placeholder: String = "Ví dụ: Đổ xăng 50 cành...",
        showVoiceButton: Bool = true,
        showCameraButton: Bool = true,
        onSubmit: @escaping (String) -> Void,
        onVoice: @escaping () -> Void = {},
        onCamera: @escaping () -> Void = {}
    ) {
        self._text = text
        self._isAnalyzing = isAnalyzing
        self.placeholder = placeholder
        self.showVoiceButton = showVoiceButton
        self.showCameraButton = showCameraButton
        self.onSubmit = onSubmit
        self.onVoice = onVoice
        self.onCamera = onCamera
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            // AI Text Input Field
            inputField

            // Voice Button
            if showVoiceButton {
                voiceButton
            }

            // Camera Button
            if showCameraButton {
                cameraButton
            }
        }
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(isAnalyzing ? AppColors.accent : AppColors.primary)
                .rotationEffect(.degrees(isAnalyzing ? 360 : 0))
                .animation(
                    isAnalyzing
                        ? Animation.linear(duration: 2).repeatForever(autoreverses: false)
                        : .default,
                    value: isAnalyzing
                )

            TextField(placeholder, text: $text)
                .font(AppTypography.body)
                .foregroundColor(.primary)
                .focused($isFocused)
                .onSubmit {
                    if !text.isEmpty {
                        onSubmit(text)
                    }
                }

            if !text.isEmpty && !isAnalyzing {
                Button {
                    onSubmit(text)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.pill)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.pill)
                .stroke(
                    isFocused || isAnalyzing
                        ? LinearGradient(
                            colors: [
                                AppColors.primary,
                                AppColors.accent.opacity(OpacityLevel.high)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                AppColors.disabled.opacity(OpacityLevel.medium),
                                AppColors.disabled.opacity(OpacityLevel.medium)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                    lineWidth: isFocused || isAnalyzing
                        ? BorderWidth.medium : BorderWidth.thin
                )
        )
        .shadow(
            color: isFocused || isAnalyzing
                ? AppColors.accent.opacity(OpacityLevel.low) : .clear,
            radius: Spacing.xs, x: 0, y: Spacing.xs / 2
        )
    }

    // MARK: - Voice Button

    private var voiceButton: some View {
        Button {
            onVoice()
        } label: {
            Image(systemName: "mic.fill")
                .font(AppTypography.iconMedium)
                .foregroundStyle(AppColors.textInverted)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(
                    isAnalyzing
                        ? LinearGradient(
                            colors: [AppColors.accent, AppColors.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [AppColors.primary, AppColors.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .clipShape(Circle())
                .shadow(
                    color: AppColors.primary.opacity(OpacityLevel.low),
                    radius: 5, x: 0, y: 2
                )
        }
    }

    // MARK: - Camera Button

    private var cameraButton: some View {
        Button {
            onCamera()
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(AppTypography.iconMedium)
                .foregroundColor(AppColors.primary)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(AppColors.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        AppColors.disabled.opacity(OpacityLevel.medium),
                        lineWidth: BorderWidth.thin
                    )
                )
        }
    }
}
