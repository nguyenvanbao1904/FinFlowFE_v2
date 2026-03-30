import SwiftUI

struct AISmartInputField: View {
    @Binding var text: String
    @Binding var isAnalyzing: Bool
    let placeholder: String
    let onSubmit: (String) -> Void
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
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
                .focused(isFocused)
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
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.pill)
                .stroke(
                    isFocused.wrappedValue || isAnalyzing
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
                    lineWidth: isFocused.wrappedValue || isAnalyzing
                        ? BorderWidth.medium : BorderWidth.thin
                )
        )
        .shadow(
            color: isFocused.wrappedValue || isAnalyzing
                ? AppColors.accent.opacity(OpacityLevel.low) : .clear,
            radius: Spacing.xs, x: 0, y: Spacing.xs / 2
        )
    }
}
