import SwiftUI

struct AISmartCircleActionButton: View {
    let systemImage: String
    let iconColor: Color
    let fill: AnyShapeStyle
    let borderColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTypography.iconMedium)
                .foregroundStyle(iconColor)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(fill)
                .clipShape(Circle())
                .overlay {
                    if let borderColor {
                        Circle()
                            .stroke(borderColor, lineWidth: BorderWidth.thin)
                    }
                }
        }
    }
}
