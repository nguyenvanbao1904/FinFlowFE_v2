//
//  BiometricAuthHandler.swift
//  Identity
//

import FinFlowCore
import Foundation

// 1. Tách cấu hình ra thành một Public Struct độc lập
public struct BiometricAuthOptions: Sendable {
    public let reason: String
    public let unauthorizedMessage: String
    public let missingEnableMessage: String
    public let missingAccountMessage: String

    public init(
        reason: String, unauthorizedMessage: String, missingEnableMessage: String,
        missingAccountMessage: String
    ) {
        self.reason = reason
        self.unauthorizedMessage = unauthorizedMessage
        self.missingEnableMessage = missingEnableMessage
        self.missingAccountMessage = missingAccountMessage
    }
}

public protocol SessionBiometricAuthHandling: Sendable {
    func authenticate(
        sessionManager: any SessionManagerProtocol,
        userDefaults: any UserDefaultsManagerProtocol,
        options: BiometricAuthOptions  // ✅ Đã dùng kiểu Public
    ) async -> AppErrorAlert?
}

/// Dùng chung cho luồng đăng nhập sinh trắc học (Login / WelcomeBack).
@MainActor
public final class SessionBiometricAuthCoordinator: SessionBiometricAuthHandling {
    private let verifier: any BiometricVerifying

    // Preset thông điệp dùng chung để đồng nhất giữa các màn
    public enum Preset {
        public static let login = BiometricAuthOptions(
            reason: "Xác thực bằng Face ID/Touch ID để đăng nhập",
            unauthorizedMessage:
                "Phiên đăng nhập đã hết hạn hoặc refresh token không còn hiệu lực. Vui lòng đăng nhập lại.",
            missingEnableMessage:
                "Vui lòng bật xác thực sinh trắc học trong Cài đặt bảo mật để sử dụng tính năng này.",
            missingAccountMessage:
                "Vui lòng đăng nhập bằng tài khoản & mật khẩu để tiếp tục dùng sinh trắc."
        )

        public static let welcomeBack = BiometricAuthOptions(
            reason: "Xác thực bằng Face ID/Touch ID để tiếp tục",
            unauthorizedMessage:
                "Phiên đăng nhập đã hết hạn hoặc không còn hiệu lực. Vui lòng đăng nhập lại để sử dụng tính năng này.",
            missingEnableMessage:
                "Vui lòng bật xác thực sinh trắc học trong Cài đặt bảo mật để sử dụng tính năng này.",
            missingAccountMessage:
                "Vui lòng đăng nhập bằng tài khoản & mật khẩu để tiếp tục dùng sinh trắc."
        )
    }

    // ✅ Thêm public init để DI Container có thể khởi tạo được
    public init(verifier: any BiometricVerifying = FinFlowCore.BiometricAuthHandler()) {
        self.verifier = verifier
    }

    /// Thực hiện xác thực sinh trắc học và refresh token.
    /// - Returns: AppErrorAlert nếu cần hiển thị; nil nếu thành công.
    public func authenticate(
        sessionManager: any SessionManagerProtocol,
        userDefaults: any UserDefaultsManagerProtocol,
        options: BiometricAuthOptions
    ) async -> AppErrorAlert? {
        // 1) Kiểm tra thiết bị hỗ trợ
        guard verifier.isBiometricAvailable() else {
            return .general(
                title: "Thiết bị không hỗ trợ",
                message: "Thiết bị của bạn không hỗ trợ Face ID / Touch ID.")
        }

        // 2) Kiểm tra bật sinh trắc trong cài đặt
        let isBiometricEnabled = await userDefaults.getIsBiometricEnabled()
        guard isBiometricEnabled else {
            return .general(
                title: "Chưa kích hoạt",
                message: options.missingEnableMessage
            )
        }

        // 3) Kiểm tra thông tin tài khoản đã lưu
        let hasEmail = await userDefaults.getEmail() != nil
        let hasRefreshToken = await hasStoredRefreshToken(sessionManager.tokenStore)
        guard hasEmail, hasRefreshToken else {
            return .general(
                title: "Cần đăng nhập lại",
                message: options.missingAccountMessage
            )
        }

        // 4) Thực hiện Face ID / Touch ID
        // ✅ Fix: Set flag to prevent Privacy Blur glitch
        sessionManager.isBiometricAuthenticationInProgress = true
        defer {
            sessionManager.isBiometricAuthenticationInProgress = false
        }

        let success = await verifier.verifyBiometric(reason: options.reason)

        guard success else {
            return nil  // Người dùng hủy / thất bại, iOS sẽ tự retry
        }

        // 5) Refresh token (silent) để không đổi state trước khi hiển thị alert
        do {
            let newToken = try await sessionManager.refreshSessionSilently()
            // ✅ SUCCESS: Chuyển state sang authenticated để AppRouter điều hướng vào Dashboard
            await sessionManager.finalizeAuthentication(token: newToken)
            return nil
        } catch {
            return handleAuthError(error, options: options, sessionManager: sessionManager)
        }
    }

    // MARK: - Helpers

    private func hasStoredRefreshToken(_ tokenStore: any TokenStoreProtocol) async -> Bool {
        // ✅ Đã sửa vi phạm DIP: Gọi thẳng hàm của protocol, không ép kiểu (cast) về class cụ thể nữa.
        guard let token = await tokenStore.getRefreshToken() else { return false }
        return !token.isEmpty
    }

    private func handleAuthError(
        _ error: any Error,
        options: BiometricAuthOptions,
        sessionManager: any SessionManagerProtocol
    ) -> AppErrorAlert {
        if let appError = error as? AppError, case .unauthorized = appError {
            Logger.warning("Biometric refresh unauthorized - showing alert", category: "Auth")
            // Hiển thị alert, chỉ khi user bấm OK mới chuyển về login
            return .authWithAction(
                message: options.unauthorizedMessage
            ) { [weak sessionManager] in
                Task { @MainActor in
                    // ✅ Fix: Clear expired tokens so we go to Login, not WelcomeBack
                    await sessionManager?.clearExpiredSession()
                }
            }
        }

        if let appError = error as? AppError {
            return .auth(message: appError.localizedDescription)
        }

        return .general(
            title: "Lỗi",
            message: "Đăng nhập thất bại. Vui lòng thử lại.")
    }
}
