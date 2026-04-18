//
//  AddTransactionView.swift
//  Transaction
//

import FinFlowCore
import PhotosUI
import SwiftUI
import UIKit

public struct AddTransactionView: View {
    private enum ActiveSheet: String, Identifiable {
        case categoryPicker
        case accountPicker

        var id: String { rawValue }
    }

    private enum CameraSheet: String, Identifiable {
        case camera

        var id: String { rawValue }
    }

    private enum InputField: Hashable {
        case amount
        case note
    }

    @Bindable var viewModel: AddTransactionViewModel

    // AI / Smart State - Keeping locally for UI effect
    @State private var aiInputText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var speechManager = SpeechToTextManager()
    @State private var speechErrorMessage: String?
    @State private var cameraSheet: CameraSheet?
    @State private var showCameraOptions: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isOCRing: Bool = false
    @State private var ocrErrorMessage: String?

    // Animation trigger for "Magical" auto-fill effect
    @State private var showMagicEffect: Bool = false

    // Category Selection State
    @State private var activeSheet: ActiveSheet?
    @FocusState private var focusedField: InputField?

    public init(viewModel: AddTransactionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: .zero) {
            // 1. The "Brain" - Smart Input Bar (Pinned at top)
            AISmartInputBar(
                text: $aiInputText,
                isAnalyzing: Binding(
                    get: { isAnalyzing || isOCRing || speechManager.isListening },
                    set: { _ in }
                ),
                placeholder: "Ví dụ: Đổ xăng 50 cành...",
                onSubmit: { text in
                    submitTextForAnalysis(text, mirrorToInput: true)
                },
                onVoice: {
                    toggleVoiceInput()
                },
                onCamera: {
                    // Stop voice capture to avoid AVAudioSession conflicts.
                    if speechManager.isListening {
                        speechManager.stopListening()
                    }
                    showCameraOptions = true
                }
            )
            .padding(.horizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .zIndex(1)  // Keep above scrollview

            Form {
                Section {
                    amountHeaderSection
                        .padding(.vertical, Spacing.sm)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    typeSelectorSection
                        .padding(.vertical, Spacing.sm)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                // 4. Details Form
                detailsFormSection

                Section {
                    // 5. Save Button
                    Button("Lưu Giao Dịch") {
                        Task {
                            await viewModel.saveTransaction()
                        }
                    }
                    .primaryButton(isLoading: viewModel.isLoading)
                    .disabled(!viewModel.isSaveEnabled || viewModel.isLoading)
                    .opacity(viewModel.isSaveEnabled ? 1.0 : OpacityLevel.medium)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColors.appBackground)
        .navigationTitle(viewModel.isEditMode ? "Sửa giao dịch" : "Thêm giao dịch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Hủy") {
                    viewModel.cancel()
                }
                .foregroundStyle(AppColors.primary)
            }
        }
        .task {
            await viewModel.fetchCategories()
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .categoryPicker:
                CategorySelectionSheet(
                    isPresented: Binding(
                        get: { activeSheet == .categoryPicker },
                        set: { isPresented in
                            if !isPresented { activeSheet = nil }
                        }
                    ),
                    selectedCategory: $viewModel.selectedCategory,
                    categories: viewModel.filteredCategories
                )
            case .accountPicker:
                AccountSelectionSheet(
                    isPresented: Binding(
                        get: { activeSheet == .accountPicker },
                        set: { isPresented in
                            if !isPresented { activeSheet = nil }
                        }
                    ),
                    selectedAccount: $viewModel.selectedAccount,
                    accounts: viewModel.transactionEligibleAccounts
                )
            }
        }
        .alertHandler(
            Binding<AppErrorAlert?>(
                get: { viewModel.alert },
                set: { viewModel.alert = $0 }
            )
        )
        .alert("Lỗi ghi âm", isPresented: Binding(
            get: { speechErrorMessage != nil },
            set: { isPresented in
                if !isPresented { speechErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(speechErrorMessage ?? "")
        }
        .alert("Lỗi OCR", isPresented: Binding(
            get: { ocrErrorMessage != nil },
            set: { isPresented in
                if !isPresented { ocrErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ocrErrorMessage ?? "")
        }
        .confirmationDialog(
            "Chọn nguồn hoá đơn",
            isPresented: $showCameraOptions,
            titleVisibility: .visible
        ) {
            Button("Chụp ảnh") {
                cameraSheet = .camera
            }
            Button("Ảnh đã có") {
                selectedPhotoItem = nil
                showPhotoPicker = true
            }
            Button("Hủy", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .sheet(item: $cameraSheet) { _ in
            CameraImagePicker(
                onImagePicked: { image in
                selectedImage = image
                cameraSheet = nil
                Task { await runOCRAndAnalyzeIfPossible() }
            }
            ) {
                cameraSheet = nil
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                        let image = UIImage(data: data) {
                        selectedImage = image
                        showPhotoPicker = false
                        await runOCRAndAnalyzeIfPossible()
                    } else {
                        ocrErrorMessage = "Không thể đọc ảnh đã chọn."
                    }
                } catch {
                    ocrErrorMessage = "Không thể đọc ảnh đã chọn: \(error.localizedDescription)"
                }
            }
        }
        .onDisappear {
            speechManager.stopListening()
        }
    }

    // MARK: - Core UI Sections

    private var amountHeaderSection: some View {
        VStack(spacing: Spacing.xs) {
            Text("Số tiền")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: Spacing.xs / 2) {
                Text("₫")
                    .font(AppTypography.displayMedium)
                    .foregroundStyle(.primary)

                TextField("0", text: $viewModel.amount)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .amount)
                    .font(AppTypography.displayXL)
                    .foregroundStyle(viewModel.isIncome ? AppColors.success : AppColors.expense)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(height: Layout.inputRowHeight)
                    .blur(radius: isAnalyzing ? 3 : 0)
                    .scaleEffect(showMagicEffect ? 1.05 : 1.0)
                    .onChange(of: viewModel.amount) { _, newValue in
                        let formatted = formatCurrency(newValue)
                        if viewModel.amount != formatted {
                            viewModel.amount = formatted
                        }
                    }
            }
            .padding(.horizontal)
        }
    }

    private var typeSelectorSection: some View {
        HStack(spacing: Spacing.md) {
            TypeOptionButton(
                title: "Chi tiêu",
                isSelected: !viewModel.isIncome,
                color: AppColors.expense
            ) {
                withAnimation { viewModel.isIncome = false }
            }

            TypeOptionButton(
                title: "Thu nhập",
                isSelected: viewModel.isIncome,
                color: AppColors.success
            ) {
                withAnimation { viewModel.isIncome = true }
            }
        }
    }

    @ViewBuilder
    private var detailsFormSection: some View {
        Section {
            // Category Selector
            Button {
                activeSheet = .categoryPicker
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(OpacityLevel.ultraLight))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                            .scaleEffect(showMagicEffect ? 1.1 : 1.0)

                        // Icon mapping will require a helper, using default for now
                        Image(
                            systemName: viewModel.selectedCategory?.icon ?? "square.grid.2x2.fill"
                        )
                        .foregroundStyle(AppColors.accent)
                        .font(AppTypography.iconMedium)
                        .rotationEffect(.degrees(showMagicEffect ? 360 : 0))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Danh mục")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.selectedCategory?.name ?? "Chọn danh mục")
                            .font(AppTypography.body)
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())  // iOS 16+ fluid text transition
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(AppTypography.caption)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(showMagicEffect ? AppColors.accent.opacity(0.1) : nil)

            // Account Selector (transaction-eligible only)
            Button {
                if !viewModel.transactionEligibleAccounts.isEmpty {
                    activeSheet = .accountPicker
                } else {
                    viewModel.alert = AppError
                        .validationError("Chưa có tài khoản khả dụng. Thêm tài khoản trong tab \"Tài sản\".")
                        .toAppAlert(defaultTitle: "Thiếu tài khoản")
                }
            } label: {
                HStack {
                    ZStack {
                        let iconColor = Color(hex: viewModel.selectedAccount?.accountType.color ?? "#10B981")
                        Circle()
                            .fill(iconColor.opacity(OpacityLevel.ultraLight))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        Image(systemName: viewModel.selectedAccount?.accountType.icon ?? "banknote.fill")
                            .foregroundStyle(iconColor)
                            .font(AppTypography.iconMedium)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Tài khoản")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.selectedAccount?.name ?? "Chọn tài khoản")
                            .font(AppTypography.body)
                            .foregroundStyle(.primary)
                    }
                    Spacer()

                    if let account = viewModel.selectedAccount {
                        BalanceLabel(balance: account.balance, style: .signed)
                            .font(AppTypography.caption)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(AppTypography.caption)
                        .padding(.leading, Spacing.xs)
                }
            }
            .buttonStyle(.plain)

            // Note Field
            HStack {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                    .frame(width: Spacing.touchTarget)

                TextField("Ví dụ: Ăn sáng tại phở Hùng...", text: $viewModel.note)
                    .focused($focusedField, equals: .note)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
            }
            .listRowBackground(showMagicEffect ? AppColors.primary.opacity(0.1) : nil)

            // Date Picker
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                    .frame(width: Spacing.touchTarget)
                DatePicker("Ngày", selection: $viewModel.date, displayedComponents: .date)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Helpers

    private func triggerAIAnalysis(text: String) {
        focusedField = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isAnalyzing = true
        }

        Task {
            await viewModel.analyzeText(input: text)

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    isAnalyzing = false
                }
            }

            guard viewModel.alert == nil else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showMagicEffect = true
                    aiInputText = ""
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showMagicEffect = false }
                }
            }
        }
    }

