//
//  QuickAddWidget.swift
//  FinFlowWidget
//
//  Widget hiện thu chi tháng + 3 nút nhập nhanh.
//  Small: logo + số chi/thu + 3 nút icon nhỏ.
//  Medium: cột chi/thu bên trái + 3 nút full text bên phải.
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
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
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
        Group {
            if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 5) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text("FinFlow")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Amounts
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Text(formatAmount(entry.todayExpense))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.red.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("chi")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 3) {
                    Text(formatAmount(entry.todayIncome))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("thu")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Text("Tháng này")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            // 3 nút icon nhỏ (phù hợp small)
            HStack(spacing: 6) {
                iconButton(icon: "mic.fill",          tint: .blue,   url: "finflow://quickadd?mode=voice", label: "Nói")
                iconButton(icon: "keyboard",          tint: .purple, url: "finflow://quickadd?mode=text",  label: "Nhập")
                iconButton(icon: "camera.viewfinder", tint: .orange, url: "finflow://quickadd?mode=ocr",   label: "Chụp")
            }
        }
        .padding(13)
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 8) {
            // Trái: chi/thu — chiều rộng cố định để không tranh chỗ với nút
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("FinFlow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow(label: "Chi", amount: entry.todayExpense, color: .red)
                    summaryRow(label: "Thu", amount: entry.todayIncome,  color: .green)
                }
                Spacer(minLength: 0)
                Text("Tháng này")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: 94, alignment: .leading)
            .layoutPriority(0)

            Divider().padding(.vertical, 6)

            // Phải: 3 nút full text — lấy toàn bộ phần còn lại
            VStack(spacing: 6) {
                actionRow(icon: "mic.fill",          label: "Giọng nói",    tint: .blue,   url: "finflow://quickadd?mode=voice")
                actionRow(icon: "keyboard",          label: "Nhập văn bản", tint: .purple, url: "finflow://quickadd?mode=text")
                actionRow(icon: "camera.viewfinder", label: "Chụp hoá đơn", tint: .orange, url: "finflow://quickadd?mode=ocr")
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }

    // MARK: - Sub-components

    /// Nút icon vuông nhỏ cho small widget
    private func iconButton(icon: String, tint: Color, url: String, label: String) -> some View {
        Link(destination: URL(string: url) ?? URL(string: "finflow://")!) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            // FIX: contentShape đảm bảo toàn bộ vùng VStack đều tappable
            .contentShape(Rectangle())
        }
    }

    /// Hàng nút full text cho medium widget
    private func actionRow(icon: String, label: String, tint: Color, url: String) -> some View {
        Link(destination: URL(string: url) ?? URL(string: "finflow://")!) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            // FIX: contentShape đảm bảo vùng Spacer() cũng tappable → không miss tap
            .contentShape(Rectangle())
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
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        guard amount > 0 else { return "0 ₫" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: amount)) ?? "0") + " ₫"
    }
}

// MARK: - Widget Definition

struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Thu Chi Tháng Này")
        .description("Xem chi tiêu và thu nhập tháng này, nhập nhanh giao dịch mới.")
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
