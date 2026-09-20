// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ActivityKit
import SwiftUI
import UIKit

@MainActor
enum TicketRevealIslandSupport {
    /// Height of the hardware Dynamic Island pill.
    static let islandHeight: CGFloat = 37

    static var isSupported: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        if currentWindow?.safeAreaInsets.top ?? 0 >= 51 {
            return true
        }
        let bounds = currentWindow?.windowScene?.screen.bounds ?? .zero
        let size = (Int(bounds.width.rounded()), Int(bounds.height.rounded()))
        return [(393, 852), (402, 874), (420, 912), (430, 932), (440, 956)]
            .contains { $0 == size }
    }

    /// Bottom edge of the hardware Dynamic Island in screen coordinates.
    ///
    /// The pill sits 11pt above the safe-area boundary on every Dynamic
    /// Island iPhone, but the safe-area inset itself varies per model
    /// (59pt on iPhone 14 Pro / 15 / 16, 62pt on iPhone 16 Pro / 17
    /// series, ...), so the island bottom moves with it (48pt vs 51pt).
    /// Derive the outlet from the live inset instead of a fixed constant,
    /// otherwise the drawn bar drifts above or below the real island.
    static var outletBottom: CGFloat {
        let topInset = currentWindow?.safeAreaInsets.top ?? 0
        if topInset >= 51 {
            return topInset - 11
        }
        // Window not laid out yet: fall back to the known inset for the
        // current screen size. 402x874 covers iPhone 16 Pro / 17 / 17 Pro,
        // 420x912 is iPhone Air whose island sits even lower.
        let bounds = currentWindow?.windowScene?.screen.bounds ?? .zero
        let size = (Int(bounds.width.rounded()), Int(bounds.height.rounded()))
        switch size {
        case (402, 874), (440, 956):
            return 51
        case (420, 912):
            return 57
        default:
            return 48
        }
    }

    private static var currentWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

@MainActor
final class TicketRevealLiveActivityController {
    static let shared = TicketRevealLiveActivityController()

    private var activity: Activity<TicketRevealActivityAttributes>?

    private init() {}

    func start(
        title: String,
        primaryHex: String?,
        secondaryHex: String?
    ) async -> Bool {
        guard #available(iOS 18.0, *),
              TicketRevealIslandSupport.isSupported,
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            return false
        }

        for existingActivity in Activity<TicketRevealActivityAttributes>.activities {
            await existingActivity.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = TicketRevealActivityAttributes(
            title: title,
            primaryHex: primaryHex ?? "34735E",
            secondaryHex: secondaryHex ?? "5145CD"
        )
        let state = TicketRevealActivityAttributes.ContentState(
            phase: .preparing,
            progress: 0.05
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: Date.now.addingTimeInterval(20),
                    relevanceScore: 100
                ),
                pushType: nil
            )
            return true
        } catch {
            activity = nil
            return false
        }
    }

    func update(
        phase: TicketRevealActivityPhase,
        progress: Double
    ) async {
        guard let activity else { return }
        await activity.update(content(phase: phase, progress: progress))
    }

    func end(
        phase: TicketRevealActivityPhase,
        progress: Double
    ) async {
        guard let activity else { return }
        await activity.end(
            content(phase: phase, progress: progress, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.activity = nil
    }

    func cancel() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }

    private func content(
        phase: TicketRevealActivityPhase,
        progress: Double,
        staleDate: Date? = Date.now.addingTimeInterval(20)
    ) -> ActivityContent<TicketRevealActivityAttributes.ContentState> {
        ActivityContent(
            state: .init(
                phase: phase,
                progress: min(max(progress, 0), 1)
            ),
            staleDate: staleDate,
            relevanceScore: 100
        )
    }
}
