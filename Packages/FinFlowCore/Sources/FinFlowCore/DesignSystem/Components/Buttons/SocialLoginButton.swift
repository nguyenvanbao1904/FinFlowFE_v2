//
//  SocialLoginButton.swift
//  FinFlowCore
//
//  Social media login button
//

import SwiftUI

/// Social media login button with brand colors
public struct SocialLoginButton: View {
    public enum Provider {
        case google
        case apple

        public var color: Color {
            switch self {
            case .google: return AppColors.google
            case .apple: return AppColors.apple
            }
        }

        public var logoAsset: String {
            switch self {
            case .google: return AppAssets.googleLogo
            case .apple: return AppAssets.appleLogo
            }
        }

        public var iconFallback: String {
            switch self {
            case .google: return AppAssets.googleIconFallback
            case .apple: return AppAssets.appleIconFallback
            }
        }
    }

    public let provider: Provider
    public let action: () -> Void

    public init(provider: Provider, action: @escaping () -> Void) {
        self.provider = provider
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Image(provider.logoAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            }
            .frame(width: 80, height: 55)
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}
