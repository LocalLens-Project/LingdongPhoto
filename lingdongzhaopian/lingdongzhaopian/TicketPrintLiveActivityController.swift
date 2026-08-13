// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ActivityKit
import Foundation

@MainActor
final class TicketPrintLiveActivityController {
    static let shared = TicketPrintLiveActivityController()

    private var activity: Activity<TicketPrintActivityAttributes>?

    private init() {}

    func start(title: String) async -> Bool {
        for existingActivity in Activity<TicketPrintActivityAttributes>.activities {
            await existingActivity.end(nil, dismissalPolicy: .immediate)
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activity = nil
            return false
        }

        let attributes = TicketPrintActivityAttributes(title: title)
        let state = TicketPrintActivityAttributes.ContentState(
            phase: .preparing,
            progress: 0.05
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date.now.addingTimeInterval(60),
            relevanceScore: 100
        )

        do {
            if #available(iOS 18.0, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil,
                    style: .transient
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            }
            return true
        } catch {
            activity = nil
            return false
        }
    }

    func update(phase: TicketPrintActivityPhase, progress: Double) async {
        guard let activity else { return }
        let state = TicketPrintActivityAttributes.ContentState(
            phase: phase,
            progress: min(max(progress, 0), 1)
        )
        await activity.update(
            ActivityContent(
                state: state,
                staleDate: Date.now.addingTimeInterval(60),
                relevanceScore: 100
            )
        )
    }

    func end(phase: TicketPrintActivityPhase, progress: Double) async {
        guard let activity else { return }
        let state = TicketPrintActivityAttributes.ContentState(
            phase: phase,
            progress: min(max(progress, 0), 1)
        )
        let content = ActivityContent(
            state: state,
            staleDate: nil,
            relevanceScore: 100
        )
        await activity.end(content, dismissalPolicy: .immediate)
        self.activity = nil
    }

    func cancel() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
