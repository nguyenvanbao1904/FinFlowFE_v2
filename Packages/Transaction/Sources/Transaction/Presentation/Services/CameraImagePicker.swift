import SwiftUI
import UIKit

struct CameraImagePicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIImagePickerController

    private let onImagePicked: @MainActor (UIImage) -> Void
    private let onCancel: @MainActor () -> Void

    init(
        onImagePicked: @MainActor @escaping (UIImage) -> Void,
        onCancel: @MainActor @escaping () -> Void = {}
    ) {
        self.onImagePicked = onImagePicked
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }
}

extension CameraImagePicker {
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: @MainActor (UIImage) -> Void
        private let onCancel: @MainActor () -> Void

        init(
            onImagePicked: @MainActor @escaping (UIImage) -> Void,
            onCancel: @MainActor @escaping () -> Void
        ) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in
                onCancel()
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.originalImage] as? UIImage)
            Task { @MainActor in
                if let image {
                    onImagePicked(image)
                } else {
                    onCancel()
                }
            }
        }
    }
}
