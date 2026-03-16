//
//  ProgressBar.swift
//  FinFlowCore
//
//  Reusable progress bar primitive for budget tracking
//

import SwiftUI

/// Linear progress bar showing current value vs total
/// Apple HIG: Use for determinate progress (known completion percentage)
public struct ProgressBar: View {
    public let current: Double
    public let total: Double
    public let color: Color
    public let height: CGFloat

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(current / total, 0), 1.0)
    }

    public init(
        current: Double,
        total: Double,
        color: Color = AppColors.primary,
        height: CGFloat = Spacing.xs
    ) {
        self.current = current
        self.total = total
        self.color = color
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.primary.opacity(0.1))

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: height)
    }
}
