// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

@MainActor
final class TicketClipLaunchModel: ObservableObject {
    enum ClipState {
        case waiting
        case verified(VerifiedTicket)
        case failed(String)
    }

    @Published private(set) var state: ClipState = .waiting

    func consumeLaunchContext() async {
        if let value = ProcessInfo.processInfo.environment["_XCAppClipURL"],
           let url = URL(string: value) {
            consume(url)
        }
    }

    func consume(_ url: URL) {
        do {
            let ticket = try TicketEnvelope.decodeVerified(from: url)
            if case let .verified(currentTicket) = state,
               currentTicket == ticket {
                return
            }
            state = .verified(ticket)
        } catch {
            state = .failed(
                (error as? LocalizedError)?.errorDescription
                    ?? "票根内容无法读取，请让发送者重新生成二维码。"
            )
        }
    }
}

struct TicketClipRootView: View {
    @ObservedObject var launchModel: TicketClipLaunchModel

    var body: some View {
        Group {
            switch launchModel.state {
            case .waiting:
                landing
            case let .verified(ticket):
                TicketVerificationView(ticket: ticket)
            case let .failed(message):
                TicketVerificationErrorView(message: message)
            }
        }
        .statusBarHidden(true)
        .task(launchModel.consumeLaunchContext)
        .onOpenURL(perform: launchModel.consume)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            launchModel.consume(url)
        }
    }

    private var landing: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.12),
                    Color(red: 0.11, green: 0.27, blue: 0.24),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                Circle()
                    .fill(Color.mint.opacity(0.22))
                    .frame(width: proxy.size.width * 1.1)
                    .blur(radius: 72)
                    .offset(x: -proxy.size.width * 0.44, y: proxy.size.height * 0.24)
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 118, height: 118)
                        .overlay {
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.48), .white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: .black.opacity(0.28), radius: 30, y: 16)

                    Image(systemName: "ticket.fill")
                        .font(.system(size: 47, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }

                VStack(spacing: 9) {
                    Text("扫描影像票根")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("查看照片色盘、拍摄信息与创作者留下的文案")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                    Text("仅在本机解析 · 不读取相册")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.13), lineWidth: 1))
            }
            .foregroundStyle(.white)
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }
}
