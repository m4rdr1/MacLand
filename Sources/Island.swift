import AppKit
import CoreImage
import CoreText

let gColorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
private let gCIContext = CIContext(options: nil)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    return CGColor(colorSpace: gColorSpace, components: [r, g, b, a]) ?? CGColor(gray: 0, alpha: a)
}

func fillRounded(_ ctx: CGContext, _ r: CGRect, _ rad: CGFloat, _ c: CGColor, _ a: CGFloat) {
    if a <= 0.003 || r.width <= 0 || r.height <= 0 { return }
    ctx.setFillColor(c.copy(alpha: a) ?? c)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil))
    ctx.fillPath()
}

func sysFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    return NSFont.systemFont(ofSize: size, weight: weight)
}

enum Align { case left, center, right }

func attributedText(_ s: String, _ f: NSFont, _ c: CGColor, _ tracking: CGFloat) -> NSAttributedString {
    var attrs: [NSAttributedString.Key: Any] = [
        .font: f,
        .foregroundColor: NSColor(cgColor: c) ?? NSColor.white
    ]
    if tracking != 0 { attrs[.kern] = tracking }
    return NSAttributedString(string: s, attributes: attrs)
}

func metricWidth(_ line: CTLine) -> CGFloat {
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) + CGFloat(CTLineGetTrailingWhitespaceWidth(line))
}

func textWidth(_ s: String, _ f: NSFont, _ tracking: CGFloat = 0) -> CGFloat {
    if s.isEmpty { return 0 }
    return metricWidth(CTLineCreateWithAttributedString(attributedText(s, f, rgb(1, 1, 1), tracking)))
}

func drawText(_ ctx: CGContext, _ s: String, font f: NSFont, color: CGColor, alpha: CGFloat,
              rect: CGRect, align: Align = .left, tracking: CGFloat = 0, truncate: Bool = false) {
    if alpha <= 0.003 || s.isEmpty || rect.width <= 1 { return }
    let col = color.copy(alpha: alpha) ?? color
    var line = CTLineCreateWithAttributedString(attributedText(s, f, col, tracking))
    var w = metricWidth(line)
    if truncate && w > rect.width {
        let ell = CTLineCreateWithAttributedString(attributedText("…", f, col, tracking))
        if let t = CTLineCreateTruncatedLine(line, Double(rect.width), .end, ell) {
            line = t
            w = metricWidth(line)
        }
    }
    var x = rect.minX
    if align == .center { x = rect.midX - w * 0.5 }
    if align == .right { x = rect.maxX - w }
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    let baseline = rect.midY + (ascent - descent) * 0.5
    ctx.saveGState()
    ctx.translateBy(x: x, y: baseline)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textMatrix = .identity
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func fmtTime(_ s: Double) -> String {
    let t = Int(max(0, s))
    if t >= 3600 {
        return String(format: "%d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60)
    }
    return String(format: "%d:%02d", t / 60, t % 60)
}

let gBellPath: CGPath = {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -0.55, y: 0.30))
    p.addCurve(to: CGPoint(x: -0.32, y: -0.12), control1: CGPoint(x: -0.35, y: 0.22), control2: CGPoint(x: -0.32, y: 0.05))
    p.addCurve(to: CGPoint(x: 0, y: -0.55), control1: CGPoint(x: -0.32, y: -0.42), control2: CGPoint(x: -0.15, y: -0.55))
    p.addCurve(to: CGPoint(x: 0.32, y: -0.12), control1: CGPoint(x: 0.15, y: -0.55), control2: CGPoint(x: 0.32, y: -0.42))
    p.addCurve(to: CGPoint(x: 0.55, y: 0.30), control1: CGPoint(x: 0.32, y: 0.05), control2: CGPoint(x: 0.35, y: 0.22))
    p.closeSubpath()
    return p
}()

func drawBell(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, scale s: CGFloat, color: CGColor,
              alpha a: CGFloat, slash: CGFloat, bg: CGColor, ang: CGFloat) {
    if a <= 0.003 { return }
    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy)
    ctx.scaleBy(x: s, y: s)
    ctx.translateBy(x: 0, y: -0.6)
    ctx.rotate(by: ang * .pi / 180)
    ctx.translateBy(x: 0, y: 0.6)
    ctx.setFillColor(color.copy(alpha: a) ?? color)
    ctx.addPath(gBellPath)
    ctx.fillPath()
    ctx.fillEllipse(in: CGRect(x: -0.15, y: 0.33, width: 0.30, height: 0.20))
    ctx.fillEllipse(in: CGRect(x: -0.07, y: -0.67, width: 0.14, height: 0.14))
    if slash > 0.01 {
        let ex = lerpf(-0.62, 0.62, slash)
        let ey = lerpf(-0.55, 0.55, slash)
        ctx.setStrokeColor(bg.copy(alpha: a) ?? bg)
        ctx.setLineWidth(0.34)
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -0.62, y: -0.55))
        ctx.addLine(to: CGPoint(x: ex, y: ey))
        ctx.strokePath()
        ctx.setStrokeColor(color.copy(alpha: a) ?? color)
        ctx.setLineWidth(0.13)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -0.62, y: -0.55))
        ctx.addLine(to: CGPoint(x: ex, y: ey))
        ctx.strokePath()
    }
    ctx.restoreGState()
}

