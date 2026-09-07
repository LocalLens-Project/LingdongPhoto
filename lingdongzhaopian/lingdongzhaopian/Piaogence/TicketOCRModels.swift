import CryptoKit
import ImageIO
import UIKit
@preconcurrency import Vision

enum PhysicalTicketType: String, CaseIterable, Codable, Hashable {
    case movie = "电影票"
    case train = "铁路票"
    case flight = "航空票"
    case performance = "演出票"
    case musicFestival = "音乐节"
    case exhibition = "展览票"
    case attraction = "景区票"
    case other = "纪念票"

    var symbol: String {
        switch self {
        case .movie: "film.fill"
        case .train: "tram.fill"
        case .flight: "airplane"
        case .performance: "music.mic"
        case .musicFestival: "music.note.list"
        case .exhibition: "photo.artframe"
        case .attraction: "building.columns.fill"
        case .other: "ticket.fill"
        }
    }

    var localizedTitle: String { rawValue.appLocalized }

    var localizedMemoryTemplateName: String { memoryTemplateName.appLocalized }

    var memoryTemplateName: String {
        switch self {
        case .movie: "银幕票"
        case .train: "行旅票"
        case .flight: "云端票"
        case .performance: "在场票"
        case .musicFestival: "夏日票"
        case .exhibition: "看展票"
        case .attraction: "山河票"
        case .other: "记忆票"
        }
    }
}

enum TicketImportPlatform: String, Hashable {
    case paper = "纸质票"
    case damai = "大麦凭证"
    case maoyan = "猫眼凭证"
    case showStart = "秀动凭证"
    case rail12306 = "12306 凭证"
    case airline = "航空凭证"

    var localizedTitle: String { rawValue.appLocalized }

    var symbol: String {
        switch self {
        case .paper: "doc.text.viewfinder"
        case .damai, .maoyan, .showStart: "rectangle.and.text.magnifyingglass"
        case .rail12306: "tram.fill"
        case .airline: "airplane"
        }
    }
}

struct TicketOCRTextBlock: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct TicketOCRResult: Hashable {
    var type: PhysicalTicketType
    var platform: TicketImportPlatform
    var title: String
    var subtitle: String
    var date: Date
    var dateText: String
    var place: String
    var seat: String
    var price: String
    var blocks: [TicketOCRTextBlock]

    var detailLine: String {
        [place, seat, price].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " · ")
    }
}

enum TicketOCRService {
    enum RecognitionError: LocalizedError {
        case invalidImage
        case noText

        var errorDescription: String? {
            switch self {
            case .invalidImage: "无法读取这张票面照片。".appLocalized
            case .noText: "没有识别到清晰文字，请让票面铺平并重新拍摄。".appLocalized
            }
        }
    }

    static func recognize(_ image: UIImage) async throws -> TicketOCRResult {
        guard let cgImage = image.cgImage else { throw RecognitionError.invalidImage }
        let blocks: [TicketOCRTextBlock] = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[TicketOCRTextBlock], Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let blocks = observations.compactMap { observation -> TicketOCRTextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    return TicketOCRTextBlock(
                        text: text,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                continuation.resume(returning: blocks)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.012
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation),
                options: [:]
            )
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }

