import Charts
import FinFlowCore
import SwiftUI

public struct ShareholderPieChart: View {
    let shareholders: [ShareholderDataPoint]

    public init(shareholders: [ShareholderDataPoint]) {
        self.shareholders = shareholders
    }

    private var topShareholders: [ShareholderDataPoint] {
        shareholders.filter { $0.name != "Cổ đông khác" }
    }

    private var othersPercentage: Double {
        shareholders.first(where: { $0.name == "Cổ đông khác" })?.percentage ?? 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Top 10 cổ đông lớn")
                    .font(AppTypography.headline)
                Spacer()
            }

            if let biggest = topShareholders.max(by: { $0.percentage < $1.percentage }) {
                Text("Lớn nhất: \(biggest.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            donutChart
                .frame(maxWidth: .infinity)
                .frame(height: 250)

            legendList

            if othersPercentage > 0 {
                infoRow("Cổ đông khác: \(String(format: "%.2f%%", othersPercentage))")
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private var donutChart: some View {
        Chart(shareholders) { sh in
            SectorMark(
                angle: .value("Tỉ lệ", sh.percentage),
                innerRadius: .ratio(0.60),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Tên", sh.name))
            .cornerRadius(3)
        }
        .chartLegend(.hidden)
    }

    private var legendList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(topShareholders.enumerated()), id: \.element.id) { idx, sh in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Circle()
                        .fill(colorForIndex(idx))
                        .frame(width: 10, height: 10)
                        .padding(.top, Spacing.xs)
                    Text(sh.name)
                        .font(AppTypography.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer()
                    Text(String(format: "%.2f%%", sh.percentage))
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func infoRow(_ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func colorForIndex(_ index: Int) -> Color {
        let palette: [Color] = [.teal, .purple, .orange, .pink, .indigo, .mint, .brown, .cyan, .red, .gray]
        return palette[index % palette.count]
    }
}