func drawSpeaker(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, alpha a: CGFloat, k: CGFloat) {
    if a <= 0.003 { return }
    let S = k
    let white = rgb(1, 1, 1)
    let pts = [
        CGPoint(x: cx - 7 * S, y: cy - 3 * S),
        CGPoint(x: cx - 3.5 * S, y: cy - 3 * S),
        CGPoint(x: cx + 1 * S, y: cy - 7 * S),
        CGPoint(x: cx + 1 * S, y: cy + 7 * S),
        CGPoint(x: cx - 3.5 * S, y: cy + 3 * S),
        CGPoint(x: cx - 7 * S, y: cy + 3 * S)
    ]
    ctx.setFillColor(white.copy(alpha: a) ?? white)
    ctx.beginPath()
    ctx.addLines(between: pts)
    ctx.closePath()
    ctx.fillPath()

    for i in 0..<3 {
        let w = clampf(Island.shared.waveAmt[i], 0, 1)
        if w < 0.01 { continue }
        let sweep = 90 * lerpf(0.45, 1.0, w) * .pi / 180
        let r = (5 + CGFloat(i) * 4) * S * lerpf(0.7, 1.0, w)
        ctx.setStrokeColor(white.copy(alpha: a * w) ?? white)
        ctx.setLineWidth(1.8 * S)
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.addArc(center: CGPoint(x: cx + 1 * S, y: cy), radius: r,
                   startAngle: -sweep / 2, endAngle: sweep / 2, clockwise: false)
        ctx.strokePath()
    }

    let m = clampf(Island.shared.muteAmt, 0, 1)
    if m > 0.01 {
        ctx.setStrokeColor(white.copy(alpha: a) ?? white)
        ctx.setLineWidth(2 * S)
        ctx.setLineCap(.round)
        let p1a = CGPoint(x: cx + 4 * S, y: cy - 4 * S)
        let p1b = CGPoint(x: lerpf(cx + 4 * S, cx + 12 * S, m), y: lerpf(cy - 4 * S, cy + 4 * S, m))
        let p2a = CGPoint(x: cx + 12 * S, y: cy - 4 * S)
        let p2b = CGPoint(x: lerpf(cx + 12 * S, cx + 4 * S, m), y: lerpf(cy - 4 * S, cy + 4 * S, m))
        ctx.beginPath()
        ctx.move(to: p1a)
        ctx.addLine(to: p1b)
        ctx.strokePath()
        ctx.beginPath()
        ctx.move(to: p2a)
        ctx.addLine(to: p2b)
        ctx.strokePath()
    }
}

func drawChevrons(_ ctx: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ dir: Int, _ color: CGColor, _ a: CGFloat) {
    if a <= 0.003 { return }
    let S: CGFloat = 1
    let w = 13 * S
    let h = 20 * S
    for i in 0..<2 {
        let xl = cx - w + CGFloat(i) * w
        let xr = xl + w
        let pts: [CGPoint]
        if dir < 0 {
            pts = [CGPoint(x: xr, y: cy - h / 2), CGPoint(x: xl, y: cy), CGPoint(x: xr, y: cy + h / 2)]
        } else {
            pts = [CGPoint(x: xl, y: cy - h / 2), CGPoint(x: xr, y: cy), CGPoint(x: xl, y: cy + h / 2)]
        }
        ctx.setFillColor(color.copy(alpha: a) ?? color)
        ctx.setStrokeColor(color.copy(alpha: a) ?? color)
        ctx.setLineWidth(3 * S)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.addLines(between: pts)
        ctx.closePath()
        ctx.drawPath(using: .fillStroke)
    }
}

func drawSearchIcon(_ ctx: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ color: CGColor, _ a: CGFloat) {
    if a <= 0.003 { return }
    let S: CGFloat = 1
    ctx.setStrokeColor(color.copy(alpha: a) ?? color)
    ctx.setLineWidth(2.3 * S)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(x: cx - 2 * S - 7 * S, y: cy - 2 * S - 7 * S, width: 14 * S, height: 14 * S))
    ctx.strokePath()
    ctx.setLineWidth(2.6 * S)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx + 3.2 * S, y: cy + 3.2 * S))
    ctx.addLine(to: CGPoint(x: cx + 9 * S, y: cy + 9 * S))
    ctx.strokePath()
}

