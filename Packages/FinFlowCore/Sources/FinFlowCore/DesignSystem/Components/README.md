# 🎨 Component Library - Hướng Dẫn Mở Rộng

## 📁 Cấu Trúc Thư Mục

```
FinFlowCore/Sources/FinFlowCore/DesignSystem/
├── DesignSystem.swift          # ✅ Đã có (Tokens + Basic Components)
└── Components/                 # 🆕 Thư mục mới cho components mở rộng
    ├── README.md              # File này
    ├── Form/                  # Form components
    │   ├── SecondaryButton.swift
    │   ├── TextButton.swift
    │   ├── IconButton.swift
    │   ├── Checkbox.swift
    │   ├── RadioButton.swift
    │   ├── ToggleSwitch.swift
    │   ├── Dropdown.swift
    │   ├── DatePickerField.swift
    │   └── SearchBar.swift
    ├── DataDisplay/           # Data display components
    │   ├── Card.swift
    │   ├── Badge.swift
    │   ├── Chip.swift
    │   ├── Avatar.swift
    │   ├── EmptyState.swift
    │   └── ErrorState.swift
    ├── Feedback/              # Feedback components
    │   ├── Toast.swift
    │   ├── Alert.swift
    │   ├── LoadingOverlay.swift
    │   ├── ProgressBar.swift
    │   └── SkeletonView.swift
    ├── Navigation/            # Navigation components
    │   ├── CustomTabBar.swift
    │   ├── SegmentedControl.swift
    │   ├── CustomNavigationBar.swift
    │   └── BottomSheet.swift
    └── Layout/                # Layout components
        ├── HorizontalScroll.swift
        ├── GridLayout.swift
        └── StickyHeader.swift
```

---

## 🚀 Cách Sử Dụng

### 1️⃣ Khi Cần Component Mới

**Ví dụ: Cần Card component**

```bash
# Tạo file mới
touch Components/DataDisplay/Card.swift
```

### 2️⃣ Template Code cho Component

**File: `Components/DataDisplay/Card.swift`**

```swift
//
//  Card.swift
//  FinFlowCore
//
//  Component: Card (Data Display)
//

import SwiftUI

/**
 Card Component
 
 Elevated surface with shadow for grouping content
 Similar to Material-UI Card / React Bootstrap Card
 
 Usage:
 ```swift
 Card {
     VStack(alignment: .leading, spacing: 10) {
         Text("Title")
             .font(.headline)
         Text("Description")
             .font(.body)
     }
 }
 
 // With custom style
 Card(backgroundColor: .blue, cornerRadius: 20) {
     Text("Custom Card")
 }
 ```
 */
public struct Card<Content: View>: View {
    // MARK: - Properties
    
    private let content: Content
    public var backgroundColor: Color
    public var cornerRadius: CGFloat
    public var shadow: Bool
    public var padding: CGFloat
    
    // MARK: - Initialization
    
    public init(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = CornerRadius.medium,
        shadow: Bool = true,
        padding: CGFloat = Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.padding = padding
        self.content = content()
    }
    
    // MARK: - Body
    
    public var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadow ? .black.opacity(0.1) : .clear,
                radius: shadow ? 8 : 0,
                y: shadow ? 4 : 0
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Basic Card
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("User Profile")
                    .font(.headline)
                Text("John Doe")
                    .font(.body)
                Text("john@example.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        // Custom Card
        Card(backgroundColor: .blue.opacity(0.1), cornerRadius: 20) {
            Text("Custom Styled Card")
                .foregroundColor(.blue)
        }
    }
    .padding()
}
```

### 3️⃣ Export Component trong DesignSystem.swift

**Thêm vào cuối file `DesignSystem.swift`:**

```swift
// MARK: - Extended Components (Import from Components/)

@_exported import struct FinFlowCore.Card
@_exported import struct FinFlowCore.Badge
// ... các components khác
```

