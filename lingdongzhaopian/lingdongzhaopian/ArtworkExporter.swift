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
    case videoWriterFailed(String)
    case photoLibraryFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有相册写入权限。请在系统设置中允许“灵动照片”添加照片。"
        case .encodingFailed:
            "作品编码失败，请稍后重试。"
        case .missingVideo:
            "所选 Live Photo 的动态片段不可用，请确认原片已从 iCloud 下载。"
        case .videoWriterFailed(let reason):
            "Live Photo 生成失败：\(reason)"
        case .photoLibraryFailed:
            "保存失败，请确认设备存储空间后重试。"
        }
    }
}

private nonisolated final class LiveAudioWriterContext: @unchecked Sendable {
    let reader: AVAssetReader
    let output: AVAssetReaderTrackOutput
    let input: AVAssetWriterInput
    let writer: AVAssetWriter
    private var completed = false

    init(
        reader: AVAssetReader,
        output: AVAssetReaderTrackOutput,
        input: AVAssetWriterInput,
        writer: AVAssetWriter
    ) {
        self.reader = reader
        self.output = output
        self.input = input
        self.writer = writer
    }

    func finish(
        _ result: Result<Void, Error>,
        continuation: CheckedContinuation<Void, Error>
    ) {
        guard !completed else { return }
        completed = true
        input.markAsFinished()
        continuation.resume(with: result)
    }
}

enum ArtworkExporter {
#if DEBUG
    static func debugJPEGData(
        _ image: UIImage,
        metadata: PhotoMetadata,
        originalImageData: Data?,
        preserveLocation: Bool
    ) throws -> Data {
        try jpegData(
            image: image,
            metadata: metadata,
            originalImageData: originalImageData,
            assetIdentifier: nil,
            preserveLocation: preserveLocation
        )
    }
#endif

    static func saveStill(
        _ image: UIImage,
        metadata: PhotoMetadata,
        originalImageData: Data?,
        preserveLocation: Bool = true
    ) async throws {
        let data = try jpegData(
            image: image,
            metadata: metadata,
            originalImageData: originalImageData,
            assetIdentifier: nil,
            preserveLocation: preserveLocation
        )
        try await saveToPhotoLibrary(
            photoData: data,
            pairedVideoURL: nil,
            metadata: metadata,
            preserveLocation: preserveLocation
        )
    }

    static func saveLivePhoto(
        renderedStill: UIImage,
        sourceVideoURLs: [Int: URL],
        metadata: PhotoMetadata,
        originalImageData: Data?,
        renderFrame: @escaping @MainActor ([Int: UIImage]) -> UIImage?,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        guard let primarySource = sourceVideoURLs.sorted(by: { $0.key < $1.key }).first else {
            throw ArtworkExportError.missingVideo
        }
        let identifier = UUID().uuidString
        let stillData = try jpegData(
            image: renderedStill,
            metadata: metadata,
            originalImageData: originalImageData,
            assetIdentifier: identifier,
            preserveLocation: true
        )
        let pairedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lingdong-export-\(identifier)")
            .appendingPathExtension("mov")

        defer { try? FileManager.default.removeItem(at: pairedURL) }
        try await makePairedVideo(
            sourceURL: primarySource.value,
            sourceVideoURLs: sourceVideoURLs,
            destinationURL: pairedURL,
            outputSize: renderedStill.cgImage.map { CGSize(width: $0.width, height: $0.height) }
                ?? CGSize(width: 1080, height: 1440),
            assetIdentifier: identifier,
            renderFrame: renderFrame,
            progress: progress
        )
        try await saveToPhotoLibrary(
            photoData: stillData,
            pairedVideoURL: pairedURL,
            metadata: metadata,
            preserveLocation: true
        )
    }

    private static func jpegData(
        image: UIImage,
        metadata: PhotoMetadata,
        originalImageData: Data?,
        assetIdentifier: String?,
        preserveLocation: Bool
    ) throws -> Data {
        guard let cgImage = image.cgImage,
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                destinationData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
              ) else {
            throw ArtworkExportError.encodingFailed
        }

