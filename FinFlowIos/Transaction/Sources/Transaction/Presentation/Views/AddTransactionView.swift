//
//  AddTransactionView.swift
//  Transaction
//

import SwiftUI
import FinFlowCore

public struct AddTransactionView: View {
    // Router for centralized navigation
    private let router: any AppRouterProtocol
    
    // Core User Input
    @State private var amount: String = ""
    @State private var isIncome: Bool = false
    @State private var selectedCategory: String = "Chọn danh mục"
    @State private var note: String = ""
    @State private var date: Date = Date()
    
    // AI / Smart State
    @State private var aiInputText: String = ""
    @State private var isAnalyzing: Bool = false
    @FocusState private var isAiFieldFocused: Bool
    
    // Animation trigger for "Magical" auto-fill effect
    @State private var showMagicEffect: Bool = false
    
    public init(router: any AppRouterProtocol) {
        self.router = router
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()
                
                VStack(spacing: 0) {
                    
                    // 1. The "Brain" - Smart Input Bar (Pinned at top)
                    smartInputBar
                        .padding(.horizontal)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.md)
                        .zIndex(1) // Keep above scrollview
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Spacing.xl) {
                            
                            // 2. Centralized Big Amount Input
                            amountHeaderSection
                            
                            // 3. Type Selector
                            typeSelectorSection
                            
                            // 4. Details Form
                            detailsFormSection
                            
                            // 5. Save Button
                            PrimaryButton(title: "Lưu Giao Dịch") {
                                // Action Save
                                router.dismissSheet()
                            }
                            .padding(.top, Spacing.md)
                            
                        }
                        .padding(.horizontal)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, 32)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationTitle("Thêm giao dịch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Hủy") {
                        router.dismissSheet()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Smart Input Bar (The Magic)
    
    private var smartInputBar: some View {
        HStack(spacing: 8) {
            // Typing input
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(isAnalyzing ? .purple : AppColors.primary)
                    .rotationEffect(.degrees(isAnalyzing ? 360 : 0))
                    .animation(isAnalyzing ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default, value: isAnalyzing)
                
                TextField("Ví dụ: Đổ xăng 50 cành...", text: $aiInputText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .focused($isAiFieldFocused)
                    .onSubmit {
                        if !aiInputText.isEmpty {
                            triggerAIAnalysis(text: aiInputText)
                        }
                    }
                
                if !aiInputText.isEmpty && !isAnalyzing {
                    Button {
                        triggerAIAnalysis(text: aiInputText)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(100) // Pill shape
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .stroke(
                        isAiFieldFocused || isAnalyzing
                            ? LinearGradient(
                                colors: [AppColors.primary, .purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: isAiFieldFocused || isAnalyzing ? 2 : 1
                    )
            )
            .shadow(color: isAiFieldFocused || isAnalyzing ? .purple.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            
            // Voice Mic Button
            Button {
                triggerVoiceInput()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        isAnalyzing
                            ? LinearGradient(colors: [.purple, AppColors.primary], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [AppColors.primary, AppColors.primary], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            
            // Camera / OCR Button
            Button {
                // Trigger Camera UI
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.body)
                    .foregroundColor(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
        }
    }
    
    // MARK: - Core UI Sections
    
    private var amountHeaderSection: some View {
        VStack(spacing: Spacing.xs) {
            Text("Số tiền")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .center, spacing: 4) {
                Text("₫")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                TextField("0", text: $amount)
                    .keyboardType(.numberPad)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(isIncome ? .green : .red)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(height: 70)
                    .blur(radius: isAnalyzing ? 3 : 0)
                    .scaleEffect(showMagicEffect ? 1.05 : 1.0)
                    .onChange(of: amount) { oldValue, newValue in
                        let formatted = formatCurrency(newValue)
                        if amount != formatted {
                            amount = formatted
                        }
                    }
            }
            .padding(.horizontal)
        }
    }
    
    private var typeSelectorSection: some View {
        HStack(spacing: Spacing.md) {
            typeButton(title: "Chi tiêu", isSelected: !isIncome, color: .red) {
                withAnimation { isIncome = false }
            }
            typeButton(title: "Thu nhập", isSelected: isIncome, color: .green) {
                withAnimation { isIncome = true }
            }
        }
    }
    
    private var detailsFormSection: some View {
        VStack(spacing: Spacing.md) {
            // Category Selector
            Button(action: {
                // Open Category Picker
            }) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .scaleEffect(showMagicEffect ? 1.1 : 1.0)
                        Image(systemName: selectedCategory == "Di chuyển" ? "car.fill" : "square.grid.2x2.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                            .rotationEffect(.degrees(showMagicEffect ? 360 : 0))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Danh mục")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedCategory)
                            .font(.body)
                            .foregroundColor(.primary)
                            .contentTransition(.numericText()) // iOS 16+ fluid text transition
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(CornerRadius.large)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(showMagicEffect ? .orange.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: showMagicEffect ? 2 : 0.5)
                )
            }
            .buttonStyle(.plain)
            
            // Note Field
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                TextField("Ví dụ: Ăn sáng tại phở Hùng...", text: $note)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(showMagicEffect ? AppColors.primary.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: showMagicEffect ? 2 : 0.5)
            )
            
            // Date Picker
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                DatePicker("Ngày", selection: $date, displayedComponents: .date)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Helpers & Mock Logic
    
    private func typeButton(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    if isSelected {
                        color.opacity(0.15)
                    } else {
                        Rectangle().fill(.ultraThinMaterial)
                    }
                }
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isSelected ? color.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    private func triggerAIAnalysis(text: String) {
        hideKeyboard()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isAnalyzing = true
        }
        
        // Mock API Response / AI Processing Delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                isAnalyzing = false
                showMagicEffect = true // Trigger the magical highlight
                
                // Animate Amount change programmatically for visual flair
                animateAmount(to: 50000)
                note = text.isEmpty ? "Đổ xăng" : text
                selectedCategory = "Di chuyển"
                aiInputText = "" // clear input
                isIncome = false
            }
            
            // Turn off magic highlight after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { showMagicEffect = false }
            }
        }
    }
    
    private func animateAmount(to target: Int) {
        let steps = 15
        let stepDuration = 0.03
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * stepDuration)) {
                let currentVal = (target / steps) * i
                self.amount = "\(currentVal)"
            }
        }
    }
    
    private func triggerVoiceInput() {
        hideKeyboard()
        aiInputText = "Đổ xăng 50 cành"
        triggerAIAnalysis(text: "Đổ xăng 50 cành")
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func formatCurrency(_ input: String) -> String {
        let numericOnly = input.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if numericOnly.isEmpty { return "" }
        
        guard let number = Double(numericOnly) else { return input }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: number)) ?? numericOnly
    }
}