        guard !blocks.isEmpty else { throw RecognitionError.noText }
        return parse(blocks)
    }

    private static func parse(_ blocks: [TicketOCRTextBlock]) -> TicketOCRResult {
        let ordered = blocks.sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.025 {
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        let lines = ordered.map(\.text)
        let joined = lines.joined(separator: " ")
        let type = classify(joined)
        let platform = classifyPlatform(joined)
        let ignored = ["票价", "座位", "影厅", "影院", "检票", "订单", "二维码", "NO.", "No."]
        let rawTitleCandidate = ordered
            .filter { block in
                block.text.count >= 2
                    && block.text.count <= 28
                    && !ignored.contains(where: block.text.contains)
                    && !looksSensitive(block.text)
                    && !block.text.range(of: #"\d{2,4}[-./年]\d{1,2}"#, options: .regularExpression).isSome
            }
            .max { lhs, rhs in
                let left = lhs.boundingBox.height * 2 + CGFloat(lhs.confidence) * 0.12
                let right = rhs.boundingBox.height * 2 + CGFloat(rhs.confidence) * 0.12
                return left < right
            }?.text ?? type.rawValue
        let genericTitles = ["本人车票", "活动与优惠券", "观影卡/票", "订单详情", "票夹"]
        let titleCandidate = genericTitles.contains(where: rawTitleCandidate.contains)
            ? type.rawValue
            : rawTitleCandidate

        let dateText = firstMatch(
            in: joined,
            patterns: [
                #"20\d{2}[年./-]\d{1,2}[月./-]\d{1,2}(?:日)?(?:\s+\d{1,2}[:：]\d{2})?"#,
                #"\d{1,2}[月./-]\d{1,2}(?:日)?\s+\d{1,2}[:：]\d{2}"#,
                #"\d{1,2}[:：]\d{2}"#
            ]
        ) ?? "时间待确认"
        let parsedDate = parseDate(dateText) ?? .now
        let seat = firstMatch(
            in: joined,
            patterns: [#"\d{1,3}\s*排\s*\d{1,3}\s*座"#, #"(?:座位|Seat)[:： ]*[A-Za-z0-9-]+"#]
        ) ?? ""
        let price = firstMatch(
            in: joined,
            patterns: [#"(?:¥|￥)\s*\d+(?:\.\d{1,2})?"#, #"\d+(?:\.\d{1,2})?\s*元"#]
        ) ?? ""
        let place = lines.first {
            ["影院", "影城", "剧院", "剧场", "站", "馆", "中心", "景区", "公园"]
                .contains(where: $0.contains)
                && $0 != titleCandidate
        } ?? ""
        let subtitle = lines.first {
            $0 != titleCandidate && $0 != place && $0.count > 2 && $0.count < 32
        } ?? type.rawValue

        return TicketOCRResult(
            type: type,
            platform: platform,
            title: titleCandidate,
            subtitle: subtitle,
            date: parsedDate,
            dateText: dateText,
            place: place,
            seat: seat,
            price: price,
            blocks: ordered
        )
    }

    private static func classify(_ text: String) -> PhysicalTicketType {
        if ["电影", "影城", "影院", "影厅", "IMAX"].contains(where: text.contains) { return .movie }
        if ["航班", "登机", "登机口", "登机牌", "BOARDING", "GATE", "航空"].contains(where: text.contains) { return .flight }
        if ["铁路", "12306", "车次", "检票口", "始发站", "终到站", "候车", "高铁"].contains(where: text.contains) { return .train }
        if ["音乐节", "MUSIC FESTIVAL", "舞台", "阵容"].contains(where: text.contains) { return .musicFestival }
        if ["展览", "特展", "美术馆", "博物馆", "画廊", "艺术展", "EXHIBITION", "展期", "优待票"]
            .contains(where: text.localizedCaseInsensitiveContains) { return .exhibition }
        if ["演出", "演唱会", "音乐会", "剧院", "剧场", "话剧", "脱口秀"].contains(where: text.contains) { return .performance }
        if ["门票", "景区", "入园", "公园", "古镇"].contains(where: text.contains) { return .attraction }
        return .other
    }

    private static func classifyPlatform(_ text: String) -> TicketImportPlatform {
        if text.localizedCaseInsensitiveContains("大麦") || text.localizedCaseInsensitiveContains("damai") {
            return .damai
        }
        if text.localizedCaseInsensitiveContains("猫眼") || text.localizedCaseInsensitiveContains("maoyan") {
            return .maoyan
        }
        if text.localizedCaseInsensitiveContains("秀动") || text.localizedCaseInsensitiveContains("showstart") {
            return .showStart
        }
        if text.contains("12306") || text.contains("中国铁路") { return .rail12306 }
        if ["登机牌", "BOARDING PASS", "航空"].contains(where: text.localizedCaseInsensitiveContains) {
            return .airline
        }
        return .paper
    }

    private static func looksSensitive(_ text: String) -> Bool {
        let patterns = [
            #"\d{17}[0-9Xx]"#,
            #"1[3-9]\d{9}"#,
            #"(?:订单|票码|取票码|证件)[:： ]*[A-Za-z0-9-]{6,}"#,
            #"[A-Za-z0-9]{16,}"#,
            #"^\d{7,}$"#,
            #"(?:https?://|www\.|\.(?:com|cn|net))"#
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let range = text.range(of: pattern, options: .regularExpression) else { continue }
            return String(text[range]).replacingOccurrences(of: "：", with: ":")
        }
        return nil
    }

    private static func parseDate(_ text: String) -> Date? {
        let normalized = text
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "：", with: ":")
        for format in ["yyyy-M-d H:mm", "yyyy-M-d", "M-d H:mm", "H:mm"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = format
            if let value = formatter.date(from: normalized) { return value }
        }
        return nil
    }

    static func fingerprint(for data: Data) -> String {
        SHA256.hash(data: data).prefix(8).map { String(format: "%02X", $0) }.joined()
    }
}

private extension Optional {
    var isSome: Bool { self != nil }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
