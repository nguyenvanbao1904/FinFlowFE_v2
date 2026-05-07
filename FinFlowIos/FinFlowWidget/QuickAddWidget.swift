//
//  QuickAddWidget.swift
//  FinFlowWidget
//
//  Widget nhập giao dịch nhanh: Voice, Text, OCR.
//  Dùng Link(destination:) — cách Apple khuyến nghị để deep link từng nút trong widget.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct QuickAddEntry: TimelineEntry {
    let date: Date
    let todayExpense: Double
    let todayIncome: Double
}

// MARK: - Timeline Provider

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: Date(), todayExpense: 450_000, todayIncome: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> QuickAddEntry {
        QuickAddEntry(
            date: Date(),
            todayExpense: QuickAddSharedState.getTodayExpense(),
            todayIncome: QuickAddSharedState.getTodayIncome()
        )
    }
}

// MARK: - Widget View

struct QuickAddWidgetView: View {
    let entry: QuickAddEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    // MARK: - Small: 3 link-buttons + chi hôm nay

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("FinFlow")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if entry.todayExpense > 0 || entry.todayIncome > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatAmount(entry.todayExpense))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.red.opacity(0.9))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("chi hôm nay")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                actionLink(
                    systemImage: "mic.fill",
                    label: "Nói",
                    tint: .blue,
                    url: "finflow://quickadd?mode=voice"
                )
                actionLink(
                    systemImage: "sparkles",
                    label: "AI",
                    tint: .purple,
                    url: "finflow://quickadd?mode=text"
                )
                actionLink(
                    systemImage: "camera.viewfinder",
                    label: "OCR",
                    tint: .orange,
                    url: "finflow://quickadd?mode=ocr"
                )
            }
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Medium: summary bên trái + 3 link-rows bên phải

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("FinFlow")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    summaryRow(label: "Chi", amount: entry.todayExpense, color: .red)
                    summaryRow(label: "Thu", amount: entry.todayIncome, color: .green)
                }

                Spacer()

                Text("Hôm nay")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().padding(.vertical, 8)

            VStack(spacing: 8) {
                bigActionLink(
                    systemImage: "mic.fill",
                    label: "Giọng nói",
                    tint: .blue,
                    url: "finflow://quickadd?mode=voice"
                )
                bigActionLink(
                    systemImage: "sparkles",
                    label: "Văn bản AI",
                    tint: .purple,
                    url: "finflow://quickadd?mode=text"
                )
                bigActionLink(
                    systemImage: "camera.viewfinder",
                    label: "Chụp hoá đơn",
                    tint: .orange,
                    url: "finflow://quickadd?mode=ocr"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Sub-components

    private func actionLink(
        systemImage: String,
        label: String,
        tint: Color,
        url: String
    ) -> some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bigActionLink(
        systemImage: String,
        label: String,
        tint: Color,
        url: String
    ) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    private func summaryRow(label: String, amount: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(formatAmount(amount))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color.opacity(0.9))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        guard amount > 0 else { return "0 ₫" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(formatted) ₫"
    }
}

// MARK: - Widget Definition

struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Nhập Giao Dịch Nhanh")
        .description("Nhập thu chi bằng giọng nói, văn bản AI, hoặc chụp hoá đơn ngay từ màn hình chính.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    QuickAddWidget()
} timeline: {
    QuickAddEntry(date: Date(), todayExpense: 180_000, todayIncome: 0)
    QuickAddEntry(date: Date(), todayExpense: 450_000, todayIncome: 2_000_000)
}

#Preview(as: .systemMedium) {
    QuickAddWidget()
} timeline: {
    QuickAddEntry(date: Date(), todayExpense: 450_000, todayIncome: 2_000_000)
}
