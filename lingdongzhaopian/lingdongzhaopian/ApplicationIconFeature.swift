import SwiftUI
import UIKit

enum ApplicationIconChoice: String, CaseIterable, Identifiable {
    case original, ribbon, halo, journal, origami
    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "原始图标".appLocalized
        case .ribbon: "流彩丝带".appLocalized
        case .halo: "虹光环带".appLocalized
        case .journal: "光影手札".appLocalized
        case .origami: "折纸流光".appLocalized
        }
    }

    var alternateName: String? {
        switch self {
        case .original: nil
        case .ribbon: "AppIconRibbon"
        case .halo: "AppIconHalo"
        case .journal: "AppIconJournal"
        case .origami: "AppIconOrigami"
        }
    }

    var previewAsset: String {
        switch self {
        case .original: "LingdongAppIcon"
        case .ribbon: "AppIconPreviewRibbon"
        case .halo: "AppIconPreviewHalo"
        case .journal: "AppIconPreviewJournal"
        case .origami: "AppIconPreviewOrigami"
        }
    }

    static func current(named alternateName: String?) -> Self {
        allCases.first { $0.alternateName == alternateName } ?? .original
    }
}

enum ApplicationIconError: LocalizedError {
    case requiresPro, unavailable, inactive, busy
    var errorDescription: String? {
        switch self {
        case .requiresPro: "支持我们后，即可解锁全部应用图标。".appLocalized
        case .unavailable: "当前设备暂不支持更换应用图标。".appLocalized
        case .inactive: "请返回应用后再更换图标。".appLocalized
        case .busy: "正在更换图标，请稍候。".appLocalized
        }
    }
}


@MainActor @Observable
final class ApplicationIconStore {
    static let shared = ApplicationIconStore()
    private(set) var selected = ApplicationIconChoice.current(named: UIApplication.shared.alternateIconName)
    private(set) var isChanging = false

    func refresh() {
        selected = .current(named: UIApplication.shared.alternateIconName)
    }

    func change(to icon: ApplicationIconChoice, hasPro: Bool) async throws {
        guard hasPro || icon == .original else { throw ApplicationIconError.requiresPro }
        guard !isChanging else { throw ApplicationIconError.busy }
        guard UIApplication.shared.supportsAlternateIcons else { throw ApplicationIconError.unavailable }
        guard UIApplication.shared.applicationState == .active else { throw ApplicationIconError.inactive }
        refresh()
        guard selected != icon else { return }
        isChanging = true
        defer { isChanging = false }
        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateName)
            refresh()
        } catch {
            refresh()
            throw error
        }
    }
}

struct CurrentApplicationIcon: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ApplicationIconStore.shared

    var body: some View {
        Image(store.selected.previewAsset)
            .resizable().scaledToFit()
            .accessibilityLabel(store.selected.title)
            .accessibilityIdentifier("appIcon.current")
            .onAppear { store.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.refresh() }
            }
    }
}

struct ApplicationIconPicker: View {
    @AppStorage("supporterUnlocked") private var supporterUnlocked = false
    @AppStorage("poeticNamesEnabled") private var poeticNamesEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = ApplicationIconStore.shared
    @State private var unlockPrompt = false
    @State private var unlockPromptDismissTask: Task<Void, Never>?
    @State private var supportPresented = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 8) {
                    Text("选择喜欢的图标，让灵动照片多一种模样。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ProBadge(compact: true)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 24)], spacing: 28) {
                    ForEach(ApplicationIconChoice.allCases) { icon in
                        iconButton(icon)
                    }
                }
                if store.isChanging { ProgressView("正在更换图标…") }
            }
            .padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
            .padding(.bottom, unlockPrompt ? 110 : 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("更换应用图标")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { store.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refresh() } }
        .onChange(of: supporterUnlocked) { _, unlocked in
            if unlocked {
                unlockPromptDismissTask?.cancel()
                unlockPrompt = false
                supportPresented = false
            }
        }
        .overlay(alignment: .bottom) {
            if unlockPrompt && !supporterUnlocked {
                SupporterProUnlockPrompt(message: "支持我们后，即可解锁全部应用图标。") {
                    unlockPromptDismissTask?.cancel()
                    unlockPrompt = false
                    supportPresented = true
                }
                .padding(20)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .accessibilityIdentifier("appIcon.unlockPrompt")
            }
        }
        .onDisappear {
            unlockPromptDismissTask?.cancel()
        }
        .fullScreenCover(isPresented: $supportPresented) {
            SupportUsView {
                poeticNamesEnabled = true
            }
        }
        .alert("更换图标失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func iconButton(_ icon: ApplicationIconChoice) -> some View {

        let locked = !supporterUnlocked && icon != .original
        return Button {
            guard !locked else {
                unlockPromptDismissTask?.cancel()
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) { unlockPrompt = true }
                unlockPromptDismissTask = Task {
                    try? await Task.sleep(for: .seconds(6))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.22)) { unlockPrompt = false }
                }
                return
            }
            Task {
                do { try await store.change(to: icon, hasPro: supporterUnlocked) }
                catch { self.error = error.localizedDescription }
            }
        } label: {
            VStack(spacing: 10) {
                Image(icon.previewAsset).resizable().scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    .overlay {
                        if locked {
                            Image(systemName: "lock.fill").font(.system(size: 23, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.78), in: Circle())
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .stroke(store.selected == icon ? Color.accentColor.opacity(0.65) : .primary.opacity(0.08), lineWidth: store.selected == icon ? 2 : 0.5)
                    }
                Text(icon.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(store.selected == icon ? "当前使用".appLocalized : " ")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(store.isChanging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(icon.title)
        .accessibilityValue((!locked ? (store.selected == icon ? "当前使用" : "可更换") : "需要支持者 PRO").appLocalized)
        .accessibilityIdentifier("appIcon.choice.\(icon.rawValue)")
    }
}