    private func toggleVoiceInput() {
        if speechManager.isListening {
            let finalText = speechManager.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            speechManager.stopListening()
            if !finalText.isEmpty {
                submitTextForAnalysis(finalText, mirrorToInput: true)
            }
            return
        }

        speechManager.startListening(
            onPartialText: { partialText in
                aiInputText = partialText
            },
            onError: { message in
                speechErrorMessage = message
            },
            onAutoSubmit: { finalText in
                // User stopped speaking — stop mic and send to AI automatically.
                speechManager.stopListening()
                submitTextForAnalysis(finalText, mirrorToInput: true)
            }
        )
    }

    private func runOCRAndAnalyzeIfPossible() async {
        guard let image = selectedImage else { return }
        guard !isOCRing else { return }
        isOCRing = true
        defer {
            isOCRing = false
            selectedImage = nil
            selectedPhotoItem = nil
        }

        do {
            let text = try await ReceiptOCRService().recognizeText(from: image)
            submitTextForAnalysis(text, mirrorToInput: false)
        } catch {
            ocrErrorMessage = error.localizedDescription
        }
    }

    private func submitTextForAnalysis(_ text: String, mirrorToInput: Bool) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if mirrorToInput {
            aiInputText = normalized
        }
        triggerAIAnalysis(text: normalized)
    }

    private func formatCurrency(_ input: String) -> String {
        return CurrencyFormatter.formatInput(input)
    }
}
