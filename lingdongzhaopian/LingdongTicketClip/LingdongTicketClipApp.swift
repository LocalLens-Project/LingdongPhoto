// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

@main
struct LingdongTicketClipApp: App {
    @StateObject private var launchModel = TicketClipLaunchModel()

    var body: some Scene {
        WindowGroup {
            TicketClipRootView(launchModel: launchModel)
        }
    }
}
