//
//  PINInputSheet.swift
//  FinFlowCore
//
//  CONSOLIDATED: Includes PINCodeInput component inline
//  Single file for all PIN input UI components
//

import SwiftUI

// MARK: - Display Mode

public enum PINDisplayMode {
    case dots  // Show dots for PIN (secure)
    case numbers  // Show actual numbers for OTP
}

// MARK: - View Extension

extension View {
    /// Present PIN input in a standardized sheet
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
                PINInputContent(
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

// MARK: - Content

private struct PINInputContent: View {
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

// MARK: - PINCodeInput (Inline Component)

/// Reusable PIN Code Input Component with Glassmorphism Design
/// Displays 6 input boxes for PIN or OTP with animation and focus state
public struct PINCodeInput: View {
    @Binding public var pin: String
    @FocusState.Binding public var isFocused: Bool
    public let displayMode: PINDisplayMode

    private let digitCount = 6
    private let spacing: CGFloat = 12

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
            // Hidden TextField to capture input
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .frame(width: UILayout.hiddenCursorSize, height: UILayout.hiddenCursorSize)

            // 6 display boxes - tap to focus and open keyboard
            HStack(spacing: spacing) {
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
            .onTapGesture {
                isFocused = true
            }
        }
    }

    private func digitAt(_ index: Int) -> String? {
        guard index < pin.count else { return nil }
        let digitIndex = pin.index(pin.startIndex, offsetBy: index)
        return String(pin[digitIndex])
    }
}

// MARK: - Single PIN Digit Box

private struct PINDigitBox: View {
    let digit: String?
    let isFilled: Bool
    let isFocused: Bool
    let displayMode: PINDisplayMode

    var body: some View {
        ZStack {
            // Glassmorphism background
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isFocused ? AppColors.primary : AppColors.inputBorderDefault,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isFocused ? AppColors.primary.opacity(0.3) : .clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )

            // Display content based on display mode
            if isFilled, let digit = digit {
                switch displayMode {
                case .dots:
                    // Show dot for PIN
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: UILayout.iconSmall, height: UILayout.iconSmall)
                        .transition(.scale.combined(with: .opacity))
                case .numbers:
                    // Show actual number for OTP
                    Text(digit)
                        .font(AppTypography.pinDigit)
                        .foregroundStyle(AppColors.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Animated cursor when focused
            if isFocused && !isFilled {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: UILayout.pinCursorWidth, height: UILayout.pinCursorHeight)
                    .opacity(isFocused ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isFocused
                    )
            }
        }
        .frame(width: UILayout.pinCellWidth, height: UILayout.pinCellHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFilled)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}
