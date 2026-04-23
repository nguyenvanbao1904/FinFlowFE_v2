import Charts
import FinFlowCore
import SwiftUI

// MARK: - Dividend Y Domain Helpers

func dividendCashYDomain(maxValue: Double) -> ClosedRange<Double> {
    let headroom = 0.12
    guard maxValue > 0 else { return 0 ... 1 }
    let padded = maxValue * (1.0 + headroom)
    let t = pow(10.0, floor(log10(max(padded, 1e-9))))
    let step = [0.25, 0.5, 1, 2, 5, 10].map { $0 * t }.first { $0 >= padded / 5 } ?? (10 * t)
    let upper = max(ceil(padded / step) * step, maxValue * 1.001)
    return 0 ... upper
}

func dividendStockPercentYDomain(maxValue: Double) -> ClosedRange<Double> {
    let headroom = 0.12
    guard maxValue > 0 else { return 0 ... 1 }
    let padded = maxValue * (1.0 + headroom)
    let upper = max(ceil(padded / 10.0) * 10.0, maxValue + 1)
    return 0 ... upper
}

// MARK: - Horizontal Layout Modifier

struct DividendHorizontalChartLayout: ViewModifier {
    let labels: [String]
    let needsScroll: Bool
    let fullScreen: Bool
    let inlineVisibleLength: Int
    let fullVisibleLength: Int
    @Binding var scrollYear: String
    let initialInlineScrollLabel: String
    let initialFullScrollLabel: String

    func body(content: Content) -> some View {
        Group {
            if needsScroll {
                if fullScreen {
                    content
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: fullVisibleLength)
                        .chartScrollPosition(x: .constant(initialFullScrollLabel))
                } else {
                    content
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: inlineVisibleLength)
                        .chartScrollPosition(x: inlineScrollPositionBinding)
                }
            } else {
                content
                    .chartXScale(domain: labels)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inlineScrollPositionBinding: Binding<String> {
        Binding(
            get: { scrollYear.isEmpty ? initialInlineScrollLabel : scrollYear },
            set: { scrollYear = $0 }
        )
    }
}

func shouldShowDividendChartLabel(_ label: String, labels: [String], fullScreen: Bool) -> Bool {
    guard let idx = labels.firstIndex(of: label) else { return true }
    let stride = fullScreen ? max(1, labels.count / 12) : max(1, labels.count / 4)
    return idx == labels.count - 1 || idx % stride == 0
}
