import FinFlowCore
import SwiftUI

public struct ProfileHeaderCard: View {
    let profile: UserProfile

    public init(profile: UserProfile) {
        self.profile = profile
    }

    public var body: some View {
        HStack(spacing: Spacing.lg) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: UILayout.avatarSize, height: UILayout.avatarSize)

                Text(profile.initials)
                    .font(AppTypography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(profile.fullName)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)

                Text(profile.email)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(AppColors.textInverted)
        .clipShape(.rect(cornerRadius: CornerRadius.small))
    }
}
