//
//  FinFlowBotChatPlaceholderView.swift
//  FinFlowCore
//
//  Professional chat surface for FinFlow Bot.
//

import SwiftUI

private struct FinFlowBotChatMessage: Identifiable, Equatable {
    enum Sender {
        case bot
        case user
    }

    let id = UUID()
    let sender: Sender
    let text: String
    let sentAt: Date
}

/// Sheet chat FinFlow Bot theo phong cách native iOS.
public struct FinFlowBotChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var isBotTyping = false
    @State private var showsResetDialog = false
    @State private var messages: [FinFlowBotChatMessage]

    private let quickPrompts: [String]

    public init(
        quickPrompts: [String] = [
            "Tóm tắt chi tiêu tuần này",
            "Kiểm tra ngân sách tháng này",
            "Gợi ý tối ưu danh mục đầu tư"
        ]
    ) {
        self.quickPrompts = quickPrompts
        self._messages = State(
            initialValue: [
                FinFlowBotChatMessage(
                    sender: .bot,
                    text: "Chào bạn, mình là FinFlow Bot. Hãy hỏi về chi tiêu, ngân sách hoặc danh mục đầu tư để mình phân tích nhanh cho bạn.",
                    sentAt: Date()
                )
            ]
        )
    }

    public var body: some View {
        List {
            Section {
                botIntroCard
                    .listRowBackground(AppColors.settingsCardBackground)
                    .listRowInsets(
                        EdgeInsets(top: Spacing.xs, leading: Spacing.sm, bottom: Spacing.xs, trailing: Spacing.sm)
                    )

                quickPromptSection
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(top: .zero, leading: Spacing.sm, bottom: Spacing.xs, trailing: Spacing.sm)
                    )

                ForEach(messages) { message in
                    FinFlowBotChatMessageRow(message: message)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: Spacing.xs, leading: Spacing.sm, bottom: .zero, trailing: Spacing.sm)
                        )
                }

                if isBotTyping {
                    botTypingRow
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: Spacing.xs, leading: Spacing.sm, bottom: .zero, trailing: Spacing.sm)
                        )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .navigationTitle("FinFlow Bot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Làm mới") {
                    showsResetDialog = true
                }
                .font(AppTypography.buttonTitle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Đóng") {
                    dismiss()
                }
                .font(AppTypography.buttonTitle)
            }
        }
        .confirmationDialog("Làm mới hội thoại?", isPresented: $showsResetDialog, titleVisibility: .visible) {
            Button("Làm mới", role: .destructive) {
                resetConversation()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Các tin nhắn hiện tại sẽ được xoá khỏi phiên chat này.")
        }
    }

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
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                Text("Mình trả lời nhanh theo dữ liệu trong FinFlow và đưa gợi ý hành động cụ thể.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickPromptSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(prompt) {
                        applyPrompt(prompt)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(AppTypography.caption)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gợi ý câu hỏi nhanh")
    }

    private var botTypingRow: some View {
        HStack(spacing: Spacing.xs) {
            ProgressView()
                .controlSize(.small)
            Text("FinFlow Bot đang soạn...")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Tin nhắn")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            HStack(alignment: .bottom, spacing: Spacing.xs) {
                TextField("Hỏi về thu chi, ngân sách, đầu tư...", text: $draft, axis: .vertical)
                    .font(AppTypography.body)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit(sendMessage)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppTypography.displaySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canSend ? AppColors.primary : AppColors.disabled)
                .disabled(!canSend)
                .accessibilityLabel("Gửi tin nhắn")
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.cardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(AppColors.inputBorderDefault, lineWidth: BorderWidth.hairline)
            )
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBotTyping
    }

    private func applyPrompt(_ prompt: String) {
        draft = prompt
        sendMessage()
    }

    private func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isBotTyping else { return }

        draft = ""
        messages.append(FinFlowBotChatMessage(sender: .user, text: trimmed, sentAt: Date()))
        isBotTyping = true

        let response = botReply(for: trimmed)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            messages.append(FinFlowBotChatMessage(sender: .bot, text: response, sentAt: Date()))
            isBotTyping = false
        }
    }

    private func botReply(for prompt: String) -> String {
        let normalized = prompt.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("ngan sach") {
            return "Bạn có thể đặt ngưỡng cảnh báo ở mức 85% ngân sách để tránh vượt chi trước tuần cuối tháng."
        }
        if normalized.contains("chi tieu") || normalized.contains("thu chi") {
            return "Chi tiêu lớn nhất hiện nên gom theo 3 nhóm chính để thấy rõ khoản nào có thể cắt giảm ngay trong tuần này."
        }
        if normalized.contains("dau tu") || normalized.contains("co phieu") || normalized.contains("danh muc") {
            return "Mình gợi ý theo dõi tỷ trọng tiền mặt và biến động theo tuần để cân bằng rủi ro danh mục trước khi thêm vị thế mới."
        }
        return "Mình đã nhận câu hỏi. Bạn có thể hỏi cụ thể theo mốc thời gian như “7 ngày gần đây” hoặc “tháng này” để mình trả lời sát hơn."
    }

    private func resetConversation() {
        messages = [
            FinFlowBotChatMessage(
                sender: .bot,
                text: "Phiên chat mới đã sẵn sàng. Bạn muốn bắt đầu từ thu chi, ngân sách hay đầu tư?",
                sentAt: Date()
            )
        ]
        draft = ""
        isBotTyping = false
    }
}

@available(*, deprecated, renamed: "FinFlowBotChatView")
public typealias FinFlowBotChatPlaceholderView = FinFlowBotChatView

private struct FinFlowBotChatMessageRow: View {
    let message: FinFlowBotChatMessage

    private var isBot: Bool {
        message.sender == .bot
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if isBot {
                Image(systemName: "sparkles")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(AppColors.primary.opacity(OpacityLevel.ultraLight))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            } else {
                Spacer(minLength: Spacing.touchTarget)
            }

            VStack(alignment: isBot ? .leading : .trailing, spacing: BorderWidth.hairline) {
                Text(message.text)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                    .font(AppTypography.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: isBot ? .leading : .trailing)
            .background(isBot ? AppColors.cardBackground : AppColors.primary.opacity(OpacityLevel.light))
            .clipShape(.rect(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isBot
                            ? AppColors.inputBorderDefault.opacity(OpacityLevel.medium)
                            : AppColors.primary.opacity(OpacityLevel.medium),
                        lineWidth: BorderWidth.hairline
                    )
            )
            .frame(maxWidth: .infinity, alignment: isBot ? .leading : .trailing)

            if isBot {
                Spacer(minLength: Spacing.lg)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
