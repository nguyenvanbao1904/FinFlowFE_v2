//
//  LoadingOverlay.swift
//  FinFlowCore
//

import SwiftUI

/// Loading overlay modifier
/// Hiển thị full-screen loading với backdrop
public struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool

    public func body(content: Content) -> some View {
        ZStack {
            content

            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}

extension View {
    /// Thêm loading overlay vào view
    /// - Parameter isLoading: State loading
    /// - Returns: View với loading overlay
    public func loadingOverlay(_ isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
}