        var properties: [CFString: Any] = [:]
        if let originalImageData,
           let source = CGImageSourceCreateWithData(originalImageData as CFData, nil),
           let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            properties = originalProperties
        }
        if !preserveLocation {
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary)
        }
        properties[kCGImagePropertyPixelWidth] = cgImage.width
        properties[kCGImagePropertyPixelHeight] = cgImage.height
        properties[kCGImagePropertyOrientation] = 1
        properties[kCGImageDestinationLossyCompressionQuality] = 0.94
        merge(
            metadata: metadata,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            preserveLocation: preserveLocation,
            into: &properties
        )

        var makerApple = properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any] ?? [:]
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

    private static func merge(
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

    private static func makePairedVideo(
        sourceURL: URL,
        sourceVideoURLs: [Int: URL],
        destinationURL: URL,
        outputSize: CGSize,
        assetIdentifier: String,
        renderFrame: @escaping @MainActor ([Int: UIImage]) -> UIImage?,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ArtworkExportError.missingVideo
        }
        let duration = try await asset.load(.duration)
        guard duration.isValid, duration.seconds > 0 else { throw ArtworkExportError.missingVideo }
        let nominalFrameRate = try await sourceTrack.load(.nominalFrameRate)
        let framesPerSecond = min(max(Double(nominalFrameRate), 15), 24)
        let frameCount = max(2, Int(ceil(duration.seconds * framesPerSecond)))
        let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mov)
        let width = max(2, Int(outputSize.width.rounded()) / 2 * 2)
        let height = max(2, Int(outputSize.height.rounded()) / 2 * 2)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: max(3_500_000, width * height * 3),
                    AVVideoMaxKeyFrameIntervalKey: Int(framesPerSecond)
                ]
            ]
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
        if let sourceAudioTrack,
           let formatHint = try await sourceAudioTrack.load(.formatDescriptions).first,
           let audioDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatHint)?.pointee {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(
                track: sourceAudioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            )
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: audioDescription.mSampleRate,
                    AVNumberOfChannelsKey: max(1, Int(audioDescription.mChannelsPerFrame)),
                    AVEncoderBitRateKey: 128_000
                ]
            )
            input.expectsMediaDataInRealTime = false
            if reader.canAdd(output), writer.canAdd(input) {
                reader.add(output)
                writer.add(input)
                audioReader = reader
                audioOutput = output
                audioInput = input
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
        let audioWritingTask: Task<Void, Error>?
        if let audioReader, let audioOutput, let audioInput {
            audioWritingTask = Task {
                try await writeAudioSamples(
                    reader: audioReader,
                    output: audioOutput,
                    input: audioInput,
                    writer: writer
                )
            }
        } else {
            audioWritingTask = nil
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.dynamicRangePolicy = .forceSDR
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
        var frameGenerators: [Int: (generator: AVAssetImageGenerator, duration: CMTime)] = [:]
        for (index, url) in sourceVideoURLs {
            if url == sourceURL {
                frameGenerators[index] = (generator, duration)
            } else {
                let additionalAsset = AVURLAsset(url: url)
                let additionalDuration = try await additionalAsset.load(.duration)
                let additionalGenerator = AVAssetImageGenerator(asset: additionalAsset)
                additionalGenerator.appliesPreferredTrackTransform = true
                additionalGenerator.dynamicRangePolicy = .forceSDR
                additionalGenerator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
                additionalGenerator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
                frameGenerators[index] = (additionalGenerator, additionalDuration)
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

        for index in 0..<frameCount {
            try Task.checkCancellation()
            let presentationTime = CMTime(seconds: Double(index) / framesPerSecond, preferredTimescale: 600)
            var dynamicFrames: [Int: UIImage] = [:]
            for (photoIndex, source) in frameGenerators {
                let requestedTime = CMTimeMinimum(
                    presentationTime,
                    CMTimeSubtract(source.duration, CMTime(value: 1, timescale: 600))
                )
                let (sourceImage, _) = try await source.generator.image(at: requestedTime)
                dynamicFrames[photoIndex] = UIImage(cgImage: sourceImage)
            }
            guard let composedImage = renderFrame(dynamicFrames),
                  let composedCGImage = composedImage.cgImage else {
                writer.cancelWriting()
                throw ArtworkExportError.encodingFailed
            }

            while !videoInput.isReadyForMoreMediaData {
                if writer.status == .failed {
                    throw ArtworkExportError.videoWriterFailed(writer.error?.localizedDescription ?? "视频编码中断。")
                }
                try await Task.sleep(for: .milliseconds(4))
            }
            guard let pool = pixelAdaptor.pixelBufferPool,
                  let pixelBuffer = makePixelBuffer(from: composedCGImage, width: width, height: height, pool: pool),
                  pixelAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                writer.cancelWriting()
                throw ArtworkExportError.videoWriterFailed(writer.error?.localizedDescription ?? "视频帧写入失败。")
            }

            progress(Double(index + 1) / Double(frameCount))
        }

        videoInput.markAsFinished()
        metadataInput.markAsFinished()
        do {
            try await audioWritingTask?.value
        } catch {
            writer.cancelWriting()
            throw error
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw ArtworkExportError.videoWriterFailed(writer.error?.localizedDescription ?? "动态视频未完成。")
        }
    }

    private static func writeAudioSamples(
        reader: AVAssetReader,
        output: AVAssetReaderTrackOutput,
        input: AVAssetWriterInput,
        writer: AVAssetWriter
    ) async throws {
        guard reader.startReading() else {
            input.markAsFinished()
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let context = LiveAudioWriterContext(
                reader: reader,
                output: output,
                input: input,
                writer: writer
            )
            let queue = DispatchQueue(label: "LivePhotoAudioWriter")
            context.input.requestMediaDataWhenReady(on: queue) {
                while context.input.isReadyForMoreMediaData {
                    if context.writer.status == .failed {
                        context.finish(.failure(ArtworkExportError.videoWriterFailed(
                            context.writer.error?.localizedDescription ?? "Live Photo 音频写入中断。"
                        )), continuation: continuation)
                        return
                    }
                    guard let sampleBuffer = context.output.copyNextSampleBuffer() else {
                        if context.reader.status == .failed {
                            context.finish(.failure(ArtworkExportError.videoWriterFailed(
                                context.reader.error?.localizedDescription ?? "Live Photo 音频读取失败。"
                            )), continuation: continuation)
                        } else {
                            context.finish(.success(()), continuation: continuation)
                        }
                        return
                    }
                    guard context.input.append(sampleBuffer) else {
                        context.finish(.failure(ArtworkExportError.videoWriterFailed(
                            context.writer.error?.localizedDescription ?? "Live Photo 音频写入失败。"
                        )), continuation: continuation)
                        return
                    }
                }
            }
        }
    }

    private static func makePixelBuffer(
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
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private static func saveToPhotoLibrary(
        photoData: Data,
        pairedVideoURL: URL?,
        metadata: PhotoMetadata,
        preserveLocation: Bool
    ) async throws {
        let authorization = await addAuthorization()
        guard authorization == .authorized || authorization == .limited else {
            throw ArtworkExportError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = metadata.captureDate ?? .now
                if preserveLocation,
                   let latitude = metadata.latitude,
                   let longitude = metadata.longitude {
                    request.location = CLLocation(latitude: latitude, longitude: longitude)
                }

                let photoOptions = PHAssetResourceCreationOptions()
                photoOptions.originalFilename = "灵动照片-\(Int(Date.now.timeIntervalSince1970)).jpg"
                photoOptions.uniformTypeIdentifier = UTType.jpeg.identifier
                request.addResource(with: .photo, data: photoData, options: photoOptions)

                if let pairedVideoURL {
                    let videoOptions = PHAssetResourceCreationOptions()
                    videoOptions.originalFilename = "灵动照片-Live.mov"
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
