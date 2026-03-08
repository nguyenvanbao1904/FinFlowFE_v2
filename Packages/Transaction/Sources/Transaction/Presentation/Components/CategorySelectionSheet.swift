//
//  CategorySelectionSheet.swift
//  Transaction
//
//  Category selection sheet - wrapper around generic SelectionSheet
//

import FinFlowCore
import SwiftUI

/// Category-specific selection sheet with icon and color display
public struct CategorySelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedCategory: CategoryResponse?
    let categories: [CategoryResponse]

    public init(
        isPresented: Binding<Bool>,
        selectedCategory: Binding<CategoryResponse?>,
        categories: [CategoryResponse]
    ) {
        self._isPresented = isPresented
        self._selectedCategory = selectedCategory
        self.categories = categories
    }

    public var body: some View {
        SelectionSheet(
            isPresented: $isPresented,
            selectedItem: $selectedCategory,
            items: categories,
            title: "Chọn danh mục"
        ) { category, isSelected in
            categoryRow(category, isSelected: isSelected)
        }
    }

    // MARK: - Category Row View

    @ViewBuilder
    private func categoryRow(_ category: CategoryResponse, isSelected: Bool) -> some View {
        HStack {
            // Category Icon with background circle
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(OpacityLevel.ultraLight))
                    .frame(
                        width: Spacing.iconMedium + Spacing.xs,
                        height: Spacing.iconMedium + Spacing.xs
                    )

                Image(systemName: category.icon)
                    .foregroundColor(AppColors.accent)
                    .font(AppTypography.caption)
            }

            // Category Name
            Text(category.name)
                .font(AppTypography.body)
                .foregroundColor(.primary)

            Spacer()

            // Checkmark for selected item
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(AppColors.primary)
            }
        }
    }
}