func drawStar(_ ctx: CGContext, _ center: CGPoint, _ r: CGFloat, _ color: CGColor, _ a: CGFloat) {
    if a <= 0.003 { return }
    let p = CGMutablePath()
    for i in 0..<10 {
        let ang = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let rr = i % 2 == 0 ? r : r * 0.45
        let pt = CGPoint(x: center.x + rr * cos(ang), y: center.y + rr * sin(ang))
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    ctx.setFillColor(color.copy(alpha: a) ?? color)
    ctx.addPath(p)
    ctx.fillPath()
}

func drawCalendar(_ ctx: CGContext) {
    let I = Island.shared
    let l = I.lay
    let t = clampf(CGFloat(I.ex.x), 0, 1)
    let a = I.vCal * clampf((t - 0.48) / 0.4, 0, 1)
    if a <= 0.003 { return }

    let info = CalendarService.shared.info
    let S = I.S
    let white = rgb(1, 1, 1)

    drawText(ctx, info.weekday, font: sysFont(11 * S, .semibold), color: rgb(0.86, 0.42, 0.46),
             alpha: a, rect: l.calWeek, align: .left, tracking: 1.4)
    drawText(ctx, info.day, font: sysFont(45 * S, .regular), color: white,
             alpha: a * 0.98, rect: l.calDay, align: .left)

    if info.hasNext && !info.nextTitle.isEmpty {
        drawText(ctx, info.nextLabel, font: sysFont(10.5 * S, .semibold), color: rgb(0.60, 0.60, 0.64),
                 alpha: a, rect: l.calNext, align: .left, tracking: 1.2)

        let pf = sysFont(13.5 * S, .semibold)
        let textW = textWidth(info.nextTitle, pf, 0.2)
        let h: CGFloat = 18 * S
        let inset: CGFloat = 2.5 * S
        let pillW = min(textW + h + 36 * S, l.calNext.width)
        let pill = CGRect(x: l.calNext.minX, y: l.calNext.maxY + 1 * S, width: pillW, height: h)

        fillRounded(ctx, pill, h / 2, rgb(0.36, 0.12, 0.44), a * 0.55)
        let d = h - 2 * inset
        let circ = CGRect(x: pill.minX + inset, y: pill.minY + inset, width: d, height: d)
        ctx.setFillColor(rgb(0.83, 0.18, 0.87).copy(alpha: a) ?? rgb(0.83, 0.18, 0.87))
        ctx.fillEllipse(in: circ)
        drawStar(ctx, CGPoint(x: circ.midX, y: circ.midY), d * 0.32, rgb(0.17, 0.04, 0.23), a)
        drawText(ctx, info.nextTitle, font: pf, color: rgb(0.88, 0.70, 0.96), alpha: a,
                 rect: CGRect(x: circ.maxX + 5 * S, y: pill.minY, width: max(0, pill.maxX - circ.maxX - 9 * S), height: h),
                 align: .left, tracking: 0.2, truncate: true)
    }

    drawText(ctx, info.status1, font: sysFont(13.5 * S, .semibold), color: rgb(0.62, 0.62, 0.66),
             alpha: a, rect: l.calStatus1, align: .left, truncate: true)
    drawText(ctx, info.status2, font: sysFont(12.5 * S, .regular), color: rgb(0.45, 0.45, 0.49),
             alpha: a, rect: l.calStatus2, align: .left, truncate: true)
}

func drawSymbol(_ ctx: CGContext, _ name: String, _ rect: CGRect, _ color: CGColor, _ alpha: CGFloat,
                _ weight: NSFont.Weight = .semibold) {
    if alpha <= 0.003 || rect.width < 2 || rect.height < 2 { return }
    let conf = NSImage.SymbolConfiguration(pointSize: rect.height, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(cgColor: color) ?? NSColor.white]))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(conf) else { return }
    let sz = img.size
    guard sz.width > 0, sz.height > 0 else { return }
    let k = min(rect.width / sz.width, rect.height / sz.height)
    let r = CGRect(x: rect.midX - sz.width * k * 0.5, y: rect.midY - sz.height * k * 0.5,
                   width: sz.width * k, height: sz.height * k)
    let g = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = g
    img.draw(in: r, from: NSRect.zero, operation: NSCompositingOperation.sourceOver, fraction: alpha)
    NSGraphicsContext.restoreGraphicsState()
}

func drawRing(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ w: CGFloat, _ frac: CGFloat,
              _ color: CGColor, _ a: CGFloat, _ track: CGFloat = 0.14) {
    if a <= 0.003 || r <= 1 { return }
    let white = rgb(1, 1, 1)
    ctx.setLineWidth(w)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(white.copy(alpha: a * track) ?? white)
    ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    ctx.strokePath()
    let f = clampf(frac, 0, 1)
    if f > 0.004 {
        ctx.setStrokeColor(color.copy(alpha: a) ?? color)
        ctx.beginPath()
        ctx.addArc(center: c, radius: r, startAngle: -.pi / 2, endAngle: -.pi / 2 + 2 * .pi * f, clockwise: false)
        ctx.strokePath()
    }
}

func drawBrackets(_ ctx: CGContext, _ r: CGRect, _ len: CGFloat, _ w: CGFloat, _ c: CGColor, _ a: CGFloat) {
    if a <= 0.003 { return }
    ctx.setStrokeColor(c.copy(alpha: a) ?? c)
    ctx.setLineWidth(w)
    ctx.setLineCap(.round)
    let corners: [[CGPoint]] = [
        [CGPoint(x: r.minX, y: r.minY + len), CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.minX + len, y: r.minY)],
        [CGPoint(x: r.maxX - len, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.minY + len)],
        [CGPoint(x: r.maxX, y: r.maxY - len), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.maxX - len, y: r.maxY)],
        [CGPoint(x: r.minX + len, y: r.maxY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY - len)]
    ]
    for p in corners {
        ctx.beginPath()
        ctx.addLines(between: p)
        ctx.strokePath()
    }
}

func batterySymbol(_ pct: Int, _ charging: Bool) -> String {
    if charging { return "battery.100.bolt" }
    if pct <= 12 { return "battery.0" }
    if pct <= 37 { return "battery.25" }
    if pct <= 62 { return "battery.50" }
    if pct <= 87 { return "battery.75" }
    return "battery.100"
}

func batteryColor(_ pct: Int, _ charging: Bool) -> CGColor {
    if charging { return rgb(0.32, 0.86, 0.45) }
    if pct <= 20 { return rgb(0.95, 0.33, 0.28) }
    if pct <= 40 { return rgb(0.98, 0.74, 0.28) }
    return rgb(0.38, 0.87, 0.49)
}

