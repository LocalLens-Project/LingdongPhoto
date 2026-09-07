import SwiftUI
import QuickLook


final class PostalArtworkPreviewItem: NSObject, Identifiable, QLPreviewItem {
    let id = UUID()
    let previewItemURL: URL?
    let previewItemTitle: String?
    private let directory: URL

    init(image: UIImage, title: String) throws {
        guard let data = image.pngData() else { throw PostalError.image }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PostalPreview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(title).png")
        do { try data.write(to: url, options: .atomic) }
        catch { try? FileManager.default.removeItem(at: directory); throw error }
        self.directory = directory
        previewItemURL = url
        previewItemTitle = title
        super.init()
    }

    func removeTemporaryFile() { try? FileManager.default.removeItem(at: directory) }
    deinit { try? FileManager.default.removeItem(at: directory) }
}


struct PostalArtworkPreview: UIViewControllerRepresentable {
    let item: PostalArtworkPreviewItem
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(item: item, close: { dismiss() }) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.delegate = context.coordinator
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.close))
        done.accessibilityIdentifier = "postal.closeLargePreview"
        preview.navigationItem.rightBarButtonItem = done
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    static func dismantleUIViewController(_ controller: UINavigationController, coordinator: Coordinator) {

        for preview in controller.viewControllers.compactMap({ $0 as? QLPreviewController }) {
            preview.dataSource = nil
            preview.delegate = nil
        }
        coordinator.item.removeTemporaryFile()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let item: PostalArtworkPreviewItem
        let onClose: () -> Void
        init(item: PostalArtworkPreviewItem, close: @escaping () -> Void) { self.item = item; onClose = close }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { item }
        func previewControllerDidDismiss(_ controller: QLPreviewController) { onClose() }
        @objc func close() { onClose() }
    }
}
