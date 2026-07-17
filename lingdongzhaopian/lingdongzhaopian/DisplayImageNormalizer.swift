// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import UIKit

/// Flattens HDR/EDR image representations into a standard-dynamic-range
/// bitmap before they enter SwiftUI composition. This prevents an HDR photo
/// from changing the apparent brightness of nearby SDR text and controls.
enum DisplayImageNormalizer {
    static func standardDynamicRange(_ image: UIImage) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }

        let format = image.imageRendererFormat
        format.scale = image.scale
        format.opaque = false
        format.preferredRange = .standard

        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
