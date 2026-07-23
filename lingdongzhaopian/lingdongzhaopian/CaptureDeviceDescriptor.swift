// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

enum CaptureDeviceCategory: String, Equatable {
    case iPhone
    case smartphone
    case tablet
    case camera
    case unknown

    var systemImageName: String {
        switch self {
        case .iPhone: "iphone"
        case .smartphone: "rectangle.portrait.fill"
        case .tablet: "ipad"
        case .camera: "camera.fill"
        case .unknown: "photo.fill"
        }
    }
}

struct CaptureDeviceDescriptor: Equatable {
    let category: CaptureDeviceCategory
    let manufacturer: String?
    let model: String?

    var systemImageName: String { category.systemImageName }

    var displayName: String? {
        let values = [manufacturer, model].compactMap { value -> String? in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }
        guard !values.isEmpty else { return nil }
        return values.joined(separator: " ")
    }

    static func resolve(make: String?, model: String?) -> CaptureDeviceDescriptor {
        let cleanedMake = cleaned(make)
        let cleanedModel = cleaned(model)
        let searchableMake = searchable(cleanedMake)
        let searchableModel = searchable(cleanedModel)
        let category = category(make: searchableMake, model: searchableModel)
        let manufacturer = canonicalManufacturer(
            make: cleanedMake,
            searchableMake: searchableMake,
            searchableModel: searchableModel,
            category: category
        )
        let normalizedModel = displayModel(cleanedModel, removingManufacturer: manufacturer)

        return CaptureDeviceDescriptor(
            category: category,
            manufacturer: manufacturer,
            model: CaptureDeviceModelCatalog.displayName(
                manufacturer: manufacturer,
                model: normalizedModel,
                category: category
            ) ?? normalizedModel
        )
    }

    private static func category(make: String, model: String) -> CaptureDeviceCategory {
        if model.contains("iphone") { return .iPhone }
        if model.contains("ipad") { return .tablet }

        if make.contains("apple") {
            if model.contains("ipad") { return .tablet }
            return model.isEmpty || model.contains("iphone") ? .iPhone : .unknown
        }

        if containsAny(make, tabletManufacturers),
           containsAny(model, ["tablet", "pad", "tab "])
            || (make.contains("samsung") && model.hasPrefix("sm-x")) {
            return .tablet
        }

        if make.contains("sony") {
            return containsAny(model, ["xperia", "so-", "sog", "xq-"])
                ? .smartphone
                : .camera
        }

        if make.contains("samsung") {
            let cameraPrefixes = ["nx", "ek-gc", "wb", "st", "es", "pl", "mv", "dv", "tl", "sl"]
            if model.contains("digimax") || cameraPrefixes.contains(where: model.hasPrefix) {
                return .camera
            }
            return .smartphone
        }

        if containsAny(make, smartphoneManufacturers) { return .smartphone }
        if containsAny(make, cameraManufacturers) { return .camera }

        if containsAny(model, phoneModelTokens) { return .smartphone }
        if containsAny(model, cameraModelTokens) { return .camera }
        return .unknown
    }

    private static func canonicalManufacturer(
        make: String?,
        searchableMake: String,
        searchableModel: String,
        category: CaptureDeviceCategory
    ) -> String? {
        let candidates: [(tokens: [String], displayName: String)] = [
            (["apple"], "Apple"),
            (["samsung"], "Samsung"),
            (["huawei"], "HUAWEI"),
            (["honor"], "HONOR"),
            (["xiaomi", "redmi", "poco"], searchableMake.contains("redmi") ? "Redmi" : searchableMake.contains("poco") ? "POCO" : "Xiaomi"),
            (["oppo"], "OPPO"),
            (["oneplus"], "OnePlus"),
            (["vivo"], "vivo"),
            (["google"], "Google"),
            (["motorola"], "Motorola"),
            (["nothing"], "Nothing"),
            (["realme"], "realme"),
            (["meizu"], "Meizu"),
            (["nubia"], "nubia"),
            (["zte"], "ZTE"),
            (["asus"], "ASUS"),
            (["sony"], "Sony"),
            (["canon"], "Canon"),
            (["nikon"], "Nikon"),
            (["fujifilm", "fuji photo film"], "FUJIFILM"),
            (["leica", "leitz"], "Leica"),
            (["panasonic"], "Panasonic"),
            (["olympus", "om digital solutions"], searchableMake.contains("om digital") ? "OM SYSTEM" : "Olympus"),
            (["hasselblad"], "Hasselblad"),
            (["ricoh"], "RICOH"),
            (["pentax"], "PENTAX"),
            (["phase one"], "Phase One"),
            (["sigma"], "SIGMA"),
            (["gopro"], "GoPro"),
            (["insta360", "arashi vision"], "Insta360"),
            (["dji"], "DJI"),
            (["kodak"], "Kodak")
        ]

        if let match = candidates.first(where: { containsAny(searchableMake, $0.tokens) }) {
            return match.displayName
        }
        if searchableMake.isEmpty,
           let inferred = candidates.first(where: { containsAny(searchableModel, $0.tokens) }) {
            return inferred.displayName
        }
        if let inferred = inferredManufacturer(fromModel: searchableModel),
           searchableMake.isEmpty
            || (category == .camera && !containsAny(searchableMake, cameraManufacturers)) {
            return inferred
        }
        if searchableMake.isEmpty, category == .iPhone || category == .tablet { return "Apple" }
        return make
    }

