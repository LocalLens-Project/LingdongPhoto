// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation
import Photos
import PhotosUI
import SwiftUI

struct PhotoPickerSelection: Identifiable {
    let id = UUID()
    let itemProvider: NSItemProvider
}

/// Uses the out-of-process system picker and keeps the item provider returned
/// for each explicit user selection. No PhotoKit library read permission is
/// needed, including when the selected item is a Live Photo.
struct PrivacyPreservingPhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let selectionLimit: Int
    let onSelection: ([PhotoPickerSelection]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = max(1, selectionLimit)
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private var parent: PrivacyPreservingPhotoPicker

        init(parent: PrivacyPreservingPhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.onSelection(
                results.map { PhotoPickerSelection(itemProvider: $0.itemProvider) }
            )
            parent.isPresented = false
        }
    }
}
