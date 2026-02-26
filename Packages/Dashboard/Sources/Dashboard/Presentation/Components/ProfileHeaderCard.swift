import FinFlowCore
import SwiftUI

public struct ProfileHeaderCard: View {
    let profile: UserProfile

    public init(profile: UserProfile) {
        self.profile = profile
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Text(profile.initials)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.fullName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(profile.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