Hoặc đơn giản hơn, chỉ cần import trong file cần dùng:

```swift
import FinFlowCore

// Tự động có Card, Badge, etc.
```

---

## 📝 Checklist Khi Tạo Component Mới

```markdown
✅ 1. Tạo file trong thư mục phù hợp (Form/DataDisplay/Feedback/Navigation/Layout)
✅ 2. Viết documentation comment (/// với Usage example)
✅ 3. Sử dụng Design Tokens (AppColors, Spacing, CornerRadius)
✅ 4. Làm public cho struct và init
✅ 5. Thêm Preview (#Preview)
✅ 6. Test trên Dark Mode và Light Mode
✅ 7. Test với Dynamic Type (accessibility)
```

---

## 🎯 Priority List - Components Cần Thiết Nhất

### 🔴 High Priority (Làm trước)

1. **Card** - Group content (dùng nhiều nhất)
2. **Toast** - Temporary notifications
3. **LoadingOverlay** - Fullscreen loading
4. **EmptyState** - No data UI
5. **ErrorState** - Error UI

### 🟡 Medium Priority

6. **SecondaryButton** - Outline variant
7. **IconButton** - Icon-only button
8. **Badge** - Notification count
9. **SearchBar** - Search input
10. **ProgressBar** - Loading progress

### 🟢 Low Priority

11. **Chip** - Tags/Labels
12. **Avatar** - User profile image
13. **BottomSheet** - Modal drawer
14. **SegmentedControl** - Tabs
15. **CustomTabBar** - Bottom navigation

---

## 💡 Tips & Best Practices

### 1. Sử Dụng Design Tokens

```swift
// ✅ GOOD - Consistent with design system
Card(
    backgroundColor: AppColors.primary.opacity(0.1),
    cornerRadius: CornerRadius.medium,
    padding: Spacing.md
)

// ❌ BAD - Magic numbers
Card(
    backgroundColor: Color(red: 0.5, green: 0.5, blue: 0.5),
    cornerRadius: 16,
    padding: 20
)
```

### 2. Làm Components Flexible

```swift
// ✅ GOOD - Customizable
public struct Toast: View {
    public enum ToastType {
        case success, error, warning, info
    }
    
    public let message: String
    public let type: ToastType
    public let duration: TimeInterval
    
    // ...
}

// Usage: Flexible!
Toast(message: "Success!", type: .success)
Toast(message: "Error!", type: .error, duration: 5.0)
```

### 3. Test với Preview

```swift
#Preview {
    VStack {
        // Test various states
        Card { Text("Normal") }
        Card { Text("Dark Mode") }
            .environment(\.colorScheme, .dark)
        Card { Text("Large Text") }
            .environment(\.dynamicTypeSize, .xxxLarge)
    }
}
```

---

## 📚 Tài Liệu Tham Khảo

- **SwiftUI Components**: [Apple Developer](https://developer.apple.com/documentation/swiftui)
- **Material-UI**: [mui.com](https://mui.com) - Tham khảo API design
- **Ant Design**: [ant.design](https://ant.design) - Tham khảo component patterns
- **React Bootstrap**: [react-bootstrap.github.io](https://react-bootstrap.github.io)

---

## 🎨 Example: Tạo Toast Component

**Khi bạn cần:**

```
Bạn: "Tôi cần Toast notification component giống React"
AI: "Tôi sẽ tạo cho bạn!"
```

**AI sẽ tạo:**

1. File `Components/Feedback/Toast.swift`
2. Implement với:
   - Success/Error/Warning/Info types
   - Auto-dismiss sau X giây
   - Animation fade in/out
   - Positioned at top/bottom
3. Preview examples
4. Documentation

---

**Prepared by:** Code Review Report Implementation  
**Date:** 4 January 2026  
**Status:** ✅ Ready to Use

---

*Bây giờ cấu trúc đã sẵn sàng! Khi cần component gì, chỉ cần nói và AI sẽ tạo theo template này.*
