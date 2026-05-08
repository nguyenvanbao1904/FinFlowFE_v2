//
//  CameraImagePicker.swift
//  Transaction
//
//  Thay UIImagePickerController (deprecated iOS 14) bằng VNDocumentCameraViewController
//  (iOS 13+, VisionKit) — auto edge detect, perspective correction, stable camera session.
//  Interface giữ nguyên để AddTransactionView không đổi.
//

import SwiftUI
import VisionKit
import UIKit

struct CameraImagePicker: UIViewControllerRepresentable {

    private let onImagePicked: @MainActor (UIImage) -> Void
    private let onCancel: @MainActor () -> Void

    init(
        onImagePicked: @MainActor @escaping (UIImage) -> Void,
        onCancel: @MainActor @escaping () -> Void = {}
    ) {
        self.onImagePicked = onImagePicked
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }
}

// MARK: - Coordinator

extension CameraImagePicker {
    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void

        init(
            onImagePicked: @escaping (UIImage) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        // Scan hoàn thành — lấy ảnh trang đầu (hoá đơn thường 1 trang)
        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                Task { @MainActor in self.onCancel() }
                return
            }

            // Dùng trang đầu tiên (chất lượng cao, đã perspective-corrected)
            let image = scan.imageOfPage(at: 0)

            Task { @MainActor in self.onImagePicked(image) }
        }

        // Người dùng bấm Cancel
        nonisolated func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            Task { @MainActor in self.onCancel() }
        }

        // Camera lỗi (permission bị từ chối, camera không khả dụng, v.v.)
        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            Task { @MainActor in self.onCancel() }
        }
    }
}
