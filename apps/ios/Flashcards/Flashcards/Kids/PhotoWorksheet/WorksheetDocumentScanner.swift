import SwiftUI
import UIKit
import VisionKit

/// Systemowy skaner dokumentów Apple: sam wykrywa kartkę, prostuje ją i poprawia kontrast,
/// dzięki czemu tekst rozpoznaje się dużo lepiej niż ze zwykłego zdjęcia.
struct WorksheetDocumentScanner: UIViewControllerRepresentable {
    let onScan: @MainActor ([UIImage]) -> Void
    let onFailure: @MainActor (Error) -> Void
    let onCancel: @MainActor () -> Void

    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: self.onScan, onFailure: self.onFailure, onCancel: self.onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScan: @MainActor ([UIImage]) -> Void
        private let onFailure: @MainActor (Error) -> Void
        private let onCancel: @MainActor () -> Void

        init(
            onScan: @escaping @MainActor ([UIImage]) -> Void,
            onFailure: @escaping @MainActor (Error) -> Void,
            onCancel: @escaping @MainActor () -> Void
        ) {
            self.onScan = onScan
            self.onFailure = onFailure
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            Task { @MainActor in
                self.onScan(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            Task { @MainActor in
                self.onCancel()
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            Task { @MainActor in
                self.onFailure(error)
            }
        }
    }
}
