// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

enum PrototypeGlassVariant {
    case regular
    case clear
}

extension View {
    @ViewBuilder
    func prototypeGlass<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false,
        variant: PrototypeGlassVariant = .regular
    ) -> some View {
        if #available(iOS 26.0, *) {
            if variant == .clear {
                if interactive {
                    glassEffect(.clear.interactive(), in: shape)
                } else {
                    glassEffect(.clear, in: shape)
                }
            } else if interactive {
                glassEffect(.regular.interactive(), in: shape)
            } else {
                glassEffect(.regular, in: shape)
            }
        } else {
            background {
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

struct PrototypePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle().fill(configuration.isPressed ? .white.opacity(0.46) : .clear)
            }
            .brightness(configuration.isPressed ? 0.10 : 0)
            .scaleEffect(configuration.isPressed ? 0.89 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -1.4 : 0))
            .animation(.spring(response: 0.24, dampingFraction: 0.66), value: configuration.isPressed)
    }
}

struct PrototypeCircleButton: View {
    let symbol: String
    var isBusy = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView().tint(.primary)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Circle())
        }
        .buttonStyle(PrototypePressButtonStyle())
        .prototypeGlass(in: Circle(), interactive: true, variant: .clear)
        .disabled(isBusy)
    }
}

struct PrototypeAmbientBackground: View {
    let colors: [PaletteColor]

    private var resolved: [PaletteColor] {
        if colors.isEmpty {
            return [
                PaletteColor(red: 0.18, green: 0.39, blue: 0.24, weight: 1),
                PaletteColor(red: 0.14, green: 0.31, blue: 0.21, weight: 1),
                PaletteColor(red: 0.24, green: 0.45, blue: 0.28, weight: 1),
                PaletteColor(red: 0.10, green: 0.24, blue: 0.18, weight: 1)
            ]
        }
        return colors
    }

    var body: some View {
        GeometryReader { proxy in
            let palette = resolved
            ZStack {
                LinearGradient(
                    colors: [
                        adjusted(palette[0], brightness: 0.18, saturation: 0.08).color,
                        adjusted(palette[min(1, palette.count - 1)], brightness: 0.08).color,
                        adjusted(palette[min(2, palette.count - 1)], brightness: 0.12).color
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(palette[min(3, palette.count - 1)].color.opacity(0.42))
                    .frame(width: proxy.size.width * 0.94)
                    .blur(radius: 80)
                    .offset(x: -proxy.size.width * 0.34, y: proxy.size.height * 0.30)
                Circle()
                    .fill(adjusted(palette[min(2, palette.count - 1)], brightness: 0.22).color.opacity(0.55))
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

    private func adjusted(
        _ color: PaletteColor,
        brightness: Double = 0,
        saturation: Double = 0
    ) -> PaletteColor {
        let average = (color.red + color.green + color.blue) / 3
        let factor = 1 + saturation
        return PaletteColor(
            red: min(max(average + (color.red - average) * factor + brightness, 0), 1),
            green: min(max(average + (color.green - average) * factor + brightness, 0), 1),
            blue: min(max(average + (color.blue - average) * factor + brightness, 0), 1),
            weight: color.weight
        )
    }
}

struct PrototypeModeGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.65, green: 0.92, blue: 0.69).opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 18)
            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 1)
                .frame(width: 106, height: 106)
            HStack(spacing: -8) {
                Circle().fill(Color(red: 0.86, green: 0.55, blue: 0.39)).frame(width: 46, height: 46)
                Circle().fill(Color(red: 0.29, green: 0.55, blue: 0.59)).frame(width: 46, height: 46)
            }
            .overlay {
                Circle()
                    .fill(.white.opacity(0.84))
                    .frame(width: 14, height: 14)
            }
        }
    }
}