func batterySpan(_ m: Int) -> String {
    if m >= 60 { return "\(m / 60) h \(m % 60) m" }
    return "\(m) m"
}

func batteryHeadline(_ b: BatteryState) -> String {
    if !b.present { return "Battery Low" }
    if b.charging { return "Charging" }
    if b.percent <= 10 { return "Battery Critical" }
    if b.percent <= 20 { return "Battery Low" }
    return "Battery"
}

func batteryDetail(_ b: BatteryState) -> String {
    if !b.present { return "Turn on Low Power Mode or charge soon." }
    if b.charging {
        if b.fullMinutes > 0 { return batterySpan(b.fullMinutes) + " until full" }
        return "Connected to power"
    }
    if b.minutes > 0 { return batterySpan(b.minutes) + " remaining" }
    if b.percent <= 20 { return "Turn on Low Power Mode or charge soon." }
    return "On battery power"
}

func podsPercent(_ s: PodsState) -> Int {
    if s.left >= 0 && s.right >= 0 { return (s.left + s.right) / 2 }
    if s.left >= 0 { return s.left }
    if s.right >= 0 { return s.right }
    return s.single
}

func listeningName(_ m: Int) -> String {
    switch m {
    case 1: return "Noise Control Off"
    case 2: return "Noise Cancellation"
    case 3: return "Transparency"
    case 4: return "Adaptive"
    default: return "Noise Control"
    }
}

func listeningSymbol(_ m: Int) -> String {
    switch m {
    case 2: return "wave.3.right"
    case 3: return "ear"
    case 4: return "person.wave.2"
    default: return "speaker.slash"
    }
}

func renderIsland(_ ctx: CGContext, size: CGSize) {
    let I = Island.shared
    ctx.clear(CGRect(origin: .zero, size: size))
    guard I.isl.width > 2, I.isl.height > 2 else { return }
    let S = I.S

    let glowAmt = max(I.glowW, I.glowR)
    if glowAmt > 0.01 {
        let red = clampf(I.glowR, 0, 1)
        let c = rgb(1 - 0.08 * red, 1 - 0.74 * red, 1 - 0.80 * red)
        let n = 9
        let step = 1.1 * S
        for i in 1...n {
            let f = 1 - CGFloat(i - 1) / CGFloat(n)
            let d = (CGFloat(i) - 0.5) * step
            let r = I.isl.insetBy(dx: -d, dy: -d)
            let rr = I.radius + d
            ctx.setStrokeColor(c.copy(alpha: glowAmt * (0.12 + 0.05 * red) * f * f) ?? c)
            ctx.setLineWidth(step * 1.15)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: rr, cornerHeight: rr, transform: nil))
            ctx.strokePath()
        }
    }

    fillRounded(ctx, I.isl, I.radius, rgb(0, 0, 0), 1)

    if I.blur > 0.3 {
        drawIslandBlurred(ctx, size: size, sigma: I.blur)
        return
    }

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: I.isl, cornerWidth: I.radius, cornerHeight: I.radius, transform: nil))
    ctx.clip()
    ctx.concatenate(I.xf)
    drawIslandContent(ctx)
    ctx.restoreGState()
}

