// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import CoreLocation
import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers

enum ArtworkExportError: LocalizedError {
    case permissionDenied
    case encodingFailed
    case missingVideo
    case audioWriterFailed(String)
    case videoWriterFailed(String)
    case photoLibraryFailed
    case transparencyValidationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有相册写入权限。请在系统设置中允许“灵动照片”添加照片。".appLocalized
        case .encodingFailed:
            "作品编码失败，请稍后重试。".appLocalized
        case .missingVideo:
            "所选 Live Photo 的动态片段不可用，请确认原片已从 iCloud 下载。".appLocalized
        case .audioWriterFailed(let reason):
            String(format: "Live Photo 音频生成失败：%@".appLocalized, reason)
        case .videoWriterFailed(let reason):
            String(format: "Live Photo 生成失败：%@".appLocalized, reason)
        case .photoLibraryFailed:
            "保存失败，请确认设备存储空间后重试。".appLocalized
        case .transparencyValidationFailed:
            "票根透明区域校验失败，请稍后重试。".appLocalized
        }
    }
}

enum ArtworkPhotoLibrarySaveResult {
    case livePhoto
    case livePhotoWithoutAudio
    case stillImageFallback
}

enum ArtworkExporter {
    static func preparePhotoLibraryAccess() async throws {
        let authorization = await addAuthorization()
        guard authorization == .authorized || authorization == .limited else {
            throw ArtworkExportError.permissionDenied
        }
    }

    nonisolated static func encodedStillData(
        _ image: UIImage,
        metadata: PhotoMetadata,
        originalImageData: Data?,
        format: ArtworkExportFormat,
        metadataPolicy: ArtworkMetadataPolicy
    ) throws -> Data {
        try imageData(
            image: image,
            metadata: metadata,
            originalImageData: originalImageData,
            assetIdentifier: nil,
            format: format,
            metadataPolicy: metadataPolicy
        )
    }

    static func saveStill(
        _ image: UIImage,
        metadata: PhotoMetadata,
        originalImageData: Data?,
        format: ArtworkExportFormat = .jpeg,
        metadataPolicy: ArtworkMetadataPolicy = .preserve,
        encodedDataValidator: ((Data) -> Bool)? = nil
    ) async throws {
        // Encoding multi-megapixel artwork is the single most expensive step of
        // an export. Keep it off the main actor so a termination request (home
        // swipe, system teardown) never stalls behind a synchronous encode.
        let data = try await Task.detached(priority: .userInitiated) {
            try imageData(
                image: image,
                metadata: metadata,
                originalImageData: originalImageData,
                assetIdentifier: nil,
                format: format,
                metadataPolicy: metadataPolicy
            )
        }.value
        if let encodedDataValidator,
           !encodedDataValidator(data) {
            throw ArtworkExportError.transparencyValidationFailed
        }
        try await saveToPhotoLibrary(
            photoData: data,
            pairedVideoURL: nil,
            metadata: metadata,
            format: format,
            metadataPolicy: metadataPolicy
        )
    }

