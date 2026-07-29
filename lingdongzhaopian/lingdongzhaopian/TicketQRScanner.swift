// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import AVFoundation
import SwiftUI
import Vision
import VisionKit

struct TicketQRScannerScreen: View {
    private enum ScannerState: Equatable {
        case preparing
        case ready
        case denied
        case unavailable
    }

    @Environment(\.openURL) private var openURL

    let onCancel: () -> Void

    @State private var state: ScannerState = .preparing
    @State private var feedback: String?
    @State private var isProcessing = false
    @State private var verifiedPayload: TicketPayload?

    var body: some View {
        Group {
            if let verifiedPayload {
                TicketVerificationView(
                    payload: verifiedPayload,
                    onClose: onCancel
                )
                .transition(.opacity)
            } else {
                scannerContent
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.24), value: verifiedPayload?.id)
        .task(prepareScanner)
    }

    private var scannerContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if state == .ready {
                TicketDataScannerView(onRecognized: handleRecognizedValue)
                    .ignoresSafeArea()

                scannerOverlay
            } else {
                unavailableContent
            }
        }
    }

    private var scannerOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("扫描验证票根")
                        .font(.title3.bold())
                    Text("二维码仅在本机解析")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                .accessibilityLabel("关闭扫码")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    feedback == nil
                        ? Color.white.opacity(0.92)
                        : Color.orange,
                    style: StrokeStyle(lineWidth: 3, dash: [18, 9])
                )
                .frame(width: 278, height: 278)
                .shadow(color: .black.opacity(0.34), radius: 18)
                .overlay {
                    Image(systemName: "qrcode")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(.white.opacity(0.16))
                }
                .accessibilityHidden(true)

            Spacer()

            VStack(spacing: 8) {
                if let feedback {
                    Label(feedback, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Label("将票根二维码置于取景框内", systemImage: "viewfinder")
                }

                Text("不会拍照、保存画面或读取系统相册")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.20), value: feedback)
        }
        .foregroundStyle(.white)
    }

    private var unavailableContent: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: state == .denied
                ? "camera.fill.badge.ellipsis"
                : "qrcode.viewfinder")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text(unavailableTitle)
                    .font(.title2.bold())

                Text(unavailableMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 310)
            }

            if state == .denied {
                Button("前往系统设置") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }

            Spacer()

            Button("返回模式选择", action: onCancel)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .padding(.bottom, 26)
        }
        .padding(24)
        .foregroundStyle(.white)
    }

    private var unavailableTitle: String {
        switch state {
        case .preparing: "正在准备相机"
        case .ready: ""
        case .denied: "没有相机权限"
        case .unavailable: "当前设备无法使用扫码"
        }
    }

    private var unavailableMessage: String {
        switch state {
        case .preparing:
            "首次使用时，系统会询问是否允许访问相机。"
        case .ready:
            ""
        case .denied:
            "请允许“灵动照片”访问相机后再扫描票根二维码。"
        case .unavailable:
            "请确认相机没有被其他应用占用，并在支持相机的 iPhone 上重试。"
        }
    }

    @MainActor
    private func prepareScanner() async {
        guard DataScannerViewController.isSupported else {
            state = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state = DataScannerViewController.isAvailable ? .ready : .unavailable
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            state = granted && DataScannerViewController.isAvailable
                ? .ready
                : (granted ? .unavailable : .denied)
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .unavailable
        }
    }

    @MainActor
    private func handleRecognizedValue(_ value: String) {
        guard !isProcessing else { return }
        isProcessing = true

        do {
            guard let url = URL(string: value) else {
                throw TicketEnvelopeError.invalidURL
            }
            let payload = try TicketEnvelope.decode(from: url)
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
            verifiedPayload = payload
        } catch {
            feedback = "这不是可验证的灵动照片票根"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                feedback = nil
                isProcessing = false
            }
        }
    }
}

private struct TicketDataScannerView: UIViewControllerRepresentable {
    let onRecognized: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized)
    }

    func makeUIViewController(
        context: Context
    ) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(
        _ uiViewController: DataScannerViewController,
        context: Context
    ) {
        if DataScannerViewController.isAvailable,
           !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: DataScannerViewController,
        coordinator: Coordinator
    ) {
        uiViewController.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onRecognized: (String) -> Void
        private var lastValue: String?
        private var lastRecognitionDate = Date.distantPast

        init(onRecognized: @escaping (String) -> Void) {
            self.onRecognized = onRecognized
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                guard case let .barcode(barcode) = item,
                      let value = barcode.observation.payloadStringValue else {
                    continue
                }
                let now = Date()
                guard value != lastValue
                    || now.timeIntervalSince(lastRecognitionDate) > 2 else {
                    continue
                }
                lastValue = value
                lastRecognitionDate = now
                onRecognized(value)
                break
            }
        }
    }
}
