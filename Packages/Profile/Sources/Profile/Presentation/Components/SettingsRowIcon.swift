import FinFlowCore
import SwiftUI

struct SettingsRowIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: UILayout.socialIconSize, height: UILayout.socialIconSize)

            Image(systemName: icon)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.textInverted)
        }
    }
}
