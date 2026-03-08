//
//  SelectionSheet.swift
//  FinFlowCore
//
//  REFACTORED: Now uses SheetContainer primitive for consistent styling
//  Generic selection sheet for picking items from a list
//

import SwiftUI

/// Generic single-selection sheet with search and custom item views
/// Reusable for: Categories, Tags, Accounts, Budgets, Currencies, etc.
public struct SelectionSheet<Item: Identifiable & Equatable>: View {
    // Bindings
    @Binding public var isPresented: Bool
    @Binding public var selectedItem: Item?

    // Data
    public let items: [Item]
    public let title: String

    // View builder for item rows
    public let itemContent: (Item, Bool) -> AnyView

    public init(
        isPresented: Binding<Bool>,
        selectedItem: Binding<Item?>,
        items: [Item],
        title: String,
        @ViewBuilder itemContent: @escaping (Item, Bool) -> some View
    ) {
        self._isPresented = isPresented
        self._selectedItem = selectedItem
        self.items = items
        self.title = title
        self.itemContent = { item, isSelected in
            AnyView(itemContent(item, isSelected))
        }
    }

    public var body: some View {
        SheetContainer(
            title: title,
            detents: [.medium, .large],
            allowDismissal: true,
            onDismiss: { isPresented = false },
            content: {
                List {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                            isPresented = false
                        } label: {
                            itemContent(item, selectedItem?.id == item.id)
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Convenience Init with Default Item View

extension SelectionSheet where Item: CustomStringConvertible {
    /// Convenience initializer with default text-only item view
    public init(
        isPresented: Binding<Bool>,
        selectedItem: Binding<Item?>,
        items: [Item],
        title: String
    ) {
        self.init(
            isPresented: isPresented,
            selectedItem: selectedItem,
            items: items,
            title: title
        ) { item, isSelected in
            HStack {
                Text(item.description)
                    .font(AppTypography.body)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}
