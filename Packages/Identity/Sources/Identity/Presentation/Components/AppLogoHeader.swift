//
//  AppLogoHeader.swift
//  Identity
//
//  MOVED FROM: FinFlowCore (Identity-specific component)
//  Reusable logo header with title and subtitle
//

import FinFlowCore
import SwiftUI

/// Reusable logo header với title và subtitle
/// Tự động fallback sang SF Symbol nếu không có custom logo
struct AppLogoHeader: View {
    let title: String?
    let subtitle: String?
    let logoSize: CGFloat

    init(
        title: String? = "FinFlow",
        subtitle: String? = "Quản lý tài chính thông minh",
        logoSize: CGFloat = 80
    ) {
        self.title = title
        self.subtitle = subtitle
        self.logoSize = logoSize
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // App Logo - Try custom asset first, fallback to SF Symbol
            Group {
                if UIImage(named: AppAssets.appLogo) != nil {
                    Image(AppAssets.appLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)
                } else {
                    // Fallback to SF Symbol
                    Image(systemName: AppAssets.chartIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)
                        .foregroundStyle(AppColors.primary.gradient)
                }
            }
            .shadow(
                color: ShadowStyle.soft().color,
                radius: ShadowStyle.soft().radius,
                x: ShadowStyle.soft().x,
                y: ShadowStyle.soft().y
            )

            if let title = title {
                Text(title)
                    .font(AppTypography.largeTitle)
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