private func drawIslandBlurred(_ ctx: CGContext, size: CGSize, sigma: CGFloat) {
    let I = Island.shared
    let scale: CGFloat = 2
    let pad = min(max(sigma, 2) + 4, 40)
    let rect = I.isl.insetBy(dx: -pad, dy: -pad)
    let w = Int((rect.width * scale).rounded(.up))
    let h = Int((rect.height * scale).rounded(.up))
    guard w > 1, h > 1,
          let off = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: gColorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    off.scaleBy(x: scale, y: scale)
    off.translateBy(x: -rect.minX, y: rect.maxY)
    off.scaleBy(x: 1, y: -1)
    off.concatenate(I.xf)
    drawIslandContent(off)

    guard let cg = off.makeImage() else { return }
    let src = CIImage(cgImage: cg)
    let blurred = src.clampedToExtent()
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: sigma * scale])
        .cropped(to: src.extent)
    guard let out = gCIContext.createCGImage(blurred, from: src.extent) else { return }

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: I.isl, cornerWidth: I.radius, cornerHeight: I.radius, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.translateBy(x: rect.minX, y: rect.minY + rect.height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(out, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
    ctx.restoreGState()
}

func drawIslandContent(_ ctx: CGContext) {
    let I = Island.shared
    let S = I.S
    let l = I.lay
    let t = clampf(CGFloat(I.ex.x), 0, 1.12)
    let white = rgb(1, 1, 1)

    if I.vMedia > 0.01 && I.has {
        let rr = l.art
        if let img = I.artImage {
            ctx.saveGState()
            ctx.addPath(CGPath(roundedRect: rr, cornerWidth: l.artR, cornerHeight: l.artR, transform: nil))
            ctx.clip()
            ctx.setAlpha(I.vMedia * I.artFade)
            ctx.interpolationQuality = .high
            ctx.translateBy(x: 0, y: rr.midY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(img, in: CGRect(x: rr.minX, y: -rr.height / 2, width: rr.width, height: rr.height))
            ctx.restoreGState()
        } else {
            fillRounded(ctx, rr, l.artR, white, 0.16 * I.vMedia)
        }

        let n = 5
        let sz = l.wsz
        let bw = 2.6 * S * sz
        let gap = 1.9 * S * sz
        let total = CGFloat(n) * bw + CGFloat(n - 1) * gap
        let x0 = l.wx - total / 2
        for i in 0..<n {
            let phase = Double(I.waveTime) * (2.3 + 0.55 * Double(i)) + Double(i) * 1.7
            let amp = 0.30 + 0.70 * abs(sin(phase))
            let hMax = 16 * S * sz
            let hh = lerpf(bw, bw + (hMax - bw) * CGFloat(amp), I.playT)
            let x = x0 + CGFloat(i) * (bw + gap)
            let c = rgb(lerpf(0.55, I.artColor.0, I.playT),
                        lerpf(0.55, I.artColor.1, I.playT),
                        lerpf(0.55, I.artColor.2, I.playT))
            fillRounded(ctx, CGRect(x: x, y: l.wy - hh / 2, width: bw, height: hh), bw / 2, c, I.vMedia)
        }
    }

    let aText = I.vText * clampf((t - 0.55) / 0.35, 0, 1) * (I.has ? 1 : 0)
    if aText > 0.01 {
        let pos = I.displayPos()
        let dur = I.dur
        var frac = dur > 0 ? CGFloat(pos / dur) : 0
        if I.seeking { frac = I.seekFrac }
        frac = clampf(frac, 0, 1)

        var title = I.title
        if title.isEmpty { title = "Unknown" }
        drawText(ctx, title, font: sysFont(17 * S, .semibold), color: white, alpha: aText,
                 rect: l.title, truncate: true)
        drawText(ctx, I.artist, font: sysFont(16 * S, .regular), color: white, alpha: aText * 0.58,
                 rect: l.artist, truncate: true)
        drawText(ctx, fmtTime(pos), font: sysFont(12 * S, .semibold), color: white, alpha: aText * 0.5,
                 rect: l.tEl, align: .left)
        drawText(ctx, "-" + fmtTime(max(0, dur - pos)), font: sysFont(12 * S, .semibold), color: white,
                 alpha: aText * 0.5, rect: l.tRem, align: .right)

        let bh = lerpf(6, 10, I.barGrow) * S
        let cy = l.bar.midY
        let tr = CGRect(x: l.bar.minX, y: cy - bh / 2, width: l.bar.width, height: bh)
        fillRounded(ctx, tr, bh / 2, white, aText * 0.24)
        let fw = max(bh, tr.width * frac)
        fillRounded(ctx, CGRect(x: tr.minX, y: tr.minY, width: fw, height: tr.height), bh / 2, white, aText * 0.92)

        let ctrlGray = rgb(0.58, 0.58, 0.58)
        drawChevrons(ctx, l.prev.x, l.prev.y, -1, (I.down && I.pressedHit == .prev) ? white : ctrlGray, aText)
        drawChevrons(ctx, l.next.x, l.next.y, 1, (I.down && I.pressedHit == .next) ? white : ctrlGray, aText)

        if I.playT < 0.995 {
            let pa = aText * (1 - I.playT)
            let pts = [
                CGPoint(x: l.play.x - 9 * S, y: l.play.y - 14 * S),
                CGPoint(x: l.play.x + 13 * S, y: l.play.y),
                CGPoint(x: l.play.x - 9 * S, y: l.play.y + 14 * S)
            ]
            ctx.setFillColor(white.copy(alpha: pa) ?? white)
            ctx.beginPath()
            ctx.addLines(between: pts)
            ctx.closePath()
            ctx.fillPath()
        }
        if I.playT > 0.01 {
            fillRounded(ctx, CGRect(x: l.play.x - 13 * S, y: l.play.y - 16 * S, width: 9 * S, height: 32 * S), 3 * S, white, aText * I.playT)
            fillRounded(ctx, CGRect(x: l.play.x + 4 * S, y: l.play.y - 16 * S, width: 9 * S, height: 32 * S), 3 * S, white, aText * I.playT)
        }

        drawSpeaker(ctx, cx: l.vol.x - 2 * S, cy: l.vol.y, alpha: ((I.down && I.pressedHit == .vol) ? 1.0 : 0.62) * aText, k: 1.35)
        drawSearchIcon(ctx, l.srch.x, l.srch.y, white, ((I.down && I.pressedHit == .srch) ? 1.0 : 0.62) * aText)
    }

    let aS = I.vSearch * clampf((t - 0.6) / 0.3, 0, 1)
    if aS > 0.01 {
        fillRounded(ctx, l.field, 14 * S, white, 0.14 * aS)
        let padIn = 14 * S
        let inner = l.field.insetBy(dx: padIn, dy: 0)
        let fField = sysFont(17 * S, .regular)
        var caretX = inner.minX
        if I.query.isEmpty {
            drawText(ctx, "Search songs or videos", font: fField, color: white, alpha: 0.45 * aS,
                     rect: inner, align: .left)
        } else {
            let w = textWidth(I.query, fField)
            var x = inner.minX
            if w > inner.width { x = inner.maxX - w }
            ctx.saveGState()
            ctx.clip(to: inner)
            drawText(ctx, I.query, font: fField, color: white, alpha: aS,
                     rect: CGRect(x: x, y: inner.minY, width: w + 12, height: inner.height), align: .left)
            ctx.restoreGState()
            caretX = x + w
        }
        if I.time.truncatingRemainder(dividingBy: 1.0) < 0.55 {
            fillRounded(ctx, CGRect(x: caretX + 1 * S, y: l.field.minY + 11 * S,
                                    width: 2 * S, height: l.field.height - 22 * S),
                        1 * S, rgb(0.35, 0.65, 1.0), aS)
        }

        let ba: CGFloat = I.query.isEmpty ? 0.4 : 1.0
        func button(_ r: CGRect, _ label: String, _ h: Hit) {
            let aa = ba * aS * ((I.down && I.pressedHit == h) ? 0.75 : 1.0)
            fillRounded(ctx, r, 20 * S, white, aa)
            drawText(ctx, label, font: sysFont(15 * S, .semibold), color: rgb(0, 0, 0), alpha: aa, rect: r, align: .center)
        }
        button(l.bSpot, "Spotify", .spot)
        button(l.bYt, "YouTube", .yt)
        drawText(ctx, "↩ Spotify   ·   ⌘↩ YouTube   ·   esc cancel", font: sysFont(12 * S, .regular),
                 color: white, alpha: 0.42 * aS, rect: l.hint, align: .center)
    }

    let red = rgb(0.84, 0.33, 0.26)
    let tt = CGFloat(I.time - I.alertStart)
    let aSil = clampf(CGFloat(I.aSilent.x), 0, 1)
    let aRg = clampf(CGFloat(I.aRing.x), 0, 1)
    func zsc(_ sp: Spring) -> CGFloat { lerpf(0.5, 1, clampf(CGFloat(sp.x), 0, 1.12)) }
    func zoom(_ ax: CGFloat, _ ay: CGFloat, _ sc: CGFloat, _ offX: CGFloat) {
        ctx.translateBy(x: offX, y: 0)
        ctx.translateBy(x: ax, y: ay)
        ctx.scaleBy(x: sc, y: sc)
        ctx.translateBy(x: -ax, y: -ay)
    }

    if aSil > 0.01 {
        ctx.saveGState()
        zoom(l.capX, l.capY, zsc(I.aSilent), 0)
        fillRounded(ctx, l.capsule, 13 * S, red, aSil)
        ctx.restoreGState()
    }
    let aBell = max(aSil, aRg)
    if aBell > 0.01 {
        let slide = clampf(CGFloat(I.bellSlide.x), 0, 1.1)
        let bx = lerpf(l.ringX, l.capX, slide)
        let ang = (I.alertKind == .ring && tt < 1.6) ? 24 * exp(-2.4 * tt) * sin(tt * 27) : 0
        let gap = rgb(red.components?[0] ?? 0, red.components?[1] ?? 0, red.components?[2] ?? 0)
        drawBell(ctx, cx: bx, cy: l.ringY, scale: 13 * S, color: white, alpha: aBell,
                 slash: clampf(CGFloat(I.slashT.x), 0, 1), bg: gap, ang: ang)
    }
    if aSil > 0.01 {
        ctx.saveGState()
        zoom(l.alertText.maxX - 24 * S, l.capY, zsc(I.aSilent), -(1 - aSil) * 14 * S)
        drawText(ctx, "Silent", font: sysFont(15 * S, .semibold), color: red, alpha: aSil,
                 rect: l.alertText, align: .right)
        ctx.restoreGState()
    }
    if aRg > 0.01 {
        ctx.saveGState()
        zoom(l.alertText.maxX - 18 * S, l.capY, zsc(I.aRing), (1 - aRg) * 14 * S)
        drawText(ctx, "Ring", font: sysFont(15 * S, .semibold), color: white, alpha: aRg,
                 rect: l.alertText, align: .right)
        ctx.restoreGState()
    }
    let aVl = clampf(CGFloat(I.aVolS.x), 0, 1)
    if aVl > 0.01 {
        ctx.saveGState()
        let midX = (l.ringX + l.alertText.maxX) * 0.5
        zoom(midX, l.ringY, zsc(I.aVolS), 0)
        drawSpeaker(ctx, cx: l.ringX - 2 * S, cy: l.ringY, alpha: aVl, k: 0.85)
        let x0 = l.ringX + 17 * S
        let x1 = l.alertText.maxX - 2 * S
        let bh = 7 * S
        let cy = l.ringY
        let tr = CGRect(x: x0, y: cy - bh / 2, width: max(0, x1 - x0), height: bh)
        fillRounded(ctx, tr, bh / 2, white, aVl * 0.25)
        let fw = tr.width * clampf(I.volShown, 0, 1)
        if fw > 0.5 {
            fillRounded(ctx, CGRect(x: tr.minX, y: tr.minY, width: max(bh, fw), height: tr.height), bh / 2, white, aVl)
        }
        ctx.restoreGState()
    }

    let aB = clampf(CGFloat(I.aBat.x), 0, 1)
    if aB > 0.01 {
        let pct = I.battery.present ? I.battery.percent : 14
        let col = batteryColor(pct, I.battery.charging)
        drawSymbol(ctx, batterySymbol(pct, I.battery.charging), l.batIcon, col, aB)
        drawText(ctx, I.battery.charging ? "Charging" : "Battery Low", font: sysFont(14.5 * S, .semibold),
                 color: white, alpha: aB, rect: l.batTitle, truncate: true)
        drawText(ctx, "\(pct)%", font: sysFont(16 * S, .semibold), color: col, alpha: aB,
                 rect: l.batPct, align: .right)
    }

    let aP = clampf(CGFloat(I.aPods.x), 0, 1)
    if aP > 0.01 {
        let st = I.pods
        let name = st.name.isEmpty ? "AirPods" : st.name
        let dim = rgb(0.52, 0.52, 0.56)
        drawSymbol(ctx, "airpodspro", l.podIcon, st.connected ? white : dim, aP)
        drawText(ctx, st.connected ? "Connected" : "Disconnected", font: sysFont(10.5 * S, .semibold),
                 color: st.connected ? rgb(0.55, 0.86, 0.62) : dim, alpha: aP, rect: l.podLabel, tracking: 0.4)
        drawText(ctx, name, font: sysFont(14.5 * S, .semibold), color: white,
                 alpha: aP * (st.connected ? 1 : 0.55), rect: l.podName, truncate: true)
        let pct = podsPercent(st)
        if pct >= 0 {
            drawRing(ctx, l.podRing, l.podRingR, 3 * S, CGFloat(pct) / 100, batteryColor(pct, false), aP, 0.16)
            drawText(ctx, "\(pct)", font: sysFont(10.5 * S, .semibold), color: white, alpha: aP,
                     rect: CGRect(x: l.podRing.x - 16 * S, y: l.podRing.y - 8 * S, width: 32 * S, height: 16 * S), align: .center)
        }
    }

    let aA = clampf(CGFloat(I.aAuth.x), 0, 1)
    if aA > 0.01 {
        let ok = I.authOK
        let col = I.authRunning ? white : (ok ? rgb(0.35, 0.87, 0.46) : rgb(0.95, 0.35, 0.30))
        let sym = I.authRunning ? "touchid" : (ok ? "checkmark.circle.fill" : "xmark.circle.fill")
        drawSymbol(ctx, sym, l.authIcon, col, aA)
        drawText(ctx, I.authLabel.isEmpty ? "Authenticating" : I.authLabel, font: sysFont(15 * S, .semibold),
                 color: white, alpha: aA, rect: l.authLabel, truncate: true)
    }

    let aPm = clampf(CGFloat(I.aPerm.x), 0, 1)
    if aPm > 0.01 {
        let col = I.authOK ? rgb(0.35, 0.87, 0.46) : rgb(0.95, 0.35, 0.30)
        drawSymbol(ctx, "lock.shield", l.authIcon, col, aPm)
        drawText(ctx, I.authLabel.isEmpty ? "Calendar Access" : I.authLabel, font: sysFont(14.5 * S, .semibold),
                 color: white, alpha: aPm, rect: l.authLabel, truncate: true)
    }

    let aC = I.vCard * clampf((t - 0.5) / 0.35, 0, 1)
    if aC > 0.01 && I.expanded {
        if I.card == .battery {
            let st = I.battery
            let pct = st.present ? st.percent : 14
            let col = batteryColor(pct, st.charging)
            drawRing(ctx, l.ringC, l.ringR, 8 * S, CGFloat(pct) / 100, col, aC, 0.13)
            drawText(ctx, "\(pct)%", font: sysFont(28 * S, .semibold), color: white, alpha: aC,
                     rect: CGRect(x: l.ringC.x - l.ringR, y: l.ringC.y - 17 * S, width: l.ringR * 2, height: 34 * S), align: .center)
            if st.charging {
                drawSymbol(ctx, "bolt.fill", CGRect(x: l.ringC.x - 7 * S, y: l.ringC.y + l.ringR + 5 * S, width: 14 * S, height: 14 * S), col, aC * 0.9)
            }
            drawText(ctx, "BATTERY", font: sysFont(10 * S, .semibold), color: rgb(0.62, 0.62, 0.66),
                     alpha: aC, rect: l.cardKick, tracking: 1.4)
            drawText(ctx, batteryHeadline(st), font: sysFont(21 * S, .semibold), color: white,
                     alpha: aC, rect: l.cardTitle, truncate: true)
            drawText(ctx, batteryDetail(st), font: sysFont(12.5 * S, .regular), color: rgb(0.62, 0.62, 0.66),
                     alpha: aC, rect: l.cardSub, truncate: true)
            let chip = l.cardChip
            fillRounded(ctx, chip, chip.height / 2, white, aC * 0.10)
            drawSymbol(ctx, "bolt.fill", CGRect(x: chip.minX + 12 * S, y: chip.midY - 7 * S, width: 14 * S, height: 14 * S),
                       st.lowPower ? col : rgb(0.60, 0.60, 0.64), aC)
            drawText(ctx, st.lowPower ? "Low Power Mode On" : "Low Power Mode Off", font: sysFont(11.5 * S, .semibold),
                     color: white, alpha: aC * 0.85,
                     rect: CGRect(x: chip.minX + 32 * S, y: chip.minY, width: chip.width - 42 * S, height: chip.height), truncate: true)
            drawText(ctx, "Open Battery Settings", font: sysFont(11.5 * S, .medium), color: white,
                     alpha: aC * 0.45, rect: l.cardHint)
        }

        if I.card == .pods {
            let st = I.pods
            let name = st.name.isEmpty ? "AirPods" : st.name
            let on = st.connected
            drawSymbol(ctx, "airpodspro", l.podIconBig, white, aC * (on ? 1 : 0.35))
            drawText(ctx, on ? "CONNECTED" : "DISCONNECTED", font: sysFont(10 * S, .semibold),
                     color: on ? rgb(0.45, 0.86, 0.55) : rgb(0.55, 0.55, 0.58), alpha: aC,
                     rect: l.podCardKick, tracking: 1.3)
            drawText(ctx, name, font: sysFont(19 * S, .semibold), color: white,
                     alpha: aC * (on ? 1 : 0.5), rect: l.podCardName, truncate: true)
            if on && st.listening > 0 {
                let chip = l.podModeChip
                fillRounded(ctx, chip, chip.height / 2, white, aC * 0.10)
                drawSymbol(ctx, listeningSymbol(st.listening),
                           CGRect(x: chip.minX + 10 * S, y: chip.midY - 7 * S, width: 14 * S, height: 14 * S), white, aC * 0.9)
                drawText(ctx, listeningName(st.listening), font: sysFont(11 * S, .semibold), color: white,
                         alpha: aC * 0.9,
                         rect: CGRect(x: chip.minX + 30 * S, y: chip.minY, width: chip.width - 38 * S, height: chip.height),
                         truncate: true)
            } else {
                drawText(ctx, on ? "Noise control unavailable" : "Connect to see battery",
                         font: sysFont(11 * S, .regular), color: white, alpha: aC * 0.45, rect: l.podModeChip)
            }
            let rows: [(String, Int)] = [("L", st.left), ("R", st.right), ("Case", st.caseLevel)]
            let cL = l.cardL
            let cT = l.cardT
            var y = cT + 46 * S
            var any = false
            for (label, value) in rows where value >= 0 {
                any = true
                drawText(ctx, label, font: sysFont(11 * S, .semibold), color: rgb(0.62, 0.62, 0.66), alpha: aC,
                         rect: CGRect(x: cL + 196 * S, y: y, width: 30 * S, height: 16 * S))
                let br = CGRect(x: cL + 228 * S, y: y + 6 * S, width: 74 * S, height: 5 * S)
                fillRounded(ctx, br, br.height / 2, white, aC * 0.16)
                fillRounded(ctx, CGRect(x: br.minX, y: br.minY, width: max(br.height, br.width * CGFloat(value) / 100), height: br.height),
                            br.height / 2, batteryColor(value, false), aC * 0.95)
                drawText(ctx, "\(value)%", font: sysFont(11 * S, .semibold), color: white, alpha: aC * 0.9,
                         rect: CGRect(x: cL + 308 * S, y: y, width: 44 * S, height: 16 * S), align: .right)
                y += 30 * S
            }
            if !any && on {
                drawText(ctx, "Battery levels unavailable", font: sysFont(11 * S, .regular), color: rgb(0.55, 0.55, 0.58),
                         alpha: aC, rect: CGRect(x: cL + 196 * S, y: cT + 48 * S, width: 156 * S, height: 16 * S), truncate: true)
            }
            drawText(ctx, on ? "Click mode to cycle" : "Open Bluetooth Settings",
                     font: sysFont(11 * S, .medium), color: white, alpha: aC * 0.42, rect: l.podHint, truncate: true)
        }

        if I.card == .auth || I.card == .permission {
            let perm = I.card == .permission
            let ok = I.authOK
            let running = I.authRunning
            let col = running ? white : (ok ? rgb(0.35, 0.87, 0.46) : rgb(0.95, 0.35, 0.30))
            let phase = max(0, CGFloat(I.time - I.authStart))
            if running {
                for i in 0..<2 {
                    let p = (phase * 0.9 + CGFloat(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    let rr = l.authBig.width * 0.62 + p * 32 * S
                    ctx.setStrokeColor(col.copy(alpha: aC * 0.22 * (1 - p)) ?? col)
                    ctx.setLineWidth(1.5 * S)
                    ctx.addEllipse(in: CGRect(x: l.authBig.midX - rr, y: l.authBig.midY - rr, width: rr * 2, height: rr * 2))
                    ctx.strokePath()
                }
            }
            let br = l.authBig.insetBy(dx: -12 * S, dy: -12 * S)
            drawBrackets(ctx, br, 10 * S, 2.5 * S, col, aC * (running ? 0.9 : 0.4))
            let sym = perm ? "lock.shield" : (running ? "touchid" : (ok ? "checkmark.circle.fill" : "xmark.circle.fill"))
            drawSymbol(ctx, sym, l.authBig, col, aC, .regular)
            if running {
                let yy = br.minY + br.height * (0.5 + 0.45 * sin(phase * 2.6))
                fillRounded(ctx, CGRect(x: br.minX + 6 * S, y: yy, width: br.width - 12 * S, height: 2 * S), 1 * S, col, aC * 0.55)
            }
            let title = perm ? I.authLabel : (running ? "Authenticating" : I.authLabel)
            drawText(ctx, title.isEmpty ? "Authenticating" : title, font: sysFont(19 * S, .semibold), color: white,
                     alpha: aC, rect: l.authTitle, align: .center, truncate: true)
            let sub = perm ? (ok ? "MacLand can show your calendar" : "Enable it in Privacy & Security")
                           : (running ? "Touch ID" : (ok ? "It's you" : "Try again"))
            drawText(ctx, sub, font: sysFont(12 * S, .regular), color: white, alpha: aC * 0.5,
                     rect: l.authSub, align: .center)
        }
    }

    drawCalendar(ctx)
}
