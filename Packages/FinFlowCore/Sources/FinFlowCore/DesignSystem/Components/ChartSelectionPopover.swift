import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

public struct ChartPopoverMetric: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let value: String
    public let color: Color

    public init(id: String, label: String, value: String, color: Color) {
        self.id = id
        self.label = label
        self.value = value
        self.color = color
    }
}

public struct ChartSelectionPopover: View {
    let title: String
    let subtitle: String?
    let metrics: [ChartPopoverMetric]

    public init(title: String, subtitle: String? = nil, metrics: [ChartPopoverMetric]) {
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(AppTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.apple)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(metrics) { metric in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(metric.color)
                        .frame(width: UILayout.chartLegendDotMedium, height: UILayout.chartLegendDotMedium)

                    Text(metric.label)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: Spacing.sm)

                    Text(metric.value)
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.apple)
                }
            }
        }
        .padding(Spacing.sm)
        // Small floating popover is an allowed material usage for chart context.
        // swiftlint:disable:next liquid_glass_materials_guideline
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.glassPopoverBorder, lineWidth: BorderWidth.hairline)
        )
        .shadow(color: AppColors.glassPopoverShadow, radius: 14, y: 6)
    }
}

public enum ChartSelectionHaptics {
    public static func selectionChanged() {
        #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.72)
        #endif
    }
}

@MainActor
public enum ChartSelectionLifecycle {
    public static func handleChange<Value: Equatable>(
        from oldValue: Value?,
        to newValue: Value?,
        displayedValue: inout Value?,
        hideTask: inout Task<Void, Never>?,
        hideDelay: Duration = .milliseconds(80),
        onInitialSelection: () -> Void = { ChartSelectionHaptics.selectionChanged() },
        onDelayedClear: @escaping @MainActor () -> Void
    ) {
        hideTask?.cancel()

        if let value = newValue {
            displayedValue = value
            if oldValue == nil {
                onInitialSelection()
            }
            return
        }

        hideTask = Task {
            try? await Task.sleep(for: hideDelay)
            guard !Task.isCancelled else { return }
            await onDelayedClear()
        }
    }

    public static func cancelHideTask(_ hideTask: inout Task<Void, Never>?) {
        hideTask?.cancel()
        hideTask = nil
    }
}

public struct ChartSelectionAlignedOverlay<Content: View>: View {
    private let ratio: Double
    private let maxWidth: CGFloat
    private let content: Content

    public init(
        ratio: Double,
        maxWidth: CGFloat = 280,
        @ViewBuilder content: () -> Content
    ) {
        self.ratio = ratio
        self.maxWidth = maxWidth
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Spacing.xs * 0) {
            if ratio > 0.34 {
                Spacer(minLength: 0)
            }

            content
                .frame(maxWidth: maxWidth)

            if ratio < 0.66 {
                Spacer(minLength: 0)
            }
        }
    }
}
