//
//  AISmartInputBar.swift
//  FinFlowCore
//
//  AI-powered smart input bar with voice and camera support
//

import SwiftUI

/// Smart input bar with AI sparkle icon, voice, and camera buttons
/// Reusable across Transaction, Budget, and Dashboard modules
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
            AISmartInputField(
                text: $text,
                isAnalyzing: $isAnalyzing,
                placeholder: placeholder,
                onSubmit: onSubmit,
                isFocused: $isFocused
            )

            if showVoiceButton {
                voiceButton
            }

            if showCameraButton {
                cameraButton
            }
        }
    }

    private var voiceButton: some View {
        AISmartCircleActionButton(
            systemImage: "mic.fill",
            iconColor: AppColors.textInverted,
            fill: AnyShapeStyle(
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
            ),
            borderColor: nil,
            action: onVoice
        )
        .shadow(
            color: AppColors.primary.opacity(OpacityLevel.low),
            radius: 5, x: 0, y: 2
        )
    }

    private var cameraButton: some View {
        AISmartCircleActionButton(
            systemImage: "camera.viewfinder",
            iconColor: AppColors.primary,
            fill: AnyShapeStyle(AppColors.cardBackground),
            borderColor: AppColors.disabled.opacity(OpacityLevel.medium),
            action: onCamera
        )
    }
}
