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
        NavigationStack {
            VStack {
                Text("Trang chủ")
                    .font(AppTypography.title)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Tổng quan")
        }
    }
}
