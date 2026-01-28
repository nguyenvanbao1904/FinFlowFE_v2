import SwiftUI

// 1. Định nghĩa khuôn mẫu cho mọi Alert trong App
public protocol AppAlert: Sendable {
    var title: String { get }
    var subtitle: String? { get }
    var buttons: AnyView { get }
}

// 2. Extension để sử dụng Alert một cách tập trung
public extension View {
    func showCustomAlert<T: AppAlert & Sendable>(alert: Binding<T?>) -> some View {
        self.alert(alert.wrappedValue?.title ?? "Error", isPresented: Binding(value: alert)) {
            alert.wrappedValue?.buttons
        } message: {
            if let subtitle = alert.wrappedValue?.subtitle {
                Text(subtitle)
            }
        }
    }
}

// 3. Extension bổ trợ cho Binding (Cực kỳ quan trọng)
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
