// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PhotoPickerSelection: Identifiable {
    let id = UUID()
    let itemProvider: NSItemProvider?
    let sharedItem: SharedPhotoHandoff.Item?

    init(itemProvider: NSItemProvider) {
        self.itemProvider = itemProvider
        sharedItem = nil
    }

    init(sharedItem: SharedPhotoHandoff.Item) {
        itemProvider = nil
        self.sharedItem = sharedItem
    }
}

nonisolated enum LivePhotoImportCapabilities {
    static let bundleIdentifier = "com.apple.live-photo-bundle"

    static var hasObjectReader: Bool {
        PHLivePhoto.responds(to: NSSelectorFromString("readableTypeIdentifiersForItemProvider"))
    }

    static func canReadObject(from provider: NSItemProvider) -> Bool {
        hasObjectReader && provider.canLoadObject(ofClass: PHLivePhoto.self)
    }

    static func isLivePhoto(_ provider: NSItemProvider) -> Bool {
        canReadObject(from: provider)
            || provider.hasItemConformingToTypeIdentifier(bundleIdentifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.livePhoto.identifier)
    }
}

/// Uses the out-of-process system picker and keeps the item provider returned
/// for each explicit user selection. No PhotoKit library read permission is
/// needed, including when the selected item is a Live Photo.
struct PrivacyPreservingPhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let selectionLimit: Int
    let colorScheme: ColorScheme
    var assetRepresentationMode: PHPickerConfiguration.AssetRepresentationMode = .current
    var usesOrderedSelection = false
    var deliversSelectionBeforeDismissal = false
    let onSelection: ([PhotoPickerSelection]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = max(1, selectionLimit)
        configuration.preferredAssetRepresentationMode = assetRepresentationMode
        if usesOrderedSelection {
            configuration.selection = .ordered
        }

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        picker.overrideUserInterfaceStyle = colorScheme.userInterfaceStyle
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.update(parent: self)
        uiViewController.overrideUserInterfaceStyle = colorScheme.userInterfaceStyle
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private var parent: PrivacyPreservingPhotoPicker
        private var didFinishPicking = false

        init(parent: PrivacyPreservingPhotoPicker) {
            self.parent = parent
        }

        func update(parent: PrivacyPreservingPhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !didFinishPicking else { return }
            didFinishPicking = true
            let selections = results.map {
                PhotoPickerSelection(itemProvider: $0.itemProvider)
            }
            let onSelection = parent.onSelection
            if parent.deliversSelectionBeforeDismissal {
                onSelection(selections)
                parent.isPresented = false
                return
            }
            parent.isPresented = false
            DispatchQueue.main.async {
                onSelection(selections)
            }
        }
    }
}

private extension ColorScheme {
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .dark: .dark
        default: .light
        }
    }
}
