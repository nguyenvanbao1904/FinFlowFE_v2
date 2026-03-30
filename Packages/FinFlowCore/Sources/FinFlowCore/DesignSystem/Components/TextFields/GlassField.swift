//
//  GlassField.swift
//  FinFlowCore
//
//  Glassmorphism-styled text/secure field with icon and focus state
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
    public typealias KeyboardType = UIKeyboardType
#else
    // Fallback for non-iOS platforms (though this package targets iOS 17+ only)
    public enum KeyboardType {
        case `default`
    }
#endif

/// Modern glassmorphism-styled input field with icon & focus state
/// Supports both text and secure input modes
public struct GlassField: View {
    // MARK: - Properties

    public let icon: String
    public let showsIcon: Bool
    public let placeholder: String
    @Binding public var text: String
    public let isSecure: Bool
    public var keyboardType: KeyboardType
    public var onFocusChange: ((Bool) -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isSecureVisible: Bool = false

    // MARK: - Initialization

    public init(
        text: Binding<String>,
        placeholder: String,
        icon: String,
        showsIcon: Bool = true,
        isSecure: Bool = false,
        keyboardType: KeyboardType = .default,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.showsIcon = showsIcon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.onFocusChange = onFocusChange
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if showsIcon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: UILayout.iconSize)
            }

            // Input field (secure or text)
            inputField

            // Eye toggle button (only for secure fields)
            if isSecure {
                eyeToggleButton
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.sm)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isFocused ? AppColors.primary.opacity(0.6) : AppColors.primary.opacity(0.2),
                    lineWidth: isFocused ? 1 : 0.5
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var inputField: some View {
        if isSecure && !isSecureVisible {
            SecureField(placeholder, text: $text)
                .textContentType(.password)
                .focused($isFocused)
                .onChange(of: isFocused) { _, newValue in
                    onFocusChange?(newValue)
                }
        } else {
            TextField(placeholder, text: $text)
                #if os(iOS)
                    .textInputAutocapitalization(isSecure ? .never : .sentences)
                    .autocorrectionDisabled(isSecure)
                    .keyboardType(keyboardType)
                #endif
                .textContentType(isSecure ? .password : nil)
                .focused($isFocused)
                .onChange(of: isFocused) { _, newValue in
                    onFocusChange?(newValue)
                }
        }
    }

    private var eyeToggleButton: some View {
        Button {
            isSecureVisible.toggle()
        } label: {
            Image(systemName: isSecureVisible ? "eye" : "eye.slash")
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}