    static func saveLivePhoto(
        renderedStill: UIImage,
        sourceVideoURLs: [Int: URL],
        metadata: PhotoMetadata,
        originalImageData: Data?,
        metadataPolicy: ArtworkMetadataPolicy = .preserve,
        renderFrame: @escaping @MainActor ([Int: UIImage], CGFloat) -> UIImage?,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> ArtworkPhotoLibrarySaveResult {
        guard let primarySource = sourceVideoURLs.sorted(by: { $0.key < $1.key }).first else {
            throw ArtworkExportError.missingVideo
        }
        try await preparePhotoLibraryAccess()
        let identifier = UUID().uuidString
        let stillData = try await Task.detached(priority: .userInitiated) {
            try imageData(
                image: renderedStill,
                metadata: metadata,
                originalImageData: originalImageData,
                assetIdentifier: identifier,
                format: .jpeg,
                metadataPolicy: metadataPolicy
            )
        }.value
        let pairedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-export-\(identifier)")
            .appendingPathExtension("mov")
        let videoOutputSize = try livePhotoVideoOutputSize(for: renderedStill)
        guard let settledImage = renderedStill.cgImage else {
            throw ArtworkExportError.encodingFailed
        }

        defer { try? FileManager.default.removeItem(at: pairedURL) }
        do {
            try await Task.detached(priority: .userInitiated) {
                try await makePairedVideo(
                    sourceURL: primarySource.value,
                    sourceVideoURLs: sourceVideoURLs,
                    destinationURL: pairedURL,
                    outputSize: videoOutputSize,
                    settledImage: settledImage,
                    assetIdentifier: identifier,
                    includesAudio: true,
                    renderFrame: { frames in
                        renderFrame(frames, videoOutputSize.width)
                    },
                    progress: progress
                )
            }.value
            try await saveToPhotoLibrary(
                photoData: stillData,
                pairedVideoURL: pairedURL,
                metadata: metadata,
                format: .jpeg,
                metadataPolicy: metadataPolicy
            )
            return .livePhoto
        } catch {
            guard shouldRetryLivePhotoWithoutAudio(after: error) else { throw error }
        }

        try? FileManager.default.removeItem(at: pairedURL)
        let normalizedStillData = try await Task.detached(priority: .userInitiated) {
            try imageData(
                image: renderedStill,
                metadata: metadata,
                originalImageData: nil,
                assetIdentifier: identifier,
                format: .jpeg,
                metadataPolicy: metadataPolicy
            )
        }.value
        do {
            try await Task.detached(priority: .userInitiated) {
                try await makePairedVideo(
                    sourceURL: primarySource.value,
                    sourceVideoURLs: sourceVideoURLs,
                    destinationURL: pairedURL,
                    outputSize: videoOutputSize,
                    settledImage: settledImage,
                    assetIdentifier: identifier,
                    includesAudio: false,
                    renderFrame: { frames in
                        renderFrame(frames, videoOutputSize.width)
                    },
                    progress: progress
                )
            }.value
            try await saveToPhotoLibrary(
                photoData: normalizedStillData,
                pairedVideoURL: pairedURL,
                metadata: metadata,
                format: .jpeg,
                metadataPolicy: metadataPolicy
            )
            return .livePhotoWithoutAudio
        } catch {
            guard isInvalidPhotoResourceError(error) else { throw error }
        }

        let fallbackStillData = try await Task.detached(priority: .userInitiated) {
            try imageData(
                image: renderedStill,
                metadata: metadata,
                originalImageData: nil,
                assetIdentifier: nil,
                format: .jpeg,
                metadataPolicy: metadataPolicy
            )
        }.value
        try await saveToPhotoLibrary(
            photoData: fallbackStillData,
            pairedVideoURL: nil,
            metadata: metadata,
            format: .jpeg,
            metadataPolicy: metadataPolicy
        )
        return .stillImageFallback
    }

    nonisolated private static func livePhotoVideoOutputSize(for renderedStill: UIImage) throws -> CGSize {
        guard let image = renderedStill.cgImage else {
            throw ArtworkExportError.encodingFailed
        }

        let stillWidth = CGFloat(image.width)
        let stillHeight = CGFloat(image.height)
        guard stillWidth > 0, stillHeight > 0 else {
            throw ArtworkExportError.encodingFailed
        }

        // A Live Photo's high-resolution still and paired movie are allowed to
        // use different dimensions. Keep the requested original resolution for
        // the still, while limiting H.264 motion frames to the same 2K/4K
        // envelope already proven reliable by the app's 2K export option.
        let isLandscape = stillWidth >= stillHeight
        let maximumWidth: CGFloat = isLandscape ? 3_840 : 2_160
        let maximumHeight: CGFloat = isLandscape ? 2_160 : 3_840
        let scale = min(1, maximumWidth / stillWidth, maximumHeight / stillHeight)
        return CGSize(
            width: max(2, floor(stillWidth * scale)),
            height: max(2, floor(stillHeight * scale))
        )
    }

    nonisolated private static func imageData(
        image: UIImage,
        metadata: PhotoMetadata,
        originalImageData: Data?,
        assetIdentifier: String?,
        format: ArtworkExportFormat,
        metadataPolicy: ArtworkMetadataPolicy
    ) throws -> Data {
        guard let sourceImage = image.cgImage,
              let cgImage = imageForEncoding(sourceImage, format: format),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                destinationData,
                format.type.identifier as CFString,
                1,
                nil
              ) else {
            throw ArtworkExportError.encodingFailed
        }

        var properties: [CFString: Any] = [:]
        if metadataPolicy.preservesMetadata,
           let originalImageData,
           let source = CGImageSourceCreateWithData(originalImageData as CFData, nil),
           let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            properties = originalProperties
        }
        if !metadataPolicy.preservesLocation {
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary)
        }
        properties[kCGImagePropertyPixelWidth] = cgImage.width
        properties[kCGImagePropertyPixelHeight] = cgImage.height
        properties[kCGImageDestinationLossyCompressionQuality] = 0.94
        if metadataPolicy.preservesMetadata {
            merge(
                metadata: metadata,
                pixelWidth: cgImage.width,
                pixelHeight: cgImage.height,
                preserveLocation: metadataPolicy.preservesLocation,
                into: &properties
            )
        } else {
            properties.removeValue(forKey: kCGImagePropertyTIFFDictionary)
            properties.removeValue(forKey: kCGImagePropertyExifDictionary)
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary)
            properties.removeValue(forKey: kCGImagePropertyIPTCDictionary)
        }

        // The exported pixels are rendered in their final upright orientation.
        // Do not retain the source photo's TIFF rotation tag, otherwise Photos
        // may rotate the already-upright artwork a second time in its viewer.
        normalizeRenderedOrientation(in: &properties)

        var makerApple = metadataPolicy.preservesMetadata
            ? properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any] ?? [:]
            : [:]
        if let assetIdentifier {
            makerApple["17"] = assetIdentifier
        } else {
            makerApple.removeValue(forKey: "17")
        }
        if !makerApple.isEmpty { properties[kCGImagePropertyMakerAppleDictionary] = makerApple }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ArtworkExportError.encodingFailed
        }
        return destinationData as Data
    }

    nonisolated private static func imageForEncoding(
        _ image: CGImage,
        format: ArtworkExportFormat
    ) -> CGImage? {
        guard format == .jpeg else { return image }

        // JPEG has no alpha channel. ImageIO otherwise turns fully transparent
        // ticket corners and the punched notch black. Composite them over a
        // neutral white surface so JPEG exports remain clean, while PNG/HEIC
        // continue to preserve the genuinely hollow areas.
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }

    nonisolated private static func normalizeRenderedOrientation(
        in properties: inout [CFString: Any]
    ) {
        properties[kCGImagePropertyOrientation] = 1

        guard var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] else {
            return
        }
        tiff[kCGImagePropertyTIFFOrientation] = 1
        properties[kCGImagePropertyTIFFDictionary] = tiff
    }

    nonisolated private static func merge(
        metadata: PhotoMetadata,
        pixelWidth: Int,
        pixelHeight: Int,
        preserveLocation: Bool,
        into properties: inout [CFString: Any]
    ) {
        var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        if let make = metadata.make { tiff[kCGImagePropertyTIFFMake] = make }
        if let model = metadata.model { tiff[kCGImagePropertyTIFFModel] = model }

        var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        if let aperture = metadata.aperture { exif[kCGImagePropertyExifFNumber] = aperture }
        if let exposureTime = metadata.exposureTime { exif[kCGImagePropertyExifExposureTime] = exposureTime }
        if let iso = metadata.iso { exif[kCGImagePropertyExifISOSpeedRatings] = [iso] }
        if let focalLength = metadata.focalLength { exif[kCGImagePropertyExifFocalLength] = focalLength }
        if let lensModel = metadata.lensModel { exif[kCGImagePropertyExifLensModel] = lensModel }
        exif[kCGImagePropertyExifPixelXDimension] = pixelWidth
        exif[kCGImagePropertyExifPixelYDimension] = pixelHeight
        if let captureDate = metadata.captureDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let value = formatter.string(from: captureDate)
            exif[kCGImagePropertyExifDateTimeOriginal] = value
            exif[kCGImagePropertyExifDateTimeDigitized] = value
            tiff[kCGImagePropertyTIFFDateTime] = value
        }

        var gps: [CFString: Any] = [:]
        if preserveLocation {
            gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
            if let latitude = metadata.latitude {
                gps[kCGImagePropertyGPSLatitude] = abs(latitude)
                gps[kCGImagePropertyGPSLatitudeRef] = latitude < 0 ? "S" : "N"
            }
            if let longitude = metadata.longitude {
                gps[kCGImagePropertyGPSLongitude] = abs(longitude)
                gps[kCGImagePropertyGPSLongitudeRef] = longitude < 0 ? "W" : "E"
            }
            if let altitude = metadata.altitude {
                gps[kCGImagePropertyGPSAltitude] = abs(altitude)
                gps[kCGImagePropertyGPSAltitudeRef] = altitude < 0 ? 1 : 0
            }
        } else {
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary)
        }

        if !tiff.isEmpty { properties[kCGImagePropertyTIFFDictionary] = tiff }
        if !exif.isEmpty { properties[kCGImagePropertyExifDictionary] = exif }
        if !gps.isEmpty { properties[kCGImagePropertyGPSDictionary] = gps }
    }

    nonisolated private static func makePairedVideo(
        sourceURL: URL,
        sourceVideoURLs: [Int: URL],
        destinationURL: URL,
        outputSize: CGSize,
        settledImage: CGImage,
        assetIdentifier: String,
        includesAudio: Bool,
        renderFrame: @escaping @MainActor ([Int: UIImage]) -> UIImage?,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ArtworkExportError.missingVideo
        }
        let videoRange = try await sourceTrack.load(.timeRange)
        let duration = videoRange.duration
        guard videoRange.start.isNumeric, duration.isNumeric, duration.seconds > 0 else {
            throw ArtworkExportError.missingVideo
        }
        let nominalFrameRate = try await sourceTrack.load(.nominalFrameRate)
        let framesPerSecond = nominalFrameRate.isFinite && nominalFrameRate > 0
            ? min(max(Double(nominalFrameRate), 15), 24)
            : 24
        let frameCount = max(2, Int(ceil(duration.seconds * framesPerSecond)))
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mov)
        defer {
            if writer.status == .writing { writer.cancelWriting() }
        }
        let width = max(2, Int(outputSize.width.rounded()) / 2 * 2)
        let height = max(2, Int(outputSize.height.rounded()) / 2 * 2)
        let videoOutputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(3_500_000, width * height * 3),
                AVVideoMaxKeyFrameIntervalKey: Int(framesPerSecond),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        guard writer.canApply(
            outputSettings: videoOutputSettings,
            forMediaType: .video
        ) else {
            throw ArtworkExportError.videoWriterFailed(
                "当前设备无法编码所需尺寸的动态视频。"
            )
        }
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoOutputSettings
        )
        videoInput.expectsMediaDataInRealTime = false
        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )

        let metadataItem = AVMutableMetadataItem()
        metadataItem.key = "com.apple.quicktime.still-image-time" as NSString
        metadataItem.keySpace = .quickTimeMetadata
        metadataItem.value = 0 as NSNumber
        metadataItem.dataType = kCMMetadataBaseDataType_SInt8 as String
        let specification: [CFString: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier:
                "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType:
                kCMMetadataBaseDataType_SInt8
        ]
        var metadataDescription: CMFormatDescription?
        let metadataStatus = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [specification] as CFArray,
            formatDescriptionOut: &metadataDescription
        )
        guard metadataStatus == noErr, let metadataDescription else {
            throw ArtworkExportError.videoWriterFailed("无法创建动态照片时间标记。")
        }
        let metadataInput = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: metadataDescription
        )
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)

        var audioReader: AVAssetReader?
        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if includesAudio {
            do {
                if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                    guard let formatHint = try await sourceAudioTrack.load(.formatDescriptions).first,
                          let audioDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatHint)?.pointee,
                          audioDescription.mSampleRate.isFinite,
                          audioDescription.mSampleRate > 0,
                          (1...2).contains(audioDescription.mChannelsPerFrame) else {
                        throw ArtworkExportError.audioWriterFailed("Live Photo 音频格式不可用。".appLocalized)
                    }
                    let reader = try AVAssetReader(asset: asset)
                    reader.timeRange = videoRange
                    let sampleRate = audioDescription.mSampleRate > 44_100 ? 48_000.0 : 44_100.0
                    let channelCount = Int(audioDescription.mChannelsPerFrame)
                    let output = AVAssetReaderTrackOutput(
                        track: sourceAudioTrack,
                        outputSettings: [
                            AVFormatIDKey: kAudioFormatLinearPCM,
                            AVSampleRateKey: sampleRate,
                            AVNumberOfChannelsKey: channelCount,
                            AVLinearPCMBitDepthKey: 16,
                            AVLinearPCMIsFloatKey: false,
                            AVLinearPCMIsBigEndianKey: false,
                            AVLinearPCMIsNonInterleaved: false
                        ]
                    )
                    let audioSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: sampleRate,
                        AVNumberOfChannelsKey: channelCount,
                        AVEncoderBitRateKey: 128_000
                    ]
                    guard writer.canApply(outputSettings: audioSettings, forMediaType: .audio) else {
                        throw ArtworkExportError.audioWriterFailed("当前设备不支持所需的音频编码格式。".appLocalized)
                    }
                    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                    input.expectsMediaDataInRealTime = false
                    guard reader.canAdd(output), writer.canAdd(input) else {
                        throw ArtworkExportError.audioWriterFailed("当前设备不支持读取或写入这段音频。".appLocalized)
                    }
                    reader.add(output)
                    writer.add(input)
                    audioReader = reader
                    audioOutput = output
                    audioInput = input
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ArtworkExportError.audioWriterFailed(error.localizedDescription)
            }
        }

        guard writer.canAdd(videoInput), writer.canAdd(metadataInput) else {
            throw ArtworkExportError.videoWriterFailed("当前设备不支持所需的视频编码格式。")
        }
        writer.add(videoInput)
        writer.add(metadataInput)

        let identifierItem = AVMutableMetadataItem()
        identifierItem.key = "com.apple.quicktime.content.identifier" as NSString
        identifierItem.keySpace = .quickTimeMetadata
        identifierItem.value = assetIdentifier as NSString
        writer.metadata = [identifierItem]

        guard writer.startWriting() else {
            throw ArtworkExportError.videoWriterFailed(writer.error?.localizedDescription ?? "视频写入器无法启动。")
        }
        writer.startSession(atSourceTime: .zero)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
        var frameGenerators: [Int: (generator: AVAssetImageGenerator, range: CMTimeRange)] = [:]
        defer { for source in frameGenerators.values { source.generator.cancelAllCGImageGeneration() } }
        for (index, url) in sourceVideoURLs {
            if url == sourceURL {
                frameGenerators[index] = (generator, videoRange)
            } else {
                let additionalAsset = AVURLAsset(url: url)
                guard let additionalTrack = try await additionalAsset.loadTracks(withMediaType: .video).first else {
                    throw ArtworkExportError.missingVideo
                }
                let additionalRange = try await additionalTrack.load(.timeRange)
                guard additionalRange.start.isNumeric, additionalRange.duration.isNumeric,
                      additionalRange.duration.seconds > 0 else { throw ArtworkExportError.missingVideo }
                let additionalGenerator = AVAssetImageGenerator(asset: additionalAsset)
                additionalGenerator.appliesPreferredTrackTransform = true
                additionalGenerator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
                additionalGenerator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
                frameGenerators[index] = (additionalGenerator, additionalRange)
            }
        }

        let stillTime = CMTime(seconds: min(duration.seconds / 2, 1.5), preferredTimescale: 600)
        let timedGroup = AVTimedMetadataGroup(
            items: [metadataItem],
            timeRange: CMTimeRange(start: stillTime, duration: CMTime(value: 1, timescale: 30))
        )
        guard metadataAdaptor.append(timedGroup) else {
            writer.cancelWriting()
            throw ArtworkExportError.videoWriterFailed(writer.error?.localizedDescription ?? "无法写入动态照片时间标记。")
        }
        metadataInput.markAsFinished()
        guard let settledCGImage = normalizedVideoImage(settledImage, width: width, height: height) else {
            throw ArtworkExportError.encodingFailed
        }

        let audioWritingTask: Task<Void, Error>?
        if let audioReader, let audioOutput, let audioInput {
            audioWritingTask = Task {
                try await writeAudioSamples(
                    reader: audioReader,
                    output: audioOutput,
                    input: audioInput,
                    writer: writer,
                    sourceStart: videoRange.start
                )
            }
        } else {
            audioWritingTask = nil
        }

        do {
            for index in 0..<frameCount {
                try Task.checkCancellation()
                let presentationTime = CMTime(seconds: Double(index) / framesPerSecond, preferredTimescale: 600)
                let normalizedProgress = min(
                    1,
                    max(0, presentationTime.seconds / duration.seconds)
                )
                var dynamicFrames: [Int: UIImage] = [:]
                for (photoIndex, source) in frameGenerators {
                    let lastReadableTime = CMTimeSubtract(
                        CMTimeRangeGetEnd(source.range),
                        CMTime(seconds: min(1 / framesPerSecond, source.range.duration.seconds / 2), preferredTimescale: 600)
                    )
                    let requestedTime = CMTimeMinimum(
                        CMTimeAdd(
                            source.range.start,
                            CMTime(seconds: source.range.duration.seconds * normalizedProgress, preferredTimescale: 600)
                        ),
                        lastReadableTime
                    )
                    let sourceImage = try await readableFrame(from: source.generator, at: requestedTime)
                    dynamicFrames[photoIndex] = UIImage(cgImage: sourceImage)
                }
                guard let composedImage = await renderFrame(dynamicFrames),
                      let dynamicCGImage = composedImage.cgImage else {
                    throw ArtworkExportError.encodingFailed
                }
                let settleProgress = min(1, max(0, (normalizedProgress - 0.86) / 0.14))
                guard let composedCGImage = crossfadedImage(
                    from: dynamicCGImage,
                    to: settledCGImage,
                    amount: settleProgress
                ) else {
                    throw ArtworkExportError.encodingFailed
                }

                let readinessDeadline = ContinuousClock.now.advanced(by: .seconds(30))
                while !videoInput.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    if writer.status != .writing || ContinuousClock.now >= readinessDeadline {
                        throw ArtworkExportError.videoWriterFailed(
                            writer.error?.localizedDescription ?? "视频编码中断。"
                        )
                    }
                    try await Task.sleep(for: .milliseconds(4))
                }
                guard let pool = pixelAdaptor.pixelBufferPool,
                      let pixelBuffer = makePixelBuffer(
                          from: composedCGImage,
                          width: width,
                          height: height,
                          pool: pool
                      ),
                      pixelAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                    throw ArtworkExportError.videoWriterFailed(
                        writer.error?.localizedDescription ?? "视频帧写入失败。"
                    )
                }

                await progress(Double(index + 1) / Double(frameCount))
            }
        } catch {
            var audioFailure: Error?
            if writer.status == .failed, let audioWritingTask {
                do { try await audioWritingTask.value } catch { audioFailure = error }
            }
            audioWritingTask?.cancel()
            if let audioWritingTask {
                _ = try? await audioWritingTask.value
            }
            writer.cancelWriting()
            if let audioFailure, case .audioWriterFailed = audioFailure as? ArtworkExportError {
                throw audioFailure
            }
            throw error
        }

        videoInput.markAsFinished()
        if let audioWritingTask {
            do {
                try await audioWritingTask.value
            } catch {
                writer.cancelWriting()
                throw error
            }
        }
        writer.endSession(atSourceTime: duration)
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw ArtworkExportError.videoWriterFailed(writer.error?.localizedDescription ?? "动态视频未完成。")
        }
    }

    nonisolated private static func readableFrame(
        from generator: AVAssetImageGenerator,
        at time: CMTime
    ) async throws -> CGImage {
        do {
            return try await generator.image(at: time).image
        } catch {
            try Task.checkCancellation()
            let before = generator.requestedTimeToleranceBefore
            let after = generator.requestedTimeToleranceAfter
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .positiveInfinity
            defer {
                generator.requestedTimeToleranceBefore = before
                generator.requestedTimeToleranceAfter = after
            }
            return try await generator.image(at: time).image
        }
    }

    nonisolated private static func normalizedVideoImage(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        return context.makeImage()
    }

    nonisolated private static func crossfadedImage(
        from source: CGImage,
        to destination: CGImage,
        amount: Double
    ) -> CGImage? {
        guard amount > 0 else { return source }
        guard amount < 1 else { return destination }
        let width = destination.width
        let height = destination.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(source, in: rect)
        context.setAlpha(CGFloat(amount))
        context.draw(destination, in: rect)
        return context.makeImage()
    }

    nonisolated private static func writeAudioSamples(
        reader: AVAssetReader,
        output: AVAssetReaderTrackOutput,
        input: AVAssetWriterInput,
        writer: AVAssetWriter,
        sourceStart: CMTime
    ) async throws {
        do {
            guard reader.startReading() else {
                throw ArtworkExportError.audioWriterFailed(
                    reader.error?.localizedDescription ?? "Live Photo 音频读取器无法启动。".appLocalized
                )
            }
            var readinessDeadline = ContinuousClock.now.advanced(by: .seconds(30))
            while true {
                try Task.checkCancellation()

                switch writer.status {
                case .writing:
                    break
                case .failed:
                    throw ArtworkExportError.audioWriterFailed(
                        writer.error?.localizedDescription ?? "Live Photo 音频写入中断。".appLocalized
                    )
                default:
                    throw ArtworkExportError.audioWriterFailed("Live Photo 音频写入器状态异常。".appLocalized)
                }

                guard input.isReadyForMoreMediaData else {
                    guard ContinuousClock.now < readinessDeadline else {
                        throw ArtworkExportError.audioWriterFailed("Live Photo 音频写入超时。".appLocalized)
                    }
                    try await Task.sleep(for: .milliseconds(3))
                    continue
                }

                if let sampleBuffer = output.copyNextSampleBuffer() {
                    let normalizedSample = try normalizedAudioSample(sampleBuffer, sourceStart: sourceStart)
                    guard input.append(normalizedSample) else {
                        throw ArtworkExportError.audioWriterFailed(
                            writer.error?.localizedDescription ?? "Live Photo 音频写入失败。".appLocalized
                        )
                    }
                    readinessDeadline = ContinuousClock.now.advanced(by: .seconds(30))
                    continue
                }

                switch reader.status {
                case .reading:
                    guard ContinuousClock.now < readinessDeadline else {
                        throw ArtworkExportError.audioWriterFailed("Live Photo 音频读取超时。".appLocalized)
                    }
                    try await Task.sleep(for: .milliseconds(3))
                case .completed:
                    input.markAsFinished()
                    return
                case .failed:
                    throw ArtworkExportError.audioWriterFailed(
                    reader.error?.localizedDescription ?? "Live Photo 音频读取失败。".appLocalized
                    )
                case .cancelled:
                    throw CancellationError()
                default:
                    throw ArtworkExportError.audioWriterFailed("Live Photo 音频读取器状态异常。".appLocalized)
                }
            }
        } catch {
            reader.cancelReading()
            if writer.status == .writing {
                input.markAsFinished()
            }
            throw error
        }
    }

    nonisolated private static func normalizedAudioSample(_ sample: CMSampleBuffer, sourceStart: CMTime) throws -> CMSampleBuffer {
        guard CMTimeCompare(sourceStart, .zero) != 0 else { return sample }
        var count = 0
        guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr else {
            throw ArtworkExportError.audioWriterFailed("无法读取音频时间信息。".appLocalized)
        }
        var timing = Array(repeating: CMSampleTimingInfo(), count: count)
        guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: count, arrayToFill: &timing, entriesNeededOut: &count) == noErr else {
            throw ArtworkExportError.audioWriterFailed("无法读取音频时间信息。".appLocalized)
        }
        for index in timing.indices {
            timing[index].presentationTimeStamp = CMTimeSubtract(timing[index].presentationTimeStamp, sourceStart)
            if timing[index].decodeTimeStamp.isNumeric {
                timing[index].decodeTimeStamp = CMTimeSubtract(timing[index].decodeTimeStamp, sourceStart)
            }
        }
        var result: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sample,
                                                  sampleTimingEntryCount: count, sampleTimingArray: &timing,
                                                  sampleBufferOut: &result) == noErr, let result else {
            throw ArtworkExportError.audioWriterFailed("无法对齐音频时间信息。".appLocalized)
        }
        return result
    }

    nonisolated private static func makePixelBuffer(
        from image: CGImage,
        width: Int,
        height: Int,
        pool: CVPixelBufferPool
    ) -> CVPixelBuffer? {
        var optionalBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer) == kCVReturnSuccess,
              let buffer = optionalBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return nil }
        context.interpolationQuality = .high
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private static func saveToPhotoLibrary(
        photoData: Data,
        pairedVideoURL: URL?,
        metadata: PhotoMetadata,
        format: ArtworkExportFormat,
        metadataPolicy: ArtworkMetadataPolicy
    ) async throws {
        try await preparePhotoLibraryAccess()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = metadataPolicy.preservesMetadata ? metadata.captureDate ?? .now : .now
                if metadataPolicy.preservesLocation,
                   let latitude = metadata.latitude,
                   let longitude = metadata.longitude {
                    request.location = CLLocation(latitude: latitude, longitude: longitude)
                }

                let photoOptions = PHAssetResourceCreationOptions()
                photoOptions.originalFilename = "\("灵动照片".appLocalized)-\(Int(Date.now.timeIntervalSince1970)).\(format.fileExtension)"
                photoOptions.uniformTypeIdentifier = format.type.identifier
                request.addResource(with: .photo, data: photoData, options: photoOptions)

                if let pairedVideoURL {
                    let videoOptions = PHAssetResourceCreationOptions()
                    videoOptions.originalFilename = "\("灵动照片".appLocalized)-Live.mov"
                    videoOptions.uniformTypeIdentifier = UTType.quickTimeMovie.identifier
                    request.addResource(with: .pairedVideo, fileURL: pairedVideoURL, options: videoOptions)
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? ArtworkExportError.photoLibraryFailed)
                }
            }
        }
    }

    private static func shouldRetryLivePhotoWithoutAudio(after error: Error) -> Bool {
        if isInvalidPhotoResourceError(error) { return true }
        if let exportError = error as? ArtworkExportError,
           case .audioWriterFailed = exportError {
            return true
        }
        return false
    }

    private static func isInvalidPhotoResourceError(_ error: Error) -> Bool {
        let photosError = error as NSError
        return photosError.domain == PHPhotosError.errorDomain
            && photosError.code == PHPhotosError.Code.invalidResource.rawValue
    }

    private static func addAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
