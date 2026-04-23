//
//  PINEntry.swift
//  FinFlowCore
//
//  Consolidated PIN input components: sheet, input view, code grid, digit box.
//  Used by Identity (lock screen, login) and Profile (create/change PIN).
//

import SwiftUI

// MARK: - Display Mode

public enum PINDisplayMode {
    case dots      // Secure PIN display
    case numbers   // OTP display
}

// MARK: - Sheet Extension

extension View {
    /// Present PIN input in a standardized sheet.
    public func pinInputSheet(
        isPresented: Binding<Bool>,
        pin: Binding<String>,
        title: String = "Nhập mã PIN",
        subtitle: String? = nil,
        showConfirmButton: Bool = true,
        isLoading: Bool = false,
        displayMode: PINDisplayMode = .dots,
        allowDismissal: Bool = false,
        onComplete: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onForgotPIN: (() -> Void)? = nil,
        alert: Binding<AppErrorAlert?> = .constant(nil)
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            SheetContainer(
                title: title,
                detents: [.medium],
                allowDismissal: allowDismissal,
                onDismiss: onDismiss
            ) {
                PINSheetContent(
                    pin: pin,
                    alert: alert,
                    subtitle: subtitle,
                    showConfirmButton: showConfirmButton,
                    isLoading: isLoading,
                    displayMode: displayMode,
                    onComplete: onComplete,
                    onCancel: onCancel,
                    onForgotPIN: onForgotPIN
                )
            }
        }
    }
}

// MARK: - Sheet Content (owns FocusState)

private struct PINSheetContent: View {
    @Binding var pin: String
    @FocusState private var isFocused: Bool
    @Binding var alert: AppErrorAlert?

    let subtitle: String?
    let showConfirmButton: Bool
    let isLoading: Bool
    let displayMode: PINDisplayMode
    let onComplete: (String) -> Void
    let onCancel: (() -> Void)?
    let onForgotPIN: (() -> Void)?

    var body: some View {
        PINInputView(
            pin: $pin,
            isFocused: $isFocused,
            title: "",  // Title handled by SheetContainer
            subtitle: subtitle,
            showConfirmButton: showConfirmButton,
            isLoading: isLoading,
            displayMode: displayMode,
            onComplete: onComplete,
            onCancel: onCancel,
            onForgotPIN: onForgotPIN
        )
        .padding()
        .alertHandler($alert)
    }
}

// MARK: - PIN Input View

public struct PINInputView: View {
    @Binding public var pin: String
    @FocusState.Binding public var isFocused: Bool

    public let title: String
    public let subtitle: String?
    public let showConfirmButton: Bool
    public let isLoading: Bool
    public let displayMode: PINDisplayMode
    public let onComplete: (String) -> Void
    public let onCancel: (() -> Void)?
    public let onForgotPIN: (() -> Void)?

    public init(
        pin: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        title: String = "Nhập mã PIN",
        subtitle: String? = nil,
        showConfirmButton: Bool = false,
        isLoading: Bool = false,
        displayMode: PINDisplayMode = .dots,
        onComplete: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil,
        onForgotPIN: (() -> Void)? = nil
    ) {
        self._pin = pin
        self._isFocused = isFocused
        self.title = title
        self.subtitle = subtitle
        self.showConfirmButton = showConfirmButton
        self.isLoading = isLoading
        self.displayMode = displayMode
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onForgotPIN = onForgotPIN
    }

    public var body: some View {
        VStack(spacing: Spacing.xl) {
            if !title.isEmpty {
                VStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.md)
                    }
                }
            }

            PINCodeInput(pin: $pin, isFocused: $isFocused, displayMode: displayMode)
                .onChange(of: pin) { _, newValue in
                    if newValue.count > 6 { pin = String(newValue.prefix(6)) }
                    if pin.count == 6, !isLoading { onComplete(pin) }
                }

            if isLoading {
                ProgressView().tint(AppColors.primary)
            }

            HStack(spacing: Spacing.md) {
                if let onCancel {
                    Button("Hủy", action: onCancel).buttonStyle(.bordered)
                }
                if showConfirmButton {
                    Button("Xác nhận") { onComplete(pin) }
                        .buttonStyle(.borderedProminent)
                        .disabled(pin.count != 6 || isLoading)
                }
            }

            if let onForgotPIN {
                Button(action: onForgotPIN) {
                    Text("Quên mã PIN?")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }
                .padding(.top, Spacing.sm)
            }
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - PIN Code Input

public struct PINCodeInput: View {
    @Binding public var pin: String
    @FocusState.Binding public var isFocused: Bool
    public let displayMode: PINDisplayMode

    private let digitCount = 6

    public init(
        pin: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        displayMode: PINDisplayMode = .dots
    ) {
        self._pin = pin
        self._isFocused = isFocused
        self.displayMode = displayMode
    }

    public var body: some View {
        ZStack {
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .frame(width: UILayout.hiddenCursorSize, height: UILayout.hiddenCursorSize)

            HStack(spacing: Spacing.sm) {
                ForEach(0..<digitCount, id: \.self) { index in
                    PINDigitBox(
                        digit: digitAt(index),
                        isFilled: index < pin.count,
                        isFocused: isFocused && index == pin.count,
                        displayMode: displayMode
                    )
                }
            }
            .contentShape(Rectangle())
            .overlay {
                Button { isFocused = true } label: { Color.clear }
                    .buttonStyle(.plain)
            }
        }
    }

    private func digitAt(_ index: Int) -> String? {
        guard index < pin.count else { return nil }
        return String(pin[pin.index(pin.startIndex, offsetBy: index)])
    }
}

// MARK: - Digit Box

private struct PINDigitBox: View {
    let digit: String?
    let isFilled: Bool
    let isFocused: Bool
    let displayMode: PINDisplayMode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isFocused ? AppColors.primary : AppColors.inputBorderDefault, lineWidth: 2)
                )
                .shadow(
                    color: isFocused ? AppColors.primary.opacity(0.3) : .clear,
                    radius: 8, x: 0, y: 4
                )

            if isFilled, let digit {
                switch displayMode {
                case .dots:
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: UILayout.iconSmall, height: UILayout.iconSmall)
                        .transition(.scale.combined(with: .opacity))
                case .numbers:
                    Text(digit)
                        .font(AppTypography.pinDigit)
                        .foregroundStyle(AppColors.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if isFocused, !isFilled {
                RoundedRectangle(cornerRadius: CornerRadius.hairline)
                    .fill(AppColors.primary)
                    .frame(width: UILayout.pinCursorWidth, height: UILayout.pinCursorHeight)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isFocused)
            }
        }
        .frame(width: UILayout.pinCellWidth, height: UILayout.pinCellHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFilled)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}
