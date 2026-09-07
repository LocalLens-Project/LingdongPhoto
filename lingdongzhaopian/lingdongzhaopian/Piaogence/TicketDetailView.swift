import Photos
import SwiftUI
import UIKit

struct TicketDetailView: View {
    let ticket: TicketStub
    var namespace: Namespace.ID
    var onClose: () -> Void
    var onDelete: (TicketStub) -> Void
    var onUpdate: ((TicketStub) -> Void)? = nil

    @State private var flipped = false
    @State private var panelAppeared = false
    @State private var toastText: String?
    @State private var shareImage: UIImage?
    @State private var sharePresented = false
    @State private var showsOriginalArchive = false
    @State private var editionStudioPresented = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

                .contentShape(Rectangle())
                .onTapGesture { }

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 10)

                flipArea

                if ticket.isPhysicalImport {
                    physicalPreviewToggle
                        .padding(.top, 14)

                } else if supportsVerificationBack {
                    Text(flipHintText)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 14)
                }

                Spacer(minLength: 10)

                infoPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12)) {
                panelAppeared = true
            }
        }
        .overlay(alignment: .top) { toast }
        .sheet(isPresented: $sharePresented, onDismiss: { shareImage = nil }) {
            if let shareImage {
                PiaogenceShareSheet(items: [shareImage])
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(isPresented: $editionStudioPresented) {
            TicketEditionStudio(
                ticket: ticket,
                currentEdition: ticket.ticketEdition
            ) { edition in
                var updated = ticket
                updated.ticketEdition = edition
                onUpdate?(updated)
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 12))
                Text("票根详情")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.14)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.14)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            }
            .buttonStyle(TicketPressStyle(scale: 0.85, tilt: 0))
        }
        .opacity(panelAppeared ? 1 : 0)
        .offset(y: panelAppeared ? 0 : -14)
    }

    private var flipArea: some View {
        Group {
            if ticket.isArchivedWork {

                TicketArtworkView(ticket: ticket)
            } else if ticket.isPhysicalImport && showsOriginalArchive {
                physicalOriginalArtwork
            } else {
                flipContent
            }
        }
        .matchedGeometryEffect(id: ticket.id, in: namespace)
        .frame(maxWidth: ticket.layout == .vertical ? 320 : 560)
        .compositingGroup()
        .shadow(color: .black.opacity(0.32), radius: 28, y: 16)
        .padding(.horizontal, 16)
    }

    private var flipContent: some View {
        Group {
            if supportsVerificationBack {
                flippableTicket
            } else {
                TicketArtworkView(ticket: ticket)
            }
        }
    }

    private var flippableTicket: some View {
        ZStack {
            TicketArtworkView(ticket: ticket)
                .rotation3DEffect(.degrees(flipped ? 180 : 0),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(flipped ? 0 : 1)

            TicketBackView(ticket: ticket)
                .rotation3DEffect(.degrees(flipped ? 0 : -180),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(flipped ? 1 : 0)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.74)) {
                flipped.toggle()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: flipped)
    }

    private var supportsVerificationBack: Bool {
        if ticket.isArchivedWork { return false }
        if let codeStyle = ticket.codeStyle {
            return codeStyle == .verificationQR
        }

        return ticket.layout == .vertical
    }

    private var physicalOriginalArtwork: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.10)
            if let data = ticket.artworkImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                ContentUnavailableView("原票档案不完整", systemImage: "ticket")
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .aspectRatio(ticket.layout.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Label("仅本机私藏", systemImage: "lock.fill")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.62), in: Capsule())
                .padding(11)
        }
    }

    private var physicalPreviewToggle: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                physicalPreviewButton("记忆重制", symbol: "sparkles.rectangle.stack", selected: !showsOriginalArchive) {
                    showsOriginalArchive = false
                    flipped = false
                }
                physicalPreviewButton("原票档案", symbol: "lock.doc", selected: showsOriginalArchive) {
                    showsOriginalArchive = true
                    flipped = false
                }
            }
            .padding(4)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.6))

            TicketEditionEntryButton(edition: ticket.ticketEdition) {
                editionStudioPresented = true
            }
            .environment(\.colorScheme, .dark)
        }
    }

    private func physicalPreviewButton(_ title: String, symbol: String, selected: Bool,
                                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title.appLocalized, systemImage: symbol)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(selected ? 0.96 : 0.62))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? .white.opacity(0.16) : .clear, in: Capsule())
        }
        .buttonStyle(TicketPressStyle(scale: 0.95, tilt: 0))
    }

    private var flipHintText: String {
        (flipped ? "轻点票根查看正面" : "点击翻页查看大二维码").appLocalized
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(ticket.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                TicketStatusBadges(ticket: ticket)
            }

            Text(ticket.message.appLocalized)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack {
                HStack(spacing: 5) {
                    ForEach(Array(ticket.palette.prefix(6).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color.color)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(.black.opacity(0.08)))
                    }
                }
                Spacer()
                Text(ticket.ticketID)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                actionButton(icon: "square.and.arrow.up", title: "分享".appLocalized, tint: .primary) {
                    guard let image = makeExportImage() else {
                        showToast("导出失败，请稍后再试".appLocalized)
                        return
                    }
                    shareImage = image
                    sharePresented = true
                }
                actionButton(icon: "photo.badge.arrow.down", title: "保存".appLocalized, tint: .primary) {
                    saveTicketToAlbum()
                }
                actionButton(icon: "trash", title: "删除".appLocalized, tint: .red) {
                    onDelete(ticket)
                }
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        }
        .opacity(panelAppeared ? 1 : 0)
        .offset(y: panelAppeared ? 0 : 46)
    }

    private func actionButton(icon: String, title: String, tint: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint == .red ? Color.red.opacity(0.09) : Color.black.opacity(0.045)))
        }
        .buttonStyle(TicketPressStyle(scale: 0.92, tilt: 0))
    }

    @MainActor
    private func makeExportImage() -> UIImage? {
        if ticket.isArchivedWork,
           let data = ticket.artworkImageData,
           let image = UIImage(data: data) {
            return image
        }
        let width: CGFloat = ticket.layout == .classic ? 560 : 360
        let height = width / ticket.layout.aspectRatio
        let renderer = ImageRenderer(
            content: TicketArtworkView(ticket: ticket)
                .frame(width: width, height: height)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        return renderer.uiImage
    }

    private func saveTicketToAlbum() {
        guard let image = makeExportImage() else {
            showToast("导出失败，请稍后再试".appLocalized)
            return
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performAlbumSave(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { granted in
                DispatchQueue.main.async {
                    if granted == .authorized || granted == .limited {
                        performAlbumSave(image)
                    } else {
                        showToast("需要在设置里允许添加照片".appLocalized)
                    }
                }
            }
        default:
            showToast("需要在设置里允许添加照片".appLocalized)
        }
    }

    private func performAlbumSave(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, _ in
            DispatchQueue.main.async {
                showToast((success ? "已保存到相册" : "保存失败，请稍后再试").appLocalized)
            }
        }
    }

    private var toast: some View {
        Group {
            if let text = toastText {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(.black.opacity(0.72)))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastText)
    }

    private func showToast(_ text: String) {
        toastText = text
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            toastText = nil
        }
    }
}

private struct PiaogenceShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TicketBackView: View {
    let ticket: TicketStub

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [.white, Color(red: 0.97, green: 0.96, blue: 0.94)],
                               startPoint: .top, endPoint: .bottom)

                if let qr = qrImage {
                    Image(uiImage: qr)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: min(geo.size.width, geo.size.height) * 0.80,
                               height: min(geo.size.width, geo.size.height) * 0.80)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .mask { PiaogenceTicketMask(layout: ticket.layout) }
        }
        .aspectRatio(ticket.layout.aspectRatio, contentMode: .fit)
    }

    private var qrImage: UIImage? {

        let text = ticket.qrPayload
            ?? "lingdong://ticket/\(ticket.ticketID)?fp=\(ticket.fingerprint)"
        return PiaogenceCodeRenderer.qrImage(
            text: text,
            foreground: UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1))
    }
}

#Preview("票根详情") {
    ZStack {
        Color(red: 0.94, green: 0.93, blue: 0.91).ignoresSafeArea()
        if let first = TicketStore.shared.cityTickets.first {
            TicketDetailView(
                ticket: first,
                namespace: Namespace().wrappedValue,
                onClose: {},
                onDelete: { _ in })
        }
    }
}
