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
            "实况照片的动态片段不可用，请确认原片已从 iCloud 下载。".appLocalized
        case .unreadableFrame:
            "暂时无法播放这张实况照片，请重新选择原片后重试。".appLocalized
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

    private struct FrameResult: @unchecked Sendable {
        let index: Int
        let image: UIImage?
    }

    private enum FrameLoadingError: Error {
        case timedOut
    }

    struct PreparedPlayback: @unchecked Sendable {
        fileprivate let signature: [Int: String]
        fileprivate let primaryVideoURL: URL
        fileprivate let frameInterval: Double
        fileprivate let frames: [[Int: UIImage]]

        func matches(_ sourceVideoURLs: [Int: URL]) -> Bool {
            signature == LivePhotoPreview.signature(for: sourceVideoURLs)
        }
    }

    static func signature(for sourceVideoURLs: [Int: URL]) -> [Int: String] {
        sourceVideoURLs.mapValues(\.absoluteString)
    }

    static func prepare(sourceVideoURLs: [Int: URL]) async throws -> PreparedPlayback {
        let sortedURLs = sourceVideoURLs.sorted(by: { $0.key < $1.key })
        guard let primaryEntry = sortedURLs.first else {
            throw LivePhotoPreviewError.missingVideo
        }

        let maximumDimension: CGFloat = sortedURLs.count > 2 ? 360 : 480
        var sources: [Source] = []
        for (index, url) in sortedURLs {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let videoTrack = try await asset.loadTracks(withMediaType: .video).first
            guard duration.isValid,
                  duration.seconds > 0,
                  let videoTrack else { continue }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maximumDimension, height: maximumDimension)
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

        defer {
            for source in sources {
                source.generatorBox.generator.cancelAllCGImageGeneration()
            }
        }

        let maximumFrameRate = sources.count > 2 ? 12.0 : 15.0
        let frameRate = min(max(Double(primary.nominalFrameRate), 12), maximumFrameRate)
        let frameInterval = 1.0 / frameRate
        let frameCount = max(1, Int(ceil(primary.duration.seconds * frameRate)))
        var currentFrames: [Int: UIImage] = [:]
        var preparedFrames: [[Int: UIImage]] = []

        for frameIndex in 0...frameCount {
            try Task.checkCancellation()
            let normalizedProgress = min(1, Double(frameIndex) / Double(frameCount))
            let results = try await withThrowingTaskGroup(of: FrameResult.self) { group in
                for source in sources {
                    group.addTask {
                        let lastReadableSecond = max(0, source.duration.seconds - 1.0 / 600.0)
                        let image = try await loadFrame(
                            from: source,
                            at: min(source.duration.seconds * normalizedProgress, lastReadableSecond),
                            attempts: frameIndex == 0 ? 3 : 1,
                            timeout: frameIndex == 0 ? .seconds(2) : .milliseconds(600)
                        )
                        return FrameResult(index: source.index, image: image)
                    }
                }

                var decoded: [FrameResult] = []
                for try await result in group {
                    decoded.append(result)
                }
                return decoded
            }

            for result in results {
                if let image = result.image {
                    currentFrames[result.index] = image
                }
            }
            if currentFrames[primary.index] != nil {
                preparedFrames.append(currentFrames)
            }
        }

        guard !preparedFrames.isEmpty else {
            throw LivePhotoPreviewError.unreadableFrame
        }

        return PreparedPlayback(
            signature: signature(for: sourceVideoURLs),
            primaryVideoURL: primaryEntry.value,
            frameInterval: frameInterval,
            frames: preparedFrames
        )
    }

    static func playOnce(
        prepared: PreparedPlayback,
        onFrame: @escaping @MainActor ([Int: UIImage]) -> Void
    ) async throws {
        guard !prepared.frames.isEmpty else {
            throw LivePhotoPreviewError.missingVideo
        }

        let audioPlayer = AVPlayer(url: prepared.primaryVideoURL)
        audioPlayer.playImmediately(atRate: 1)
        defer {
            audioPlayer.pause()
        }

        for frames in prepared.frames {
            try Task.checkCancellation()
            let frameStartedAt = ContinuousClock.now
            onFrame(frames)

            let frameDuration = frameStartedAt.duration(to: .now)
            let elapsed = Double(frameDuration.components.seconds)
                + Double(frameDuration.components.attoseconds) / 1_000_000_000_000_000_000
            let delay = prepared.frameInterval - elapsed
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
