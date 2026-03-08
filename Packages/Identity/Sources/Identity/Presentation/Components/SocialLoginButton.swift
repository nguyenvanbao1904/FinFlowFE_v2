//
//  SocialLoginButton.swift
//  Identity
//
//  MOVED FROM: FinFlowCore (Identity-specific component)
//  Social media login button
//

import FinFlowCore
import SwiftUI

/// Social media login button with brand colors
struct SocialLoginButton: View {
    enum Provider {
        case google
        case apple

        var color: Color {
            switch self {
            case .google: return AppColors.google
            case .apple: return AppColors.apple
            }
        }

        var logoAsset: String {
            switch self {
            case .google: return AppAssets.googleLogo
            case .apple: return AppAssets.appleLogo
            }
        }

        var iconFallback: String {
            switch self {
            case .google: return AppAssets.googleIconFallback
            case .apple: return AppAssets.appleIconFallback
            }
        }
    }

    let provider: Provider
    let action: () -> Void

    init(provider: Provider, action: @escaping () -> Void) {
        self.provider = provider
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(provider.logoAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: UILayout.socialIconSize, height: UILayout.socialIconSize)
            }
            .frame(width: UILayout.socialButtonWidth, height: UILayout.socialButtonHeight)
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(AppColors.glassBorder, lineWidth: 0.5)
            )
        }
    }
}
