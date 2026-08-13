// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LingdongTicketActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        TicketPrintLiveActivityWidget()
        TicketRevealLiveActivityWidget()
    }
}

struct TicketPrintLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TicketPrintActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.state.phase.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(context.state.phase.tint)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(context.state.phase.title)
                        .font(.headline)
                    Text(context.attributes.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: context.state.progress)
                        .tint(context.state.phase.tint)
                }
            }
            .padding(.horizontal, 16)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phase.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.phase.symbol)
                        .foregroundStyle(context.state.phase.tint)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 7) {
                        ProgressView(value: context.state.progress)
                            .tint(context.state.phase.tint)
                        Text(context.attributes.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.state.phase.tint)
            } minimal: {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }
}

private extension TicketPrintActivityPhase {
    var title: String {
        switch self {
        case .preparing: "正在制作票根"
        case .printing: "正在出票"
        case .saving: "正在保存"
        case .completed: "出票完成"
        case .failed: "出票失败"
        }
    }

    var symbol: String {
        switch self {
        case .preparing: "ellipsis"
        case .printing: "arrow.down"
        case .saving: "photo.badge.arrow.down"
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .completed: .green
        case .failed: .orange
        default: .white
        }
    }
}
