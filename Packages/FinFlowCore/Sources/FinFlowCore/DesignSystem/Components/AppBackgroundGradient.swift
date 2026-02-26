//
//  AppBackgroundGradient.swift
//  FinFlowCore
//

import SwiftUI

/// Reusable background gradient component cho toàn app
/// Tự động adapt theo Dark/Light mode
public struct AppBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        LinearGradient(
            colors: colorScheme == .dark ? AppColors.backgroundDark : AppColors.backgroundLight,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
