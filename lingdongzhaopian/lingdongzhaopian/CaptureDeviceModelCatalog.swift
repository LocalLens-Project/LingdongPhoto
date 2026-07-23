// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

/// Converts opaque EXIF product codes into names people commonly recognize.
///
/// The catalog deliberately returns `nil` when a code cannot be identified with
/// confidence. The caller then keeps the original EXIF model, so a future or
/// regional device is never hidden or mislabeled.
enum CaptureDeviceModelCatalog {
    static func displayName(
        manufacturer: String?,
        model: String?,
        category: CaptureDeviceCategory
    ) -> String? {
        guard let model = cleaned(model), !model.isEmpty else { return nil }
        let maker = normalized(manufacturer ?? "")

        if maker.contains("SONY") {
            return category == .camera ? sonyCameraName(model) : nil
        }
        if maker.contains("PANASONIC") {
            return category == .camera ? panasonicCameraName(model) : nil
        }
        if maker.contains("OLYMPUS") || maker.contains("OM SYSTEM") {
            return category == .camera ? olympusCameraName(model) : nil
        }
        if maker.contains("SAMSUNG") {
            return samsungDeviceName(model, category: category)
        }
        if maker.contains("GOOGLE") {
            return googleDeviceName(model, category: category)
        }
        if maker.contains("DJI") {
            return category == .camera ? djiCameraName(model) : nil
        }
        if maker.contains("INSTA360") {
            return category == .camera ? insta360CameraName(model) : nil
        }

        return nil
    }

    // MARK: - Sony cameras

    private static func sonyCameraName(_ rawModel: String) -> String? {
        var code = compactCode(rawModel)
        if code.hasPrefix("SONY") {
            code.removeFirst(4)
            code = code.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        }

        for prefix in ["ILCE-", "ILCA-"] where code.hasPrefix(prefix) {
            let body = String(code.dropFirst(prefix.count))
            if body.hasPrefix("QX") { return body }
            guard let alphaName = sonyAlphaBody(body) else { return nil }
            return "α\(alphaName)"
        }

        for prefix in ["SLT-A", "SLTA", "DSLR-A"] where code.hasPrefix(prefix) {
            var body = String(code.dropFirst(prefix.count))
            if body.range(of: #"^\d+V$"#, options: .regularExpression) != nil {
                body.removeLast()
            }
            guard let alphaName = sonyAlphaBody(body) else { return nil }
            return "α\(alphaName)"
        }

        if code.hasPrefix("DSC-") {
            let body = String(code.dropFirst(4))
            return sonyMarkedName(body) ?? body
        }

        if code.hasPrefix("ZV-") {
            let body = String(code.dropFirst(3))
            return "ZV-\(sonyMarkedName(body) ?? body)"
        }

        if code.hasPrefix("ILME-") {
            let body = String(code.dropFirst(5))
            if body.hasPrefix("FX") || body.hasPrefix("FR") || body.hasPrefix("BURANO") {
                return "Cinema Line \(body)"
            }
        }

        if code.hasPrefix("NEX-") || code.hasPrefix("PXW-") || code.hasPrefix("HXR-") {
            return code
        }
        return nil
    }

    private static func sonyAlphaBody(_ body: String) -> String? {
        guard let groups = captures(
            in: body,
            pattern: #"^(\d+)([A-Z]*?)(?:M(\d+)([A-Z]?))?$"#
        ) else { return nil }

        guard let base = groups[0] else { return nil }
        let variant = groups[1] ?? ""
        guard let markText = groups[2], let mark = Int(markText) else {
            return base + variant
        }
        return base + variant + " " + romanNumeral(mark) + (groups[3] ?? "")
    }

    private static func sonyMarkedName(_ body: String) -> String? {
        guard let groups = captures(
            in: body,
            pattern: #"^(.+?)M(\d+)([A-Z]?)$"#
        ), let name = groups[0], let markText = groups[1], let mark = Int(markText) else { return nil }
        return name + " " + romanNumeral(mark) + (groups[2] ?? "")
    }

    // MARK: - Panasonic cameras

    private static func panasonicCameraName(_ rawModel: String) -> String? {
        var code = compactCode(rawModel)
        if code.hasPrefix("LUMIX") {
            code.removeFirst(5)
            code = code.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        }
        if code.hasPrefix("DMC-") {
            code = String(code.dropFirst(4))
        } else if code.hasPrefix("DC-") {
            code = String(code.dropFirst(3))
        }
        guard !code.isEmpty else { return nil }

        let exactAliases = [
            "S1M2E": "S1IIE"
        ]
        if let alias = exactAliases[code] {
            return "LUMIX \(alias)"
        }

        if let groups = captures(
            in: code,
            pattern: #"^(.+?)(?:M|MK)(\d+)([A-Z]*)$"#
        ), let name = groups[0], let markText = groups[1], let mark = Int(markText) {
            return "LUMIX \(name)\(romanNumeral(mark))\(groups[2] ?? "")"
        }
        return "LUMIX \(code)"
    }

