//
//  CategorySelectionSheet.swift
//  FinFlowCore
//
//  Reusable category selection sheet with icon and color display
//  Apple HIG: Bottom sheet with list selection pattern
//

import SwiftUI

/// Category-specific selection sheet with icon and color display
/// Used by Transaction and Budget modules for consistent category selection UX
public struct CategorySelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedCategory: CategoryResponse?
    let categories: [CategoryResponse]
    let title: String

    public init(
        isPresented: Binding<Bool>,
        selectedCategory: Binding<CategoryResponse?>,
        categories: [CategoryResponse],
        title: String = "Chọn danh mục"
    ) {
        self._isPresented = isPresented
        self._selectedCategory = selectedCategory
        self.categories = categories
        self.title = title
    }

    public var body: some View {
        SelectionSheet(
            isPresented: $isPresented,
            selectedItem: $selectedCategory,
            items: categories,
            title: title
        ) { category, isSelected in
            categoryRow(category, isSelected: isSelected)
        }
    }

    // MARK: - Category Row View

    @ViewBuilder
    private func categoryRow(_ category: CategoryResponse, isSelected: Bool) -> some View {
        let categoryColor = Color(hex: category.color)

        HStack(spacing: Spacing.md) {
            // Category Icon with colored background circle
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(OpacityLevel.ultraLight))
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)

                Image(systemName: category.icon ?? "tag")
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(categoryColor)
            }

            // Category Name
            Text(category.name)
                .font(AppTypography.body)
                .foregroundStyle(.primary)

            Spacer()

            // Checkmark for selected item
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(AppColors.primary)
            }
        }
    }
}
