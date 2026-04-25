import FinFlowCore
import SwiftUI

public struct ChatThreadListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChatThreadListViewModel
    @State private var selectedThreadId: String?

    private let makeChat: (String, String?) -> AnyView

    public init(
        viewModel: ChatThreadListViewModel,
        makeChat: @escaping (String, String?) -> AnyView
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.makeChat = makeChat
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.threads.isEmpty {
                ProgressView("Đang tải...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.threads.isEmpty {
                emptyState
            } else {
                threadList
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Hội thoại")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Đóng") { dismiss() }
                    .font(AppTypography.buttonTitle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await createAndOpen() }
                } label: {
                    Image(systemName: "plus")
                }
                .font(AppTypography.buttonTitle)
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.loadThreads() }
        .alert(
            "Lỗi",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedThreadId != nil },
            set: { if !$0 { selectedThreadId = nil } }
        )) {
            if let threadId = selectedThreadId {
                makeChat(threadId, nil)
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(AppTypography.displayXL)
                .foregroundStyle(AppColors.disabled)

            Text("Chưa có hội thoại nào")
                .font(AppTypography.headline)
                .foregroundStyle(.secondary)

            Text("Nhấn + để bắt đầu cuộc trò chuyện mới với FinFlow Bot.")
                .font(AppTypography.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                Task { await createAndOpen() }
            } label: {
                Label("Tạo hội thoại mới", systemImage: "plus.bubble")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var threadList: some View {
        List {
            ForEach(viewModel.threads) { thread in
                Button {
                    selectedThreadId = thread.id
                } label: {
                    threadRow(thread)
                }
                .listRowBackground(AppColors.cardBackground)
                .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
            }
            .onDelete { offsets in
                viewModel.deleteThread(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.loadThreads() }
    }

    private func threadRow(_ thread: ChatThreadResponse) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(OpacityLevel.ultraLight))
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                Image(systemName: "sparkles")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BorderWidth.hairline) {
                Text(thread.title ?? "Cuộc trò chuyện mới")
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    if let ticker = thread.lastTicker, !ticker.isEmpty {
                        Text(ticker)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, BorderWidth.medium)
                            .background(AppColors.accent.opacity(OpacityLevel.ultraLight))
                            .clipShape(.rect(cornerRadius: CornerRadius.micro))
                    }

                    Text(formatDate(thread.updatedAt ?? thread.createdAt))
                        .font(AppTypography.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.caption2)
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Helpers

    private func createAndOpen() async {
        if let threadId = await viewModel.createThread() {
            selectedThreadId = threadId
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString, !dateString.isEmpty else { return "" }
        let formatters: [DateFormatter] = [Self.isoWithMillis, Self.isoWithout]
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return Self.displayFormatter.string(from: date)
            }
        }
        return ""
    }

    private static let isoWithMillis: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()

    private static let isoWithout: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