    private static func inferredManufacturer(fromModel model: String) -> String? {
        if isLeicaModel(model) {
            return "Leica"
        }

        let prefixGroups: [(prefixes: [String], manufacturer: String)] = [
            (["ilce-", "ilca-", "ilme-", "dsc-", "zv-", "slt-a", "dslr-a", "nex-"], "Sony"),
            (["dmc-", "dc-", "lumix"], "Panasonic"),
            (["eos ", "eosr", "powershot"], "Canon"),
            (["nikon ", "coolpix"], "Nikon"),
            (["x100", "x-t", "x-h", "x-s", "gfx"], "FUJIFILM"),
            (["om-1", "om-3", "om-d", "e-m"], "OM SYSTEM"),
            (["ricoh gr", "gr iii"], "RICOH"),
            (["sm-"], "Samsung")
        ]
        return prefixGroups.first(where: { group in
            group.prefixes.contains(where: model.hasPrefix)
        })?.manufacturer
    }

    /// Leica JPEG/DNG derivatives are occasionally delivered without TIFF Make.
    /// Restrict inference to distinctive digital Leica families so generic model
    /// names from phones and other camera makers are not relabeled.
    private static func isLeicaModel(_ model: String) -> Bool {
        if containsAny(model, ["leica", "leitz"]) { return true }
        let patterns = [
            #"^q(?:\s*\(typ\s*\d+\)|2|3)(?:\s|$|-)"#,
            #"^m(?:8(?:\.2)?|9|10|11)(?:\s|$|-)"#,
            #"^sl(?:\s*\(typ\s*\d+\)|2|3)(?:\s|$|-)"#,
            #"^(?:d|v|c)-?lux(?:\s|$|-)"#,
            #"^digilux(?:\s|$|-)"#
        ]
        return patterns.contains { pattern in
            model.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func displayModel(_ model: String?, removingManufacturer manufacturer: String?) -> String? {
        guard var model = model else { return nil }
        if let manufacturer {
            let escaped = NSRegularExpression.escapedPattern(for: manufacturer)
            model = model.replacingOccurrences(
                of: "(?i)^\\s*\(escaped)\\s*(?:corporation|corp\\.?|inc\\.?)?\\s*",
                with: "",
                options: .regularExpression
            )
        }
        model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? nil : model
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func searchable(_ value: String?) -> String {
        value?
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased() ?? ""
    }

    private static func containsAny(_ value: String, _ candidates: [String]) -> Bool {
        candidates.contains(where: value.contains)
    }

    private static let tabletManufacturers = [
        "apple", "samsung", "huawei", "honor", "xiaomi", "lenovo", "google", "oneplus", "oppo", "vivo"
    ]

    private static let smartphoneManufacturers = [
        "huawei", "honor", "xiaomi", "redmi", "poco", "oppo", "oneplus", "vivo", "google",
        "motorola", "lenovo", "nothing", "realme", "meizu", "nubia", "zte", "tcl", "hmd",
        "nokia", "asus", "lg electronics", "htc", "sharp"
    ]

    private static let cameraManufacturers = [
        "canon", "nikon", "fujifilm", "fuji photo film", "leica", "leitz", "panasonic", "olympus",
        "om digital solutions", "hasselblad", "ricoh", "pentax", "phase one", "sigma", "gopro",
        "insta360", "arashi vision", "dji", "kodak", "casio"
    ]

    private static let phoneModelTokens = [
        "iphone", "xperia", "pixel", "galaxy", "sm-", "moto ", "oneplus", "find ", "reno",
        "realme", "redmi", "poco", "magic", "mate ", "pura ", "nova ", "vivo ", "iqoo"
    ]

    private static let cameraModelTokens = [
        "ilce-", "ilca-", "ilme-", "dsc-", "zv-", "slt-a", "dslr-a", "nex-",
        "eos ", "powershot", "nikon ", "coolpix", "finepix",
        "x100", "x-t", "x-h", "x-s", "gfx", "lumix", "dmc-", "dc-", "leica ", "pentax ",
        "leitz", "q2", "q3", "m8", "m9", "m10", "m11", "sl2", "sl3",
        "d-lux", "v-lux", "c-lux", "digilux",
        "om-1", "om-3", "om-d", "e-m", "ricoh gr", "hasselblad", "gopro", "insta360"
    ]
}
