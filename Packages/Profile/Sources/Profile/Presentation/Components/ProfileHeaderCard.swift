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
                    .frame(width: 60, height: 60)
                
                Text(profile.initials)
                    .font(AppTypography.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(profile.fullName)
                    .font(AppTypography.headline)
                    .foregroundColor(.primary)
                
                Text(profile.email)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(AppColors.backgroundLight[1])
        .cornerRadius(12)
    }
}
