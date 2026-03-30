import SwiftUI

struct PINDigitBox: View {
    let digit: String?
    let isFilled: Bool
    let isFocused: Bool
    let displayMode: PINDisplayMode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isFocused ? AppColors.primary : AppColors.inputBorderDefault,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isFocused ? AppColors.primary.opacity(0.3) : .clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )

            if isFilled, let digit = digit {
                switch displayMode {
                case .dots:
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: UILayout.iconSmall, height: UILayout.iconSmall)
                        .transition(.scale.combined(with: .opacity))
                case .numbers:
                    Text(digit)
                        .font(AppTypography.pinDigit)
                        .foregroundStyle(AppColors.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if isFocused && !isFilled {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: UILayout.pinCursorWidth, height: UILayout.pinCursorHeight)
                    .opacity(isFocused ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isFocused
                    )
            }
        }
        .frame(width: UILayout.pinCellWidth, height: UILayout.pinCellHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFilled)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}
