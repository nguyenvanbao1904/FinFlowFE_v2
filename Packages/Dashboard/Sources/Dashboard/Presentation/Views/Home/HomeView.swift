//
//  HomeView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import FinFlowCore
import SwiftUI

public struct HomeView: View {
    private let router: any AppRouterProtocol
    
    public init(router: any AppRouterProtocol) {
        self.router = router
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Future: Dashboard content cards go here
                Spacer()
                Text("Trang chủ")
                    .font(AppTypography.title)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Tổng quan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentSheet(.profile)
                } label: {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(AppTypography.subheadline)
                                .foregroundStyle(AppColors.primary)
                        )
                }
                .accessibilityLabel("Hồ sơ cá nhân")
            }
        }
    }
}