    // MARK: - Olympus / OM SYSTEM cameras

    private static func olympusCameraName(_ rawModel: String) -> String? {
        let code = compactCode(rawModel)
        if code.hasPrefix("OM-D") || code.hasPrefix("PEN") {
            return spacedMark(in: code)
        }
        if code.hasPrefix("OM-") {
            return spacedMark(in: code)
        }
        if code.hasPrefix("E-M") {
            return "OM-D \(spacedMark(in: code))"
        }
        if code.hasPrefix("E-P") || code.hasPrefix("E-PL") {
            return "PEN \(spacedMark(in: code))"
        }
        return nil
    }

    private static func spacedMark(in code: String) -> String {
        code.replacingOccurrences(
            of: #"(?i)\s*MARK\s*([IVX]+|\d+)"#,
            with: " Mark $1",
            options: .regularExpression
        )
    }

    // MARK: - Samsung phones and tablets

    private static func samsungDeviceName(
        _ rawModel: String,
        category: CaptureDeviceCategory
    ) -> String? {
        guard category == .smartphone || category == .tablet else { return nil }
        let code = compactCode(rawModel)
        guard code.hasPrefix("SM-") else { return nil }

        if let alias = firstPrefixAlias(for: code, in: samsungExactAliases) {
            return alias
        }

        if category == .smartphone,
           let groups = captures(in: code, pattern: #"^SM-([AM])(\d{2})\d[A-Z0-9]*$"#),
           let series = groups[0], let number = groups[1] {
            return "Galaxy \(series)\(number)"
        }
        return nil
    }

    /// Prefixes omit storage, radio and region suffixes (for example B, U, U1 or 0).
    /// Keep longer/special-case entries before their wider product-family entries.
    private static let samsungExactAliases: [(String, String)] = [
        ("SM-S948", "Galaxy S26 Ultra"),
        ("SM-S947", "Galaxy S26+"),
        ("SM-S942", "Galaxy S26"),
        ("SM-S938", "Galaxy S25 Ultra"),
        ("SM-S937", "Galaxy S25 Edge"),
        ("SM-S936", "Galaxy S25+"),
        ("SM-S931", "Galaxy S25"),
        ("SM-S928", "Galaxy S24 Ultra"),
        ("SM-S926", "Galaxy S24+"),
        ("SM-S921", "Galaxy S24"),
        ("SM-S918", "Galaxy S23 Ultra"),
        ("SM-S916", "Galaxy S23+"),
        ("SM-S911", "Galaxy S23"),
        ("SM-S711", "Galaxy S23 FE"),
        ("SM-S908", "Galaxy S22 Ultra"),
        ("SM-S906", "Galaxy S22+"),
        ("SM-S901", "Galaxy S22"),
        ("SM-G998", "Galaxy S21 Ultra"),
        ("SM-G996", "Galaxy S21+"),
        ("SM-G991", "Galaxy S21"),
        ("SM-G990", "Galaxy S21 FE"),
        ("SM-G988", "Galaxy S20 Ultra"),
        ("SM-G986", "Galaxy S20+"),
        ("SM-G985", "Galaxy S20+"),
        ("SM-G981", "Galaxy S20"),
        ("SM-G980", "Galaxy S20"),
        ("SM-G781", "Galaxy S20 FE"),
        ("SM-G780", "Galaxy S20 FE"),
        ("SM-G977", "Galaxy S10 5G"),
        ("SM-G975", "Galaxy S10+"),
        ("SM-G973", "Galaxy S10"),
        ("SM-G970", "Galaxy S10e"),
        ("SM-N986", "Galaxy Note20 Ultra"),
        ("SM-N985", "Galaxy Note20 Ultra"),
        ("SM-N981", "Galaxy Note20"),
        ("SM-N980", "Galaxy Note20"),
        ("SM-N976", "Galaxy Note10+"),
        ("SM-N975", "Galaxy Note10+"),
        ("SM-N971", "Galaxy Note10"),
        ("SM-N970", "Galaxy Note10"),
        ("SM-N960", "Galaxy Note9"),
        ("SM-F966", "Galaxy Z Fold7"),
        ("SM-F766", "Galaxy Z Flip7"),
        ("SM-F956", "Galaxy Z Fold6"),
        ("SM-F741", "Galaxy Z Flip6"),
        ("SM-F946", "Galaxy Z Fold5"),
        ("SM-F731", "Galaxy Z Flip5"),
        ("SM-F936", "Galaxy Z Fold4"),
        ("SM-F721", "Galaxy Z Flip4"),
        ("SM-F926", "Galaxy Z Fold3"),
        ("SM-F711", "Galaxy Z Flip3"),
        ("SM-F916", "Galaxy Z Fold2"),
        ("SM-F707", "Galaxy Z Flip 5G"),
        ("SM-F700", "Galaxy Z Flip"),
        ("SM-F907", "Galaxy Fold 5G"),
        ("SM-F900", "Galaxy Fold"),
        ("SM-X920", "Galaxy Tab S10 Ultra"),
        ("SM-X820", "Galaxy Tab S10+"),
        ("SM-X910", "Galaxy Tab S9 Ultra"),
        ("SM-X810", "Galaxy Tab S9+"),
        ("SM-X710", "Galaxy Tab S9"),
        ("SM-X900", "Galaxy Tab S8 Ultra"),
        ("SM-X800", "Galaxy Tab S8+"),
        ("SM-X700", "Galaxy Tab S8"),
        ("SM-G556", "Galaxy XCover7")
    ]

    // MARK: - Google devices

    private static func googleDeviceName(
        _ rawModel: String,
        category: CaptureDeviceCategory
    ) -> String? {
        guard category == .smartphone || category == .tablet else { return nil }
        let code = normalized(rawModel).replacingOccurrences(of: " ", with: "")
        return googleAliases[code]
    }

    private static let googleAliases: [String: String] = [
        "SAILFISH": "Pixel",
        "MARLIN": "Pixel XL",
        "WALLEYE": "Pixel 2",
        "TAIMEN": "Pixel 2 XL",
        "BLUELINE": "Pixel 3",
        "CROSSHATCH": "Pixel 3 XL",
        "SARGO": "Pixel 3a",
        "BONITO": "Pixel 3a XL",
        "FLAME": "Pixel 4",
        "CORAL": "Pixel 4 XL",
        "SUNFISH": "Pixel 4a",
        "BRAMBLE": "Pixel 4a 5G",
        "REDFIN": "Pixel 5",
        "ORIOLE": "Pixel 6",
        "RAVEN": "Pixel 6 Pro",
        "BLUEJAY": "Pixel 6a",
        "PANTHER": "Pixel 7",
        "CHEETAH": "Pixel 7 Pro",
        "LYNX": "Pixel 7a",
        "FELIX": "Pixel Fold",
        "TANGORPRO": "Pixel Tablet",
        "SHIBA": "Pixel 8",
        "HUSKY": "Pixel 8 Pro",
        "AKITA": "Pixel 8a",
        "TOKAY": "Pixel 9",
        "CAIMAN": "Pixel 9 Pro",
        "KOMODO": "Pixel 9 Pro XL",
        "COMET": "Pixel 9 Pro Fold",
        "TEGU": "Pixel 9a"
    ]

    // MARK: - DJI cameras

    private static func djiCameraName(_ rawModel: String) -> String? {
        var code = compactCode(rawModel)
        if code.hasPrefix("DJI") {
            code.removeFirst(3)
            code = code.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        }
        return djiAliases[code]
    }

    /// DJI often stores the internal camera code rather than the drone or
    /// stabilized-camera product name in EXIF.
    private static let djiAliases: [String: String] = [
        "FC230": "Mavic Air",
        "FC2103": "Mavic Air",
        "FC3170": "Mavic Air 2",
        "FC3411": "Air 2S",
        "FC8282": "Air 3 广角相机",
        "FC8284": "Air 3 中长焦相机",
        "FC9113": "Air 3S 广角相机",
        "FC9184": "Air 3S 中长焦相机",
        "FC8183": "Avata",
        "FC8485": "Avata 2",
        "OQ001E": "Avata 360",
        "FC8582": "Flip",
        "FC3305": "DJI FPV",
        "FC350": "Inspire 1 · Zenmuse X3",
        "FC550": "Inspire 1 · Zenmuse X5",
        "FC550RAW": "Inspire 1 · Zenmuse X5R",
        "FC6510": "Inspire 2 · Zenmuse X4S",
        "FC6520": "Inspire 2 · Zenmuse X5S",
        "FC6540": "Inspire 2 · Zenmuse X7",
        "FC4280": "Inspire 3 · Zenmuse X9-8K Air",
        "FC9670": "Lito 1",
        "FC9589": "Lito X1",
        "FC220": "Mavic Pro",
        "L1D-20C": "Mavic 2 Pro",
        "FC2220": "Mavic 2 Zoom",
        "FC2204": "Mavic 2 Enterprise",
        "FC2403": "Mavic 2 Enterprise Dual",
        "MAVIC2-ENTERPRISE-ADVANCED": "Mavic 2 Enterprise Advanced",
        "L2D-20C": "Mavic 3 系列广角相机",
        "FC4170": "Mavic 3 长焦相机",
        "FC4382": "Mavic 3 Pro 中长焦相机",
        "FC4370": "Mavic 3 Pro 长焦相机",
        "M3E": "Mavic 3 Enterprise",
        "M3M": "Mavic 3 Multispectral",
        "M3T": "Mavic 3 Thermal",
        "L3D-100C": "Mavic 4 Pro 广角相机",
        "FC9284": "Mavic 4 Pro 中长焦相机",
        "FC9287": "Mavic 4 Pro 长焦相机",
        "FC7203": "Mavic Mini / Mini SE",
        "FC7303": "Mini 2",
        "FC7503": "Mini 2 SE",
        "FC7703": "Mini 4K",
        "FC3682": "Mini 3",
        "FC3582": "Mini 3 Pro",
        "FC8482": "Mini 4 Pro",
        "FC9313": "Mini 5 Pro",
        "FC8671": "Neo",
        "FC9470": "Neo 2",
        "PHANTOMVISIONFC200": "Phantom 2 Vision+",
        "FC200": "Phantom 2 Vision+",
        "FC300S": "Phantom 3 Advanced",
        "FC300X": "Phantom 3 Professional",
        "FC300C": "Phantom 3 Standard",
        "FC300XW": "Phantom 3 4K",
        "FC300SE": "Phantom 3 SE",
        "FC330": "Phantom 4",
        "FC6310": "Phantom 4 Pro",
        "FC6310S": "Phantom 4 Pro V2.0",
        "FC6310R": "Phantom 4 RTK",
        "FC6360": "P4 Multispectral",
        "FC1102": "Spark",
        "RZ001": "Ryze Tello",
        "OSMOACTION": "Osmo Action",
        "MC211": "DJI Action 2",
        "AC002": "Osmo Action 3",
        "AC003": "Osmo Action 4",
        "AC004": "Osmo Action 5 Pro",
        "OSMOPOCKET": "Osmo Pocket",
        "DJIPOCKET": "DJI Pocket 2",
        "PP-101": "Osmo Pocket 3"
    ]

    // MARK: - Insta360 cameras

    private static func insta360CameraName(_ rawModel: String) -> String? {
        var code = compactCode(rawModel)
        if code.hasPrefix("INSTA360") {
            code.removeFirst("INSTA360".count)
            code = code.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        }
        return insta360Aliases[code]
    }

    private static let insta360Aliases: [String: String] = [
        "X5": "X5",
        "X4AIR": "X4 Air",
        "X4": "X4",
        "X3": "X3",
        "X2": "ONE X2",
        "ONEX2": "ONE X2",
        "ONE2": "ONE X2",
        "ONEX": "ONE X",
        "ONERS": "ONE RS",
        "ONER": "ONE R",
        "GOULTRA": "GO Ultra",
        "GO3S": "GO 3S",
        "GO3": "GO 3",
        "GO2": "GO 2",
        "ACEPRO2": "Ace Pro 2",
        "ACEPRO": "Ace Pro",
        "ACE": "Ace",
        "SPHERE": "Sphere",
        "PRO2": "Pro 2",
        "PRO": "Pro",
        "TITAN": "Titan",
        "EVO": "EVO",
        "NANOS": "Nano S",
        "NANO": "Nano",
        "AIR": "Air"
    ]

    // MARK: - Helpers

    private static func firstPrefixAlias(
        for code: String,
        in aliases: [(String, String)]
    ) -> String? {
        aliases.first(where: { code.hasPrefix($0.0) })?.1
    }

    private static func captures(in value: String, pattern: String) -> [String?]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ), match.range.location != NSNotFound else { return nil }

        return (1..<match.numberOfRanges).map { index -> String? in
            let range = match.range(at: index)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: value) else { return nil }
            return String(value[swiftRange])
        }
    }

    private static func romanNumeral(_ value: Int) -> String {
        guard value > 0, value < 20 else { return String(value) }
        let values = [
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var remainder = value
        var result = ""
        for (number, numeral) in values {
            while remainder >= number {
                remainder -= number
                result += numeral
            }
        }
        return result
    }

    private static func cleaned(_ value: String?) -> String? {
        value?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func compactCode(_ value: String) -> String {
        normalized(value).replacingOccurrences(of: " ", with: "")
    }
}
