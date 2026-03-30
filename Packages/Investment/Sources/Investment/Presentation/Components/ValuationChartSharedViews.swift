import FinFlowCore
import SwiftUI

enum ValuationChartFullscreenLayout {
    /// Dành thêm chỗ cho nhãn trục X khi fullscreen ngang.
    static let landscapeHeightTrim: CGFloat = 64
}

/// Nút ↺ thu phóng + phóng to — dùng chung cho chart định giá.
struct ValuationChartZoomToolbar: View {
    var isZoomed: Bool
    var onReset: () -> Void
    var onFullscreen: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if isZoomed {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Đặt lại thu phóng chart")
            }
            Button(action: onFullscreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 28, height: 28)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Phóng to biểu đồ")
        }
    }
}

/// Badge so sánh với trung vị / TB trong khoảng.
struct ValuationMedianMeanComparisonBadge: View {
    let current: Double
    let rangeMedian: Double?
    let rangeMean: Double?

    private var diff: Double? {
        guard let m = rangeMedian, m != 0 else { return nil }
        return current - m
    }

    private var pct: Double? {
        guard let d = diff, let m = rangeMedian, m != 0 else { return nil }
        return abs(d) / m * 100
    }

    var body: some View {
        if let median = rangeMedian, let pct {
            let isLower = (diff ?? 0) <= 0
            let text =
                pct < 1
                ? "≈ Trung vị (trong khoảng)"
                : "\(isLower ? "thấp hơn" : "cao hơn") \(String(format: "%.1f%%", pct)) so với trung vị \(String(format: "%.2f", median))"
            let color: Color = pct < 1 ? .secondary : (isLower ? .green : .red)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(text)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xs)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let mean = rangeMean, mean.isFinite, mean > 0 {
                    let dMean = current - mean
                    let pMean = abs(dMean) / mean * 100
                    let lowerMean = dMean <= 0
                    let (textMean, colorMean): (String, Color) = {
                        if pMean < 5 {
                            let t =
                                pMean < 1
                                ? "≈ Trung bình (trong khoảng, đường tím)"
                                : "Gần TB \(String(format: "%.1f%%", pMean)) so với \(String(format: "%.2f", mean))"
                            return (t, .orange)
                        }
                        let t =
                            "\(lowerMean ? "thấp hơn" : "cao hơn") \(String(format: "%.1f%%", pMean)) so với TB \(String(format: "%.2f", mean))"
                        return (t, lowerMean ? .green : .red)
                    }()
                    Text(textMean)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(colorMean)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs)
                        .background(colorMean.opacity(0.12))
                        .clipShape(Capsule())
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        } else {
            Text("Chưa có trung vị trong khoảng (không đủ dữ liệu hoặc giá trị không hợp lệ).")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
}

struct ValuationFullscreenChartHost<Content: View>: View {
    var xAxisZoom: CGFloat
    var yAxisZoom: CGFloat
    var pinchMagnification: CGFloat
    @ViewBuilder var chart: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let baseHeight = ChartFullscreenSupport.preferredChartHeight(for: proxy.size)
            let adjustedHeight = isLandscape
                ? max(Layout.chartHeight, baseHeight - ValuationChartFullscreenLayout.landscapeHeightTrim)
                : baseHeight
            VStack(spacing: Spacing.md) {
                chart()
                    .frame(maxWidth: .infinity)
                    .frame(height: adjustedHeight)
                    .valuationChartZoomAnimations(
                        xAxisZoom: xAxisZoom,
                        yAxisZoom: yAxisZoom,
                        pinchMagnification: pinchMagnification
                    )
                    .padding(Spacing.md)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            }
            .padding(.bottom, isLandscape ? Spacing.md : 0)
        }
    }
}
