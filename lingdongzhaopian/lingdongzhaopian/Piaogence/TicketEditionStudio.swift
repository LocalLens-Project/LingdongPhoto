import SwiftUI

struct TicketEditionEntryButton: View {
    let edition: TicketEdition
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: edition.symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text("票面 · \(edition.shortTitle)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .black))
                    .opacity(0.58)
            }
            .foregroundStyle(.primary.opacity(0.82))
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.68), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更换票面，当前为\(edition.title)")
    }
}

struct TicketEditionStudio: View {
    let ticket: TicketStub
    let currentEdition: TicketEdition
    var onApply: (TicketEdition) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @AppStorage("poeticNamesEnabled") private var poeticNamesEnabled = false
    @State private var selection: TicketEdition
    @State private var supportPresented = false

    init(
        ticket: TicketStub,
        currentEdition: TicketEdition,
        onApply: @escaping (TicketEdition) -> Void
    ) {
        self.ticket = ticket
        self.currentEdition = currentEdition
        self.onApply = onApply
        _selection = State(initialValue: currentEdition)
    }

    private var previewTicket: TicketStub {
        var copy = ticket
        copy.ticketEdition = selection
        return copy
    }

    private var accent: Color {
        (ticket.palette.first ?? PiaogenceRGBColor.fallback[0]).color
    }

    var body: some View {
        ZStack {
            studioBackground

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                Spacer(minLength: 18)
                    .frame(maxHeight: 80)

                preview
                    .padding(.horizontal, 20)

                Spacer(minLength: 22)

                editionRail
                    .padding(.horizontal, 18)

                actionButton
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 18)
            }
        }
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $supportPresented) {
            SupportUsView {
                poeticNamesEnabled = true
            }
        }
    }

    private var studioBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.965, green: 0.95, blue: 0.925),
                Color(red: 0.90, green: 0.925, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 78)
                .offset(x: 96, y: -122)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color(red: 0.78, green: 0.54, blue: 0.47).opacity(0.10))
                .frame(width: 250, height: 250)
                .blur(radius: 72)
                .offset(x: -100, y: 100)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.68))
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.66), lineWidth: 0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("票面工坊")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                Text("为这一张记忆票选择版本")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
    }

    private var preview: some View {
        VStack(spacing: 13) {
            ZStack {
                TicketArtworkView(ticket: previewTicket)
                    .frame(maxWidth: ticket.layout == .vertical ? 292 : 520)
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.22), radius: 24, y: 15)

                if selection == .collector && !supporterUnlocked {
                    Text("典藏预览")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.46), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 0.6))
                }
            }
            .animation(.spring(response: 0.46, dampingFraction: 0.84), value: selection)

            Text(selection == .standard
                 ? "保留清爽的信息层级与票型辨识".appLocalized
                 : "矿物箔色取自原票，随票型生成专属纹样".appLocalized)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
    }

    private var editionRail: some View {
        HStack(spacing: 10) {
            ForEach(TicketEdition.allCases) { edition in
                editionOption(edition)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous)
            .stroke(.white.opacity(0.70), lineWidth: 0.7))
    }

    private func editionOption(_ edition: TicketEdition) -> some View {
        let selected = selection == edition
        return Button {
            withAnimation(.snappy(duration: 0.34)) { selection = edition }
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(selected ? Color.white.opacity(0.72) : Color.black.opacity(0.045))
                    Image(systemName: edition.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? Color(red: 0.19, green: 0.42, blue: 0.47) : .secondary)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(edition.title)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        if edition == .collector { ProBadge(compact: true) }
                    }
                    Text((edition == .standard ? "标准功能" : "支持者礼物").appLocalized)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(selected ? Color.white.opacity(0.62) : .clear,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.82), lineWidth: 0.7)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var actionButton: some View {
        Button {
            if selection == .collector && !supporterUnlocked {
                supportPresented = true
            } else {
                onApply(selection)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selection == .collector && !supporterUnlocked
                      ? "heart.fill" : "checkmark")
                Text(actionTitle)
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.22, green: 0.47, blue: 0.51),
                             Color(red: 0.64, green: 0.43, blue: 0.39)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private var actionTitle: String {
        if selection == .collector && !supporterUnlocked {
            return "支持我们，启用典藏票面".appLocalized
        }
        if selection == currentEdition {
            return "保留当前票面".appLocalized
        }
        return String(format: "应用%@".appLocalized, selection.title)
    }
}
