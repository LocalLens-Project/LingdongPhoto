import SwiftUI

struct SceneArtView: View {
    let theme: SceneTheme
    var seed: UInt64 = 7

    var body: some View {
        LinearGradient(colors: theme.skyGradient, startPoint: .top, endPoint: .bottom)
            .overlay {
                Canvas { context, size in
                    switch theme {
                    case .sunset: drawSunset(context, size)
                    case .sea: drawSea(context, size)
                    case .forest: drawForest(context, size)
                    case .nightCity: drawNightCity(context, size)
                    case .snowMountain: drawSnowMountain(context, size)
                    case .sakura: drawSakura(context, size)
                    case .desert: drawDesert(context, size)
                    case .aurora: drawAurora(context, size)
                    }
                }
            }
            .overlay {

                RadialGradient(colors: [.clear, .black.opacity(0.18)],
                               center: .center, startRadius: 60, endRadius: 420)
            }
    }

    private func drawSunset(_ ctx: GraphicsContext, _ size: CGSize) {
        var sun = ctx
        sun.addFilter(.blur(radius: 6))
        let sunR = min(size.width, size.height) * 0.20
        let sunRect = CGRect(x: size.width * 0.5 - sunR, y: size.height * 0.38 - sunR,
                             width: sunR * 2, height: sunR * 2)
        sun.fill(Path(ellipseIn: sunRect), with: .color(Color(red: 1.0, green: 0.93, blue: 0.78).opacity(0.95)))

        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: size.height))
        hills.addQuadCurve(to: CGPoint(x: size.width * 0.55, y: size.height),
                           control: CGPoint(x: size.width * 0.25, y: size.height * 0.66))
        hills.addQuadCurve(to: CGPoint(x: size.width, y: size.height),
                           control: CGPoint(x: size.width * 0.85, y: size.height * 0.74))
        hills.closeSubpath()
        ctx.fill(hills, with: .color(theme.silhouette.opacity(0.9)))
    }

    private func drawSea(_ ctx: GraphicsContext, _ size: CGSize) {
        let horizonY = size.height * 0.52
        var glow = ctx
        glow.addFilter(.blur(radius: 4))
        glow.fill(Path(CGRect(x: size.width * 0.30, y: horizonY - 3,
                              width: size.width * 0.40, height: 6)),
                  with: .color(.white.opacity(0.8)))

        var rng = SeededGenerator(seed: seed)
        for i in 0..<9 {
            let y = horizonY + CGFloat(i + 1) / 10 * (size.height - horizonY)
            let width = CGFloat(20 + rng.unit() * 60)
            let x = CGFloat(rng.unit()) * (size.width - width)
            var wave = Path()
            wave.move(to: CGPoint(x: x, y: y))
            wave.addQuadCurve(to: CGPoint(x: x + width, y: y),
                              control: CGPoint(x: x + width / 2, y: y - 2.5))
            ctx.stroke(wave, with: .color(.white.opacity(0.28 + 0.05 * Double(i))), lineWidth: 1.4)
        }
    }

    private func drawForest(_ ctx: GraphicsContext, _ size: CGSize) {
        var sun = ctx
        sun.addFilter(.blur(radius: 5))
        sun.fill(Path(ellipseIn: CGRect(x: size.width * 0.68, y: size.height * 0.12,
                                        width: 26, height: 26)),
                 with: .color(.white.opacity(0.85)))

        let layers: [(y: CGFloat, alpha: Double, count: Int)] = [
            (0.58, 0.45, 5), (0.72, 0.70, 4), (0.88, 0.95, 3)
        ]
        var rng = SeededGenerator(seed: seed)
        for layer in layers {
            for i in 0..<layer.count {
                let x = size.width * (CGFloat(i) + CGFloat(rng.unit()) * 0.8 + 0.1) / CGFloat(layer.count)
                let treeH = size.height * CGFloat(0.16 + rng.unit() * 0.12) * (layer.y / 0.8)
                let treeW = treeH * 0.55
                var tree = Path()
                tree.move(to: CGPoint(x: x, y: size.height * layer.y - treeH))
                tree.addLine(to: CGPoint(x: x - treeW / 2, y: size.height * layer.y))
                tree.addLine(to: CGPoint(x: x + treeW / 2, y: size.height * layer.y))
                tree.closeSubpath()
                ctx.fill(tree, with: .color(theme.silhouette.opacity(layer.alpha)))
            }
            ctx.fill(Path(CGRect(x: 0, y: size.height * layer.y - 2,
                                 width: size.width, height: size.height)),
                     with: .color(theme.silhouette.opacity(layer.alpha * 0.8)))
        }
    }

    private func drawNightCity(_ ctx: GraphicsContext, _ size: CGSize) {
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<36 {
            let x = CGFloat(rng.unit()) * size.width
            let y = CGFloat(rng.unit()) * size.height * 0.5
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                     with: .color(.white.opacity(0.25 + rng.unit() * 0.55)))
        }
        var moon = ctx
        moon.addFilter(.blur(radius: 3))
        moon.fill(Path(ellipseIn: CGRect(x: size.width * 0.74, y: size.height * 0.10,
                                         width: 30, height: 30)),
                  with: .color(Color(red: 0.98, green: 0.95, blue: 0.82).opacity(0.95)))

        var x: CGFloat = 0
        while x < size.width {
            let buildingW = CGFloat(16 + rng.unit() * 26)
            let buildingH = size.height * CGFloat(0.20 + rng.unit() * 0.34)
            let rect = CGRect(x: x, y: size.height - buildingH, width: buildingW, height: buildingH)
            ctx.fill(Path(rect), with: .color(theme.silhouette))
            for _ in 0..<Int(buildingW * buildingH / 130) {
                let wx = rect.minX + 3 + CGFloat(rng.unit()) * (rect.width - 6)
                let wy = rect.minY + 4 + CGFloat(rng.unit()) * (rect.height - 8)
                ctx.fill(Path(CGRect(x: wx, y: wy, width: 2.2, height: 3)),
                         with: .color(Color(red: 1.0, green: 0.82, blue: 0.45).opacity(0.5 + rng.unit() * 0.5)))
            }
            x += buildingW + 2
        }
    }

    private func drawSnowMountain(_ ctx: GraphicsContext, _ size: CGSize) {
        func peak(cx: CGFloat, base: CGFloat, height: CGFloat, width: CGFloat,
                  color: Color) {
            var p = Path()
            p.move(to: CGPoint(x: cx, y: base - height))
            p.addLine(to: CGPoint(x: cx - width / 2, y: base))
            p.addLine(to: CGPoint(x: cx + width / 2, y: base))
            p.closeSubpath()
            ctx.fill(p, with: .color(color))
            var cap = Path()
            cap.move(to: CGPoint(x: cx, y: base - height))
            cap.addLine(to: CGPoint(x: cx - width * 0.16, y: base - height * 0.62))
            cap.addQuadCurve(to: CGPoint(x: cx + width * 0.16, y: base - height * 0.62),
                             control: CGPoint(x: cx, y: base - height * 0.52))
            cap.closeSubpath()
            ctx.fill(cap, with: .color(.white.opacity(0.92)))
        }
        peak(cx: size.width * 0.28, base: size.height, height: size.height * 0.52,
             width: size.width * 0.70, color: Color(red: 0.72, green: 0.80, blue: 0.91))
        peak(cx: size.width * 0.76, base: size.height, height: size.height * 0.66,
             width: size.width * 0.80, color: Color(red: 0.56, green: 0.67, blue: 0.84))
        peak(cx: size.width * 0.52, base: size.height, height: size.height * 0.34,
             width: size.width * 0.60, color: theme.silhouette.opacity(0.85))
    }

    private func drawSakura(_ ctx: GraphicsContext, _ size: CGSize) {
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<42 {
            let x = CGFloat(rng.unit()) * size.width
            let y = CGFloat(rng.unit()) * size.height
            let r = CGFloat(1.5 + rng.unit() * 3.5)
            var petal = ctx
            petal.translateBy(x: x, y: y)
            petal.rotate(by: .degrees(rng.unit() * 360))
            petal.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.6, width: r * 2, height: r * 1.2)),
                       with: .color(Color(red: 1.0, green: 0.86, blue: 0.90).opacity(0.35 + rng.unit() * 0.5)))
        }
        var branch = Path()
        branch.move(to: CGPoint(x: -4, y: size.height * 0.18))
        branch.addQuadCurve(to: CGPoint(x: size.width * 0.52, y: size.height * 0.30),
                            control: CGPoint(x: size.width * 0.24, y: size.height * 0.12))
        ctx.stroke(branch, with: .color(theme.silhouette.opacity(0.8)),
                   style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    private func drawDesert(_ ctx: GraphicsContext, _ size: CGSize) {
        var sun = ctx
        sun.addFilter(.blur(radius: 5))
        sun.fill(Path(ellipseIn: CGRect(x: size.width * 0.30 - 22, y: size.height * 0.20 - 22,
                                        width: 44, height: 44)),
                 with: .color(Color(red: 1.0, green: 0.90, blue: 0.66).opacity(0.95)))

        let dune1 = CGRect(x: -size.width * 0.5, y: size.height * 0.62,
                           width: size.width * 1.4, height: size.height * 1.2)
        ctx.fill(Path(ellipseIn: dune1), with: .color(theme.silhouette.opacity(0.75)))
        let dune2 = CGRect(x: size.width * 0.12, y: size.height * 0.80,
                           width: size.width * 1.5, height: size.height * 1.2)
        ctx.fill(Path(ellipseIn: dune2), with: .color(theme.silhouette.opacity(0.95)))
    }

    private func drawAurora(_ ctx: GraphicsContext, _ size: CGSize) {
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<30 {
            let x = CGFloat(rng.unit()) * size.width
            let y = CGFloat(rng.unit()) * size.height * 0.6
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                     with: .color(.white.opacity(0.2 + rng.unit() * 0.6)))
        }
        let bands: [(hue: Color, phase: Double, width: CGFloat)] = [
            (Color(red: 0.30, green: 0.85, blue: 0.62), 0.0, size.width * 0.16),
            (Color(red: 0.45, green: 0.80, blue: 0.85), 1.6, size.width * 0.12),
            (Color(red: 0.55, green: 0.70, blue: 0.95), 3.1, size.width * 0.10),
        ]
        for band in bands {
            var aurora = ctx
            aurora.addFilter(.blur(radius: 8))
            var p = Path()
            let steps = 24
            p.move(to: CGPoint(x: 0, y: size.height * 0.18))
            for i in 1...steps {
                let t = Double(i) / Double(steps)
                let x = CGFloat(t) * size.width
                let y = size.height * (0.18 + 0.16 * CGFloat(sin(t * .pi * 2 + band.phase)))
                p.addLine(to: CGPoint(x: x, y: y))
            }
            for i in stride(from: steps, through: 0, by: -1) {
                let t = Double(i) / Double(steps)
                let x = CGFloat(t) * size.width
                let y = size.height * (0.18 + 0.16 * CGFloat(sin(t * .pi * 2 + band.phase))) + band.width
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.closeSubpath()
            aurora.fill(p, with: .color(band.hue.opacity(0.45)))
        }
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: size.height))
        ground.addQuadCurve(to: CGPoint(x: size.width, y: size.height),
                            control: CGPoint(x: size.width * 0.5, y: size.height * 0.78))
        ground.closeSubpath()
        ctx.fill(ground, with: .color(theme.silhouette))
    }
}
