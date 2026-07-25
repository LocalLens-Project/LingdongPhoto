// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import AVFoundation
import UIKit

enum LivePhotoPreviewError: LocalizedError {
    case missingVideo
    case unreadableFrame

    var errorDescription: String? {
        switch self {
        case .missingVideo:
            "实况照片的动态片段不可用，请确认原片已从 iCloud 下载。"
        case .unreadableFrame:
            "暂时无法播放这张实况照片，请重新选择原片后重试。"
        }
    }
}

enum LivePhotoPreview {
    private final class GeneratorBox: @unchecked Sendable {
        nonisolated(unsafe) let generator: AVAssetImageGenerator

        init(_ generator: AVAssetImageGenerator) {
            self.generator = generator
        }
    }

    private struct Source: @unchecked Sendable {
        let index: Int
        let asset: AVURLAsset
        let generatorBox: GeneratorBox
        let duration: CMTime
        let nominalFrameRate: Float
    }

    private enum FrameLoadingError: Error {
        case timedOut
    }

    /// Extracts the original paired video one frame at a time and feeds those
    /// frames back into the existing artwork canvas. No preview frame is written
    /// into the selected photo or the exported still image.
    static func playOnce(
        sourceVideoURLs: [Int: URL],
        onFrame: @escaping @MainActor ([Int: UIImage]) -> Void
    ) async throws {
        guard let primaryEntry = sourceVideoURLs.sorted(by: { $0.key < $1.key }).first else {
            throw LivePhotoPreviewError.missingVideo
        }

        var sources: [Source] = []
        for (index, url) in sourceVideoURLs.sorted(by: { $0.key < $1.key }) {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let videoTrack = try await asset.loadTracks(withMediaType: .video).first
            guard duration.isValid,
                  duration.seconds > 0,
                  let videoTrack else { continue }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1_000, height: 1_000)
            generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
            generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
            sources.append(
                Source(
                    index: index,
                    asset: asset,
                    generatorBox: GeneratorBox(generator),
                    duration: duration,
                    nominalFrameRate: try await videoTrack.load(.nominalFrameRate)
                )
            )
        }

        guard let primary = sources.first(where: { $0.index == primaryEntry.key }) else {
            throw LivePhotoPreviewError.missingVideo
        }

        let frameRate = min(max(Double(primary.nominalFrameRate), 12), 18)
        let frameInterval = 1.0 / frameRate
        var currentFrames: [Int: UIImage] = [:]

        // The first request starts AVFoundation's decoder and is noticeably
        // slower than subsequent requests on some devices. Prepare it before
        // starting the playback clock so decoder startup never consumes most
        // of a short Live Photo.
        for source in sources {
            let warmupSecond = min(frameInterval, max(0, source.duration.seconds / 4))
            if let image = try await loadFrame(
                from: source,
                at: warmupSecond,
                attempts: source.index == primary.index ? 3 : 2,
                timeout: .seconds(2)
            ) {
                currentFrames[source.index] = image
            }
        }

        guard currentFrames[primary.index] != nil else {
            throw LivePhotoPreviewError.unreadableFrame
        }
        onFrame(currentFrames)

        let audioPlayer = AVPlayer(playerItem: AVPlayerItem(asset: primary.asset))
        let playbackStartedAt = ContinuousClock.now
        audioPlayer.playImmediately(atRate: 1)
        defer {
            audioPlayer.pause()
            for source in sources {
                source.generatorBox.generator.cancelAllCGImageGeneration()
            }
        }

        while true {
            try Task.checkCancellation()
            let elapsed = playbackStartedAt.duration(to: .now)
            let seconds = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
            guard seconds < primary.duration.seconds else { break }

            for source in sources {
                let lastReadableSecond = max(0, source.duration.seconds - 1.0 / 600.0)
                if let image = try await loadFrame(
                    from: source,
                    at: min(seconds, lastReadableSecond),
                    attempts: 1,
                    timeout: .milliseconds(450)
                ) {
                    currentFrames[source.index] = image
                }
            }

            // A sporadic missed frame is not a broken Live Photo. Keep the last
            // successfully decoded frame and continue until the next request.
            onFrame(currentFrames)

            let actualDuration = playbackStartedAt.duration(to: .now)
            let actualElapsed = Double(actualDuration.components.seconds)
                + Double(actualDuration.components.attoseconds) / 1_000_000_000_000_000_000
            let nextFrameTime = (floor(seconds / frameInterval) + 1) * frameInterval
            let delay = nextFrameTime - actualElapsed
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private static func loadFrame(
        from source: Source,
        at seconds: Double,
        attempts: Int,
        timeout: Duration
    ) async throws -> UIImage? {
        let requestedTime = CMTime(
            seconds: max(0, min(seconds, source.duration.seconds)),
            preferredTimescale: 600
        )

        for attempt in 0..<attempts {
            try Task.checkCancellation()
            do {
                return try await loadFrame(
                    using: source.generatorBox,
                    at: requestedTime,
                    timeout: timeout
                )
            } catch {
                try Task.checkCancellation()
                guard attempt + 1 < attempts else { return nil }
                try await Task.sleep(for: .milliseconds(90 * (attempt + 1)))
            }
        }
        return nil
    }

    private static func loadFrame(
        using generatorBox: GeneratorBox,
        at requestedTime: CMTime,
        timeout: Duration
    ) async throws -> UIImage {
        try await withThrowingTaskGroup(of: UIImage.self) { group in
            group.addTask {
                try await withTaskCancellationHandler {
                    let (cgImage, _) = try await generatorBox.generator.image(at: requestedTime)
                    return UIImage(cgImage: cgImage)
                } onCancel: {
                    generatorBox.generator.cancelAllCGImageGeneration()
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw FrameLoadingError.timedOut
            }

            defer { group.cancelAll() }
            guard let image = try await group.next() else {
                throw FrameLoadingError.timedOut
            }
            return image
        }
    }
}
