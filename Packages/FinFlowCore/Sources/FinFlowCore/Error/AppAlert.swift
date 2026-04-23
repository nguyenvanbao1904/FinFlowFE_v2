import SwiftUI

// 1. Định nghĩa khuôn mẫu cho mọi Alert trong App
public protocol AppAlert: Sendable {
    var title: String { get }
    var subtitle: String? { get }
}

// 2. Extension bổ trợ cho Binding
public extension Binding where Value == Bool {
    init<T: Sendable>(value: Binding<T?>) {
        self.init(
            get: { value.wrappedValue != nil },
            set: { newValue in
                if !newValue { value.wrappedValue = nil }
            }
        )
    }
}
