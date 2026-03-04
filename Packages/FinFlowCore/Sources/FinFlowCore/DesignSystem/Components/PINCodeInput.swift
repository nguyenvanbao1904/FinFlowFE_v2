//
//  PINCodeInput.swift
//  FinFlowCore
//

import SwiftUI

/// Reusable PIN Code Input Component với Glassmorphism Design
/// Hiển thị 6 ô nhập PIN hoặc OTP với animation và focus state
public struct PINCodeInput: View {
    /// Display mode for PIN input
    public enum DisplayMode {
        case dots      // Show dots for PIN (secure)
        case numbers   // Show actual numbers for OTP
    }
    
    @Binding public var pin: String
    @FocusState.Binding public var isFocused: Bool
    public let displayMode: DisplayMode

    private let digitCount = 6
    private let spacing: CGFloat = 12

    public init(
        pin: Binding<String>, 
        isFocused: FocusState<Bool>.Binding,
        displayMode: DisplayMode = .dots
    ) {
        self._pin = pin
        self._isFocused = isFocused
        self.displayMode = displayMode
    }

    public var body: some View {
        ZStack {
            // Hidden TextField để nhận input
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 1, height: 1)

            // 6 ô hiển thị — tap vào vùng này để focus và mở bàn phím
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
    let displayMode: PINCodeInput.DisplayMode

    var body: some View {
        ZStack {
            // Glassmorphism background
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isFocused ? AppColors.primary : Color.gray.opacity(0.3),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isFocused ? AppColors.primary.opacity(0.3) : .clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )

            // Hiển thị nội dung dựa trên display mode
            if isFilled, let digit = digit {
                switch displayMode {
                case .dots:
                    // Hiển thị chấm tròn cho PIN
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 16, height: 16)
                        .transition(.scale.combined(with: .opacity))
                case .numbers:
                    // Hiển thị số thực cho OTP
                    Text(digit)
                        .font(AppTypography.pinDigit)
                        .foregroundStyle(AppColors.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Animation cursor khi focus
            if isFocused && !isFilled {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 2, height: 24)
                    .opacity(isFocused ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isFocused
                    )
            }
        }
        .frame(width: 50, height: 60)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFilled)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}
