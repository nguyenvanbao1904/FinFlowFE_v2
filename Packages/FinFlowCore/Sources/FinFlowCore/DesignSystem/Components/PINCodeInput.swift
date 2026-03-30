import SwiftUI

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
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .frame(width: UILayout.hiddenCursorSize, height: UILayout.hiddenCursorSize)

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
            .overlay {
                Button {
                    isFocused = true
                } label: {
                    Color.clear
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func digitAt(_ index: Int) -> String? {
        guard index < pin.count else { return nil }
        let digitIndex = pin.index(pin.startIndex, offsetBy: index)
        return String(pin[digitIndex])
    }
}
