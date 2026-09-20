// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ActivityKit
import Foundation

enum TicketRevealActivityPhase: String, Codable, Hashable {
    case preparing
    case revealing
    case verified
}

nonisolated struct TicketRevealActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: TicketRevealActivityPhase
        var progress: Double
    }

    var title: String
    var primaryHex: String
    var secondaryHex: String
}
