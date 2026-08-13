// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ActivityKit
import Foundation

enum TicketPrintActivityPhase: String, Codable, Hashable {
    case preparing
    case printing
    case saving
    case completed
    case failed
}

struct TicketPrintActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: TicketPrintActivityPhase
        var progress: Double
    }

    var title: String
}
