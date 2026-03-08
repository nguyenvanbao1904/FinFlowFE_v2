//
//  HomeView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import FinFlowCore
import SwiftUI

public struct HomeView: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()
                
            VStack(spacing: .zero) {
                // Custom Navigation Bar
                HStack {
                    Spacer()
                    Text("Tổng quan")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding()
                
                Spacer()
                Text("Trang chủ")
                    .font(AppTypography.title)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}
