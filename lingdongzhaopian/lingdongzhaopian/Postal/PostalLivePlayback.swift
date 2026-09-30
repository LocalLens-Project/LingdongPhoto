import AVFoundation
import SwiftUI

struct PostalLiveBadge: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("实况", systemImage: "livephoto")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.black.opacity(0.62))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(.black.opacity(0.04))
                        .overlay(Capsule().stroke(.black.opacity(0.30), lineWidth: 0.8))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("播放实况照片")
        .accessibilityIdentifier("postal.liveBadge")
    }
}

private final class PostalLivePlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?
    private var player: AVQueuePlayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
        clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: item)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = false
        playerLayer.player = player
        self.player = player
        player.play()
    }

    func stop() {
        player?.pause()
        playerLayer.player = nil
        looper = nil
        player = nil
    }
}

private struct PostalLivePlayer: UIViewRepresentable {
    let videoURL: URL

    func makeUIView(context: Context) -> PostalLivePlayerView {
        let view = PostalLivePlayerView()
        view.play(url: videoURL)
        return view
    }

    func updateUIView(_ uiView: PostalLivePlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PostalLivePlayerView, coordinator: ()) {
        uiView.stop()
    }
}

struct PostalLivePlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    let artwork: UIImage
    let videoURL: URL
    var photoRectFraction: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        GeometryReader { proxy in
            let frame = AVMakeRect(
                aspectRatio: artwork.size,
                insideRect: CGRect(origin: .zero, size: proxy.size)
            )
            let videoFrame = CGRect(
                x: frame.minX + frame.width * photoRectFraction.minX,
                y: frame.minY + frame.height * photoRectFraction.minY,
                width: frame.width * photoRectFraction.width,
                height: frame.height * photoRectFraction.height
            )
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                PostalLivePlayer(videoURL: videoURL)
                    .frame(width: videoFrame.width, height: videoFrame.height)
                    .clipped()
                    .position(x: videoFrame.midX, y: videoFrame.midY)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.42), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
                .padding(20)
            }
            .overlay(alignment: .bottom) {
                Label("实况", systemImage: "livephoto")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(.bottom, 26)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

extension StampFormat {
    var livePhotoRectFraction: CGRect? {
        guard let processed = try? StampRenderer.template(self) else { return nil }
        let size = processed.paper.size
        guard size.width > 0, size.height > 0 else { return nil }
        let window = processed.window
        return CGRect(
            x: window.minX / size.width,
            y: window.minY / size.height,
            width: window.width / size.width,
            height: window.height / size.height
        )
    }
}
