//
//  SheetContainer.swift
//  FinFlowCore
//
//  Generic sheet container following Apple HIG
//  Replaces: PINInputSheet, PasswordConfirmationSheet, DateRangeFilterSheet headers
//

import SwiftUI

/// Generic sheet container with standardized header and presentation
/// Use this as the base for all sheet presentations in the app
public struct SheetContainer<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    
    // Configuration
    public let title: String
    public let showCloseButton: Bool
    public let detents: Set<PresentationDetent>
    public let dragIndicator: Visibility
    public let allowDismissal: Bool
    public let onDismiss: (() -> Void)?
    
    // Content
    @ViewBuilder public let content: () -> Content
    
    public init(
        title: String,
        showCloseButton: Bool = true,
        detents: Set<PresentationDetent> = [.medium],
        dragIndicator: Visibility = .visible,
        allowDismissal: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showCloseButton = showCloseButton
        self.detents = detents
        self.dragIndicator = dragIndicator
        self.allowDismissal = allowDismissal
        self.onDismiss = onDismiss
        self.content = content
    }
    
    public var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if showCloseButton {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Hủy") {
                                dismiss()
                            }
                            .foregroundStyle(AppColors.primary)
                        }
                    }
                }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(dragIndicator)
        .interactiveDismissDisabled(!allowDismissal)
        .onDisappear {
            onDismiss?()
        }
    }
}
