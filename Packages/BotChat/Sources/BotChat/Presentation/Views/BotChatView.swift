import FinFlowCore
import SwiftUI

public struct FinFlowBotChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BotChatViewModel
    @FocusState private var isComposerFocused: Bool

    public init(
        threadId: String,
        quickPrompts: [String] = [
            "Tóm tắt chi tiêu tuần này",
            "Kiểm tra ngân sách tháng này",
            "Gợi ý tối ưu danh mục đầu tư"
        ],
        initialPrompt: String? = nil,
        loadMessagesHandler: (@Sendable () async throws -> [FinFlowBotChatMessage])? = nil,
        sendMessageHandler: (@Sendable (String) async throws -> FinFlowBotSendResult)? = nil
    ) {
        self._viewModel = State(initialValue: BotChatViewModel(
            threadId: threadId,
            quickPrompts: quickPrompts,
            initialPrompt: initialPrompt,
            loadMessagesHandler: loadMessagesHandler,
            sendMessageHandler: sendMessageHandler
        ))
    }

    public var body: some View {
        VStack(spacing: .zero) {
            chatList
            composer.background(AppColors.appBackground)
        }
        .navigationTitle("FinFlow Bot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Đóng") {
                    isComposerFocused = false
                    dismiss()
                }
                .font(AppTypography.buttonTitle)
            }
        }
        .task { await viewModel.onAppear() }
        .alert(
            "Không thể xử lý yêu cầu",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Đã có lỗi xảy ra.")
        }
    }

    // MARK: - Chat List

    private var chatList: some View {
        List {
            Section {
                if viewModel.shouldShowQuickPrompts {
                    botIntroCard
                        .listRowBackground(AppColors.settingsCardBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))

                    quickPromptSection
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: .zero, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                }

                if viewModel.isLoadingHistory {
                    statusRow(text: "Đang tải lịch sử hội thoại...")
                }

                ForEach(viewModel.messages) { message in
                    FinFlowBotChatMessageRow(message: message)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: .zero, trailing: Spacing.md))
                }

                if viewModel.isBotTyping {
                    statusRow(text: "FinFlow Bot đang soạn...")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.appBackground)
        .onTapGesture { isComposerFocused = false }
    }

    // MARK: - Subviews

    private var botIntroCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(OpacityLevel.ultraLight))
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                Image(systemName: "sparkles")
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(AppColors.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BorderWidth.hairline) {
                Text("Trợ lý tài chính cá nhân")
                    .font(AppTypography.headline).foregroundStyle(.primary)
                Text("Mình trả lời nhanh theo dữ liệu trong FinFlow và đưa gợi ý hành động cụ thể.")
                    .font(AppTypography.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var quickPromptSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(viewModel.availableQuickPrompts, id: \.self) { prompt in
                    Button(prompt) {
                        isComposerFocused = false
                        viewModel.applyPrompt(prompt)
                    }
                    .buttonStyle(.bordered).controlSize(.small).font(AppTypography.caption)
                    .disabled(viewModel.isLoadingHistory || viewModel.isBotTyping)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gợi ý câu hỏi nhanh")
    }

    private func statusRow(text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            ProgressView().controlSize(.small)
            Text(text).font(AppTypography.caption).foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: .zero, trailing: Spacing.md))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Tin nhắn")
                .font(AppTypography.caption).foregroundStyle(.secondary).accessibilityHidden(true)

            HStack(alignment: .bottom, spacing: Spacing.xs) {
                TextField("Hỏi về thu chi, ngân sách, đầu tư...", text: $viewModel.draft, axis: .vertical)
                    .font(AppTypography.body).lineLimit(1...4).submitLabel(.send)
                    .onSubmit {
                        isComposerFocused = false
                        viewModel.sendMessage()
                    }
                    .focused($isComposerFocused)
                    .disabled(viewModel.isLoadingHistory || viewModel.isBotTyping)

                Button {
                    isComposerFocused = false
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(AppTypography.displaySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.canSend ? AppColors.primary : AppColors.disabled)
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Gửi tin nhắn")
            }
            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
            .background(AppColors.cardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(AppColors.inputBorderDefault, lineWidth: BorderWidth.hairline)
            )
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.xs).padding(.bottom, Spacing.xs)
        .background(AppColors.appBackground)
    }
}
