// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import ActivityKit
import SwiftUI
import WidgetKit

struct TicketRevealLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TicketRevealActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(context.primaryColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text(context.state.phase.title)
                        .font(.headline)
                    Text(context.attributes.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: context.state.progress)
                        .tint(context.primaryColor)
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
                        .foregroundStyle(context.primaryColor)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phase.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.title)
                        .font(.caption.bold())
                        .foregroundStyle(context.secondaryColor)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 7) {
                        ProgressView(value: context.state.progress)
                            .tint(context.primaryColor)
                        Text(context.attributes.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(context.primaryColor)
            } compactTrailing: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.secondaryColor)
            } minimal: {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(context.primaryColor)
            }
            .keylineTint(context.primaryColor)
        }
    }
}

private extension ActivityViewContext where Attributes == TicketRevealActivityAttributes {
    var primaryColor: Color {
        Color(ticketHex: attributes.primaryHex)
    }

    var secondaryColor: Color {
        Color(ticketHex: attributes.secondaryHex)
    }
}

private extension TicketRevealActivityPhase {
    var title: String {
        switch self {
        case .preparing: "正在识别票根"
        case .revealing: "正在展开回忆"
        case .verified: "票根已验证"
        }
    }

    var symbol: String {
        switch self {
        case .preparing: "ellipsis"
        case .revealing: "arrow.down"
        case .verified: "checkmark"
        }
    }
}

private extension Color {
    init(ticketHex: String) {
        let normalized = ticketHex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(normalized, radix: 16) ?? 0x34735E
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
