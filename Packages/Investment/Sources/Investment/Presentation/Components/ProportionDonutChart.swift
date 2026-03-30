import Charts
import FinFlowCore
import SwiftUI

public struct ProportionDonutSlice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let percentage: Double
    public let color: Color

    public var isPaddingSlice: Bool { id == "__padding_slice__" }

    public init(id: String, name: String, percentage: Double, color: Color) {
        self.id = id
        self.name = name
        self.percentage = percentage
        self.color = color
    }
}

public struct ProportionDonutChart: View {
    public let title: String
    public let slices: [ProportionDonutSlice]

    @State private var selectedAngle: Double?
    @State private var displayedSliceKey: String?

    public init(title: String, slices: [ProportionDonutSlice]) {
        self.title = title
        self.slices = slices
    }

    public var body: some View {
        let chartSlices = chartRenderableSlices(from: slices)
        let activeSlice = displayedSliceKey.flatMap { key in
            slices.first(where: { $0.id == key })
        } ?? slices.first

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(AppTypography.headline)

            if let activeSlice {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(activeSlice.color)
                        .frame(width: 8, height: 8)
                    Text("\(activeSlice.name): \(String(format: "%.2f%%", activeSlice.percentage))")
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(" ")
                    .font(AppTypography.caption2)
            }

            HStack(spacing: Spacing.md) {
                Chart {
                    ForEach(chartSlices) { slice in
                        SectorMark(
                            angle: .value("Tỷ lệ", slice.percentage),
                            innerRadius: .ratio(0.58),
                            angularInset: 1.4
                        )
                        .foregroundStyle(slice.color)
                        .opacity(slice.isPaddingSlice ? 0.001 : opacity(for: slice.id))
                    }
                }
                .chartAngleSelection(value: $selectedAngle)
                .onChange(of: selectedAngle) { _, newValue in
                    let newKey = newValue.flatMap { selectedSlice(for: $0, slices: slices)?.id }
                    displayedSliceKey = newKey
                }
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(slices) { slice in
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 8, height: 8)
                            Text(slice.name)
                                .font(AppTypography.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(String(format: "%.2f%%", slice.percentage))
                                .font(AppTypography.caption2)
                                .foregroundStyle(displayedSliceKey == slice.id ? .primary : .secondary)
                        }
                        .opacity(opacity(for: slice.id))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func opacity(for sliceID: String) -> Double {
        guard let selected = displayedSliceKey else { return 1.0 }
        return selected == sliceID ? 1.0 : 0.35
    }

    private func chartRenderableSlices(from slices: [ProportionDonutSlice]) -> [ProportionDonutSlice] {
        guard slices.count == 1, let only = slices.first, only.percentage > 0 else { return slices }
        return slices + [
            ProportionDonutSlice(
                id: "__padding_slice__",
                name: "",
                percentage: 0.0001,
                color: .clear
            )
        ]
    }

    private func selectedSlice(for angle: Double, slices: [ProportionDonutSlice]) -> ProportionDonutSlice? {
        guard !slices.isEmpty else { return nil }
        let total = slices.map(\.percentage).reduce(0, +)
        guard total > 0 else { return nil }

        let normalizedAngle = max(0, min(angle, total))
        var accumulated = 0.0
        for slice in slices {
            accumulated += slice.percentage
            if normalizedAngle <= accumulated {
                return slice
            }
        }
        return slices.last
    }
}
