// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

enum LiquidGlassVariant {
    case regular
    case clear
}

extension View {
    @ViewBuilder
    func liquidGlass<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false,
        variant: LiquidGlassVariant = .regular
    ) -> some View {
        if #available(iOS 26.0, *) {
            if variant == .clear {
                if interactive {
                    self.glassEffect(.clear.interactive(), in: shape)
                } else {
                    self.glassEffect(.clear, in: shape)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: shape)
                } else {
                    self.glassEffect(.regular, in: shape)
                }
            }
        } else {
            self
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay {
                            shape.stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.72), .white.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        }
                }
                .clipShape(shape)
                .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        }
    }
}

struct LiquidCircleButton: View {
    let symbol: String
    var isEnabled = true
    var isBusy = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView()
                        .tint(.primary)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Circle())
        }
        .buttonStyle(LiquidPressButtonStyle())
        .liquidGlass(in: Circle(), interactive: true, variant: .clear)
        .opacity(isEnabled ? 1 : 0.24)
        .disabled(!isEnabled || isBusy)
        .accessibilityLabel(accessibilityName)
    }

    private var accessibilityName: String {
        switch symbol {
        case "plus": "添加照片"
        case "minus": "移除末张照片"
        case "arrow.down": "保存照片"
        case "checkmark": "保存成功"
        case "gearshape": "设置"
        case "arrow.uturn.backward": "撤销上一步"
        default: symbol
        }
    }
}

struct LiquidPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(configuration.isPressed ? .white.opacity(0.46) : .clear)
            }
            .brightness(configuration.isPressed ? 0.10 : 0)
            .scaleEffect(configuration.isPressed ? 0.89 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -1.4 : 0))
            .animation(.spring(response: 0.24, dampingFraction: 0.66), value: configuration.isPressed)
    }
}

struct AmbientBackground: View {
    let palette: [RGBColor]

    private var colors: [RGBColor] {
        palette.isEmpty ? RGBColor.fallback : palette
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        colors[0].adjusted(brightness: 0.18, saturation: 0.08).color,
                        colors[min(1, colors.count - 1)].adjusted(brightness: 0.08).color,
                        colors[min(2, colors.count - 1)].adjusted(brightness: 0.12).color
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(colors[min(3, colors.count - 1)].color.opacity(0.42))
                    .frame(width: proxy.size.width * 0.94)
                    .blur(radius: 80)
                    .offset(x: -proxy.size.width * 0.34, y: proxy.size.height * 0.30)

                Circle()
                    .fill(colors[min(2, colors.count - 1)].adjusted(brightness: 0.22).color.opacity(0.55))
                    .frame(width: proxy.size.width * 0.8)
                    .blur(radius: 72)
                    .offset(x: proxy.size.width * 0.42, y: -proxy.size.height * 0.28)

                LinearGradient(
                    colors: [.white.opacity(0.18), .clear, .black.opacity(0.07)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct FreeNoticeOverlay: View {
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.20)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.24))
                        .frame(width: 68, height: 68)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 34, weight: .medium))
                }

                VStack(spacing: 8) {
                    Text("灵动照片 · 完全免费")
                        .font(.title3.bold())
                    Text("本应用不收取任何订阅或功能费用。\n谨防付费下载、代购或订阅骗局。")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }

                Button("我知道了", action: dismiss)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.black, in: Capsule())
            }
            .padding(26)
            .frame(maxWidth: 330)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .zIndex(100)
    }
}

struct FreePromisePill: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.seal.fill")
            Text("完全免费 · 谨防被骗")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .liquidGlass(in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
