import SwiftUI

struct TicketPressStyle: ButtonStyle {
    var scale: CGFloat = 0.93
    var tilt: Double = -1.2

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .rotationEffect(.degrees(configuration.isPressed ? tilt : 0))
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct TicketStatusBadges: View {
    let ticket: TicketStub
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            if ticket.isSealed {
                badge(icon: "checkmark.seal.fill", text: "已封印",
                      color: Color(red: 0.16, green: 0.60, blue: 0.38))
            }
            if ticket.isCapsule {
                badge(icon: "hourglass", text: "时光胶囊",
                      color: Color(red: 0.72, green: 0.45, blue: 0.15))
            }
        }
    }

    private func badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: compact ? 8 : 9))
            Text(text.appLocalized).font(.system(size: compact ? 9 : 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 7 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}
