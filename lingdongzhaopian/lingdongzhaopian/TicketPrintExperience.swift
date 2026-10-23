// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

enum TicketPrintPhase: Equatable {
    case idle
    case preparing
    case feeding
    case finishing
    case success
    case failed

    var isPresented: Bool { self != .idle }

    var statusText: String {
        switch self {
        case .idle:
            ""
        case .preparing:
            "正在制作影像票根"
        case .feeding:
            "正在出票"
        case .finishing:
            "正在写入系统相册"
        case .success:
            "票根已保存到相册"
        case .failed:
            "出票失败，请重试"
        }
    }
}

enum TicketPrintImage {
    static func rotatedClockwise(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage,
              cgImage.width > 0,
              cgImage.height > 0 else {
            return nil
        }

        let oriented = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
        let outputSize = CGSize(width: cgImage.height, height: cgImage.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            oriented.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }
}

enum TicketIslandAvailability {
    @MainActor
    static func isSupported(
        screenSize: CGSize,
        safeAreaTop: CGFloat
    ) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              !ModeLauncherDevice.isDuo else {
            return false
        }
        let windowTopInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
        if max(safeAreaTop, windowTopInset) >= 51 {
            return true
        }





        let size = (
            Int(min(screenSize.width, screenSize.height).rounded()),
            Int(max(screenSize.width, screenSize.height).rounded())
        )
        return [
            (393, 852),
            (402, 874),
            (420, 912),
            (430, 932),
            (440, 956)
        ].contains { $0 == size }
    }
}

struct TicketPrintExperienceView: View {
    let phase: TicketPrintPhase
    let ticketImage: UIImage?
    let feedProgress: CGFloat
    let reduceMotion: Bool
    let supportsIsland: Bool
    let backgroundPalette: [RGBColor]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if supportsIsland {
                    islandPrinter(in: proxy.size)
                } else {
                    standardWaiting
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AmbientBackground(palette: backgroundPalette)
            }
            .contentShape(Rectangle())
            .allowsHitTesting(phase.isPresented)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(phase.statusText)
        }
        .ignoresSafeArea()
        .transition(.identity)
    }

    private func islandPrinter(in screenSize: CGSize) -> some View {
        let baseIslandWidth: CGFloat = screenSize.width >= 420 ? 126 : 118
        let islandHeight = TicketRevealIslandSupport.islandHeight
        let islandBottom = TicketRevealIslandSupport.outletBottom
        let islandTop = islandBottom - islandHeight
        let ticketSize = displayTicketSize(in: screenSize)
        let expandedWidth = min(
            screenSize.width - 24,
            max(baseIslandWidth, ticketSize.width + 18)
        )
        let opensForTicket = ticketImage != nil
            && phase != .preparing
            && phase != .failed
        let islandWidth = opensForTicket ? expandedWidth : baseIslandWidth
        let progress = min(max(feedProgress, 0), 1)
        let ticketOutletY = islandBottom - 4

        return ZStack(alignment: .top) {
            if let ticketImage {
                ZStack(alignment: .top) {
                    Image(uiImage: ticketImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: ticketSize.width, height: ticketSize.height)
                        .shadow(color: .black.opacity(0.20), radius: 12, y: 8)
                        .offset(y: -ticketSize.height * (1 - progress))
                }
                .frame(
                    width: ticketSize.width,
                    height: screenSize.height - ticketOutletY,
                    alignment: .top
                )
                .clipped()
                .offset(y: ticketOutletY)
                .transition(.identity)
            }

            Capsule(style: .continuous)
                .fill(Color.black)
                .frame(width: islandWidth, height: islandHeight)
                .overlay {
                    HStack {
                        Spacer()
                        printerStatusSymbol
                    }
                    .padding(.trailing, 13)
                }
                .shadow(color: .black.opacity(0.20), radius: 8, y: 3)
                .offset(y: islandTop)
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.12)
                        : .spring(response: 0.34, dampingFraction: 0.82),
                    value: islandWidth
                )
        }
        .frame(
            width: screenSize.width,
            height: screenSize.height,
            alignment: .top
        )
    }

    @ViewBuilder
    private var printerStatusSymbol: some View {
        switch phase {
        case .preparing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.orange)
        default:
            Capsule()
                .fill(.white.opacity(0.30))
                .frame(width: 42, height: 2)
        }
    }

    private var standardWaiting: some View {
        VStack(spacing: 12) {
            Spacer()
            Group {
                if phase == .success {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(.green)
                } else if phase == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(.orange)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            Spacer()
        }
        .padding(22)
        .frame(width: 104, height: 104)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func displayTicketSize(in screenSize: CGSize) -> CGSize {
        guard let ticketImage,
              ticketImage.size.width > 0,
              ticketImage.size.height > 0 else {
            return CGSize(width: 120, height: 280)
        }
        let maximumWidth = screenSize.width - 32
        let maximumHeight = screenSize.height * 0.64
        let scale = min(
            maximumWidth / ticketImage.size.width,
            maximumHeight / ticketImage.size.height
        )
        return CGSize(
            width: ticketImage.size.width * scale,
            height: ticketImage.size.height * scale
        )
    }
}
