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
    private struct Source {
        let index: Int
        let generator: AVAssetImageGenerator
        let duration: CMTime
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
            guard duration.isValid, duration.seconds > 0 else { continue }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.dynamicRangePolicy = .forceSDR
            generator.maximumSize = CGSize(width: 1_000, height: 1_000)
            generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
            generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
            sources.append(Source(index: index, generator: generator, duration: duration))
        }

        guard let primary = sources.first(where: { $0.index == primaryEntry.key }) else {
            throw LivePhotoPreviewError.missingVideo
        }

        let primaryAsset = AVURLAsset(url: primaryEntry.value)
        let nominalRate = try await primaryAsset.loadTracks(withMediaType: .video).first?
            .load(.nominalFrameRate) ?? 15
        let frameRate = min(max(Double(nominalRate), 12), 18)
        let frameInterval = 1.0 / frameRate
        let playbackStartedAt = Date.now
        let audioPlayer = AVPlayer(url: primaryEntry.value)
        audioPlayer.play()
        defer { audioPlayer.pause() }

        while true {
            try Task.checkCancellation()
            // Drive the requested source time from the wall clock. Image
            // extraction can occasionally take longer than one frame interval;
            // skipping ahead keeps a one-shot preview from running in slow
            // motion on older devices.
            let seconds = Date.now.timeIntervalSince(playbackStartedAt)
            guard seconds < primary.duration.seconds else { break }
            var frames: [Int: UIImage] = [:]

            for source in sources {
                let lastReadableSecond = max(0, source.duration.seconds - 1.0 / 600.0)
                let requestedTime = CMTime(
                    seconds: min(seconds, lastReadableSecond),
                    preferredTimescale: 600
                )
                if let (cgImage, _) = try? await source.generator.image(at: requestedTime) {
                    frames[source.index] = UIImage(cgImage: cgImage)
                }
            }

            guard frames[primary.index] != nil else {
                throw LivePhotoPreviewError.unreadableFrame
            }
            onFrame(frames)

            let actualElapsed = Date.now.timeIntervalSince(playbackStartedAt)
            let nextFrameTime = (floor(seconds / frameInterval) + 1) * frameInterval
            let delay = nextFrameTime - actualElapsed
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }
}
