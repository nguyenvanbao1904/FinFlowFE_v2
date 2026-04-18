import SwiftUI

// MARK: - Alert Handler Extension
/// Centralized alert handling extension for SwiftUI Views
/// Provides consistent logging, haptics, and analytics for all alerts
extension View {

    /// Standard alert handler with automatic logging and haptic feedback
    /// Uses modern SwiftUI alert API (title + actions + message)
    /// - Parameters:
    ///   - alert: Binding to optional AppErrorAlert
    ///   - onDismiss: Optional callback when alert is dismissed
    /// - Returns: View with alert modifier applied
    public func alertHandler(
        _ alert: Binding<AppErrorAlert?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(value: alert),
            presenting: alert.wrappedValue
        ) { alertItem in
            buildActions(from: alertItem, onDismiss: onDismiss)
        } message: { alertItem in
            if let subtitle = alertItem.subtitle {
                Text(subtitle)
            }
        }
        .onChange(of: alert.wrappedValue != nil) { _, isPresented in
            if isPresented, let alertItem = alert.wrappedValue {
                handleAlertPresentation(alertItem)
            }
        }
    }

    // MARK: - Private Helpers

    /// Handles side effects when alert is presented
    private func handleAlertPresentation(_ alert: AppErrorAlert) {
        // 1. Logging
        logAlert(alert)

        // 2. Haptic Feedback
        triggerHapticFeedback(for: alert)
    }

    /// Logs alert information with type-appropriate emoji
    private func logAlert(_ alert: AppErrorAlert) {
        let emoji: String
        switch alert.alertType {
        case .error:
            emoji = "❌"
        case .success:
            emoji = "✅"
        case .warning:
            emoji = "⚠️"
        case .info:
            emoji = "ℹ️"
        }

        Logger.info("\(emoji) Alert: \(alert.title) - \(alert.message)", category: "UI")
    }

    /// Triggers appropriate haptic feedback based on alert type
    private func triggerHapticFeedback(for alert: AppErrorAlert) {
        let generator = UINotificationFeedbackGenerator()

        switch alert.alertType {
        case .error:
            generator.notificationOccurred(.error)
        case .success:
            generator.notificationOccurred(.success)
        case .warning, .info:
            generator.notificationOccurred(.warning)
        }
    }

    /// Builds modern alert actions from AppErrorAlert
    @ViewBuilder
    private func buildActions(
        from alert: AppErrorAlert,
        onDismiss: (() -> Void)?
    ) -> some View {
        switch alert {
        case .network(let onRetry):
            Button("Thử lại", action: onRetry)
            Button("Hủy", role: .cancel) { onDismiss?() }

        case .authWithAction(_, let onOK):
            Button("OK", role: .cancel) {
                onOK()
                onDismiss?()
            }

        case .success(_, let onOK):
            Button("OK", role: .cancel) {
                onOK()
                onDismiss?()
            }

        default:
            Button("OK", role: .cancel) {
                onDismiss?()
            }
        }
    }
}
