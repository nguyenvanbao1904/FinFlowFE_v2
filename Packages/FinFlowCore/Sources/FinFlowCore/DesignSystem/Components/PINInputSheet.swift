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

// PINCodeInput and PINDigitBox are split into dedicated files.
