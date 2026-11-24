import AppKit
import ImageIO

func clampf(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { return v < a ? a : (v > b ? b : v) }
func lerpf(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { return a + (b - a) * t }
func rubber(_ x: CGFloat, _ d: CGFloat) -> CGFloat { return (1 - 1 / ((x * 0.55 / d) + 1)) * d }

enum Mode { case idle, compact, alert, expanded }
enum Hit { case none, body, seek, prev, play, next, vol, srch, spot, yt, field, podmode, settings }
enum AlertKind: Int { case ring = 0, silent = 1, volume = 2, battery = 3, pods = 4, auth = 5, permission = 6 }

struct Lay {
    var art = CGRect.zero
    var artR: CGFloat = 0
    var wx: CGFloat = 0
    var wy: CGFloat = 0
    var wsz: CGFloat = 1
    var title = CGRect.zero
    var artist = CGRect.zero
    var tEl = CGRect.zero
    var tRem = CGRect.zero
    var bar = CGRect.zero
    var prev = CGPoint.zero
    var play = CGPoint.zero
    var next = CGPoint.zero
    var vol = CGPoint.zero
    var srch = CGPoint.zero
    var field = CGRect.zero
    var bSpot = CGRect.zero
    var bYt = CGRect.zero
    var hint = CGRect.zero
    var capsule = CGRect.zero
    var alertText = CGRect.zero
    var ringX: CGFloat = 0
    var ringY: CGFloat = 0
    var capX: CGFloat = 0
    var capY: CGFloat = 0
    var calWeek = CGRect.zero
    var calDay = CGRect.zero
    var calNext = CGRect.zero
    var calStatus1 = CGRect.zero
    var calStatus2 = CGRect.zero
    var batIcon = CGRect.zero
    var batTitle = CGRect.zero
    var batPct = CGRect.zero
    var podIcon = CGRect.zero
    var podLabel = CGRect.zero
    var podName = CGRect.zero
    var podRing = CGPoint.zero
    var podRingR: CGFloat = 15
    var authIcon = CGRect.zero
    var authLabel = CGRect.zero
    var ringC = CGPoint.zero
    var ringR: CGFloat = 40
    var cardKick = CGRect.zero
    var cardTitle = CGRect.zero
    var cardSub = CGRect.zero
    var cardChip = CGRect.zero
    var cardHint = CGRect.zero
    var podIconBig = CGRect.zero
    var podCardKick = CGRect.zero
    var podCardName = CGRect.zero
    var podModeChip = CGRect.zero
    var podHint = CGRect.zero
    var authBig = CGRect.zero
    var authTitle = CGRect.zero
    var authSub = CGRect.zero
    var cardL: CGFloat = 0
    var cardT: CGFloat = 0
}

func ComputeLayout(cL: CGFloat, cT: CGFloat, cR: CGFloat, cB: CGFloat, tRaw: CGFloat) -> Lay {
    let S: CGFloat = 1
    let t = clampf(tRaw, 0, 1.12)
    var l = Lay()
    let pad = 26 * S
    let cx = (cL + cR) * 0.5
    let asz = lerpf(22 * S, 56 * S, t)
    let ax = lerpf(cL + 9 * S, cL + pad, t)
    let ay = lerpf(cT + 7.5 * S, cT + pad, t)
    l.art = CGRect(x: ax, y: ay, width: asz, height: asz)
    l.artR = lerpf(5 * S, 11 * S, t)
    l.wx = lerpf(cR - 18 * S, cR - 42 * S, t)
    l.wy = lerpf(cT + 18.5 * S, cT + 46 * S, t)
    l.wsz = lerpf(0.85, 1.25, t)
    let tx = cL + pad + 56 * S + 14 * S
    let tw = (cR - 42 * S - 20 * S) - tx
    l.title = CGRect(x: tx, y: cT + 32 * S, width: tw, height: 24 * S)
    l.artist = CGRect(x: tx, y: cT + 55 * S, width: tw, height: 22 * S)
    let py = cT + 117 * S
    l.tEl = CGRect(x: cL + pad, y: py - 10 * S, width: 44 * S, height: 20 * S)
    l.tRem = CGRect(x: cR - pad - 48 * S, y: py - 10 * S, width: 48 * S, height: 20 * S)
    l.bar = CGRect(x: cL + pad + 46 * S, y: py - 3 * S, width: (cR - pad - 52 * S) - (cL + pad + 46 * S), height: 6 * S)
    let cy = cT + 156 * S
    l.prev = CGPoint(x: cx - 70 * S, y: cy)
    l.play = CGPoint(x: cx, y: cy)
    l.next = CGPoint(x: cx + 70 * S, y: cy)
    l.vol = CGPoint(x: cR - 50 * S, y: cy)
    l.srch = CGPoint(x: cL + 50 * S, y: cy)
    l.field = CGRect(x: cL + pad, y: cT + 26 * S, width: (cR - pad) - (cL + pad), height: 44 * S)
    l.bSpot = CGRect(x: cL + pad, y: cT + 86 * S, width: (cx - 6 * S) - (cL + pad), height: 40 * S)
    l.bYt = CGRect(x: cx + 6 * S, y: cT + 86 * S, width: (cR - pad) - (cx + 6 * S), height: 40 * S)
    l.hint = CGRect(x: cL + pad, y: cT + 140 * S, width: (cR - pad) - (cL + pad), height: 24 * S)
    l.capsule = CGRect(x: cL + 8 * S, y: cT + 5.5 * S, width: 50 * S, height: 26 * S)
    l.capX = l.capsule.midX
    l.capY = cT + 18.5 * S
    l.ringX = cL + 24 * S
    l.ringY = cT + 18.5 * S
    l.alertText = CGRect(x: cL + 62 * S, y: cT, width: (cR - 20 * S) - (cL + 62 * S), height: 37 * S)

    l.calWeek = CGRect(x: cL + 22 * S, y: cT + 17 * S, width: 168 * S, height: 14 * S)
    l.calDay = CGRect(x: cL + 20 * S, y: cT + 31 * S, width: 160 * S, height: 56 * S)
    l.calNext = CGRect(x: cL + 196 * S, y: cT + 17 * S, width: (cR - 22 * S) - (cL + 196 * S), height: 14 * S)
    l.calStatus1 = CGRect(x: cL + 22 * S, y: cT + 96 * S, width: (cR - 22 * S) - (cL + 22 * S), height: 16 * S)
    l.calStatus2 = CGRect(x: cL + 22 * S, y: cT + 112 * S, width: (cR - 22 * S) - (cL + 22 * S), height: 16 * S)

    l.batIcon = CGRect(x: cL + 18 * S, y: cT + 9 * S, width: 26 * S, height: 19 * S)
    l.batTitle = CGRect(x: cL + 52 * S, y: cT + 2 * S, width: 112 * S, height: 33 * S)
    l.batPct = CGRect(x: cR - 74 * S, y: cT + 2 * S, width: 58 * S, height: 33 * S)
    l.podIcon = CGRect(x: cL + 14 * S, y: cT + 7 * S, width: 26 * S, height: 23 * S)
    l.podLabel = CGRect(x: cL + 48 * S, y: cT + 3 * S, width: (cR - 74 * S) - (cL + 48 * S), height: 14 * S)
    l.podName = CGRect(x: cL + 48 * S, y: cT + 15 * S, width: (cR - 74 * S) - (cL + 48 * S), height: 20 * S)
    l.podRing = CGPoint(x: cR - 36 * S, y: l.ringY)
    l.podRingR = 15 * S
    l.authIcon = CGRect(x: cL + 18 * S, y: cT + 8.5 * S, width: 21 * S, height: 21 * S)
    l.authLabel = CGRect(x: cL + 48 * S, y: cT, width: (cR - 16 * S) - (cL + 48 * S), height: 37 * S)

    l.cardL = cL
    l.cardT = cT
    l.ringC = CGPoint(x: cL + 92 * S, y: cT + 100 * S)
    l.ringR = 40 * S
    l.cardKick = CGRect(x: cL + 172 * S, y: cT + 30 * S, width: (cR - 26 * S) - (cL + 172 * S), height: 14 * S)
    l.cardTitle = CGRect(x: cL + 172 * S, y: cT + 44 * S, width: (cR - 26 * S) - (cL + 172 * S), height: 28 * S)
    l.cardSub = CGRect(x: cL + 172 * S, y: cT + 74 * S, width: (cR - 24 * S) - (cL + 172 * S), height: 18 * S)
    l.cardChip = CGRect(x: cL + 172 * S, y: cT + 102 * S, width: 164 * S, height: 30 * S)
    l.cardHint = CGRect(x: cL + 172 * S, y: cT + 148 * S, width: (cR - 24 * S) - (cL + 172 * S), height: 18 * S)
    l.podIconBig = CGRect(x: cL + 34 * S, y: cT + 34 * S, width: 54 * S, height: 46 * S)
    l.podCardKick = CGRect(x: cL + 24 * S, y: cT + 88 * S, width: 150 * S, height: 14 * S)
    l.podCardName = CGRect(x: cL + 24 * S, y: cT + 102 * S, width: 148 * S, height: 28 * S)
    l.podModeChip = CGRect(x: cL + 24 * S, y: cT + 136 * S, width: 152 * S, height: 26 * S)
    l.podHint = CGRect(x: cL + 24 * S, y: cT + 166 * S, width: 150 * S, height: 16 * S)
    l.authBig = CGRect(x: cx - 34 * S, y: cT + 30 * S, width: 68 * S, height: 68 * S)
    l.authTitle = CGRect(x: cL + 20 * S, y: cT + 118 * S, width: (cR - 20 * S) - (cL + 20 * S), height: 26 * S)
    l.authSub = CGRect(x: cL + 20 * S, y: cT + 146 * S, width: (cR - 20 * S) - (cL + 20 * S), height: 18 * S)
    return l
}

final class Island {
    static let shared = Island()

    var S: CGFloat = 1
    var canvas = CGSize(width: 720, height: 460)
    var topInset: CGFloat = 20
    var pointer = CGPoint(x: -9999, y: -9999)

    var time: Double = 0
    var mode: Mode = .idle
    var expanded = false
    var searchMode = false
    var query = ""
    var searchActive: (Bool) -> Void = { _ in }

    var lastActive: Double = 0
    var leaveTimer: Double = 0
    var hoverT: Double = 0
    var topmostTimer: Double = 0
    var alertStart: Double = -10
    var alertUntil: Double = -10
    var alertKind: AlertKind = .ring

    var sw = Spring()
    var sh = Spring()
    var ex = Spring()
    var sL = Spring()
    var sR = Spring()
    var sB = Spring()
    var press = Spring()
    var aRing = Spring()
    var aSilent = Spring()
    var aVolS = Spring()
    var bellSlide = Spring()
    var slashT = Spring()

    var vMedia: CGFloat = 0
    var vText: CGFloat = 0
    var vSearch: CGFloat = 0
    var vAlert: CGFloat = 0
    var vCal: CGFloat = 0
    var playT: CGFloat = 0
    var artFade: CGFloat = 1
    var waveTime: CGFloat = 0
    var barGrow: CGFloat = 0
    var volShown: CGFloat = 0.5
    var waveAmt: [CGFloat] = [1, 1, 0]
    var muteAmt: CGFloat = 0
    var aBat = Spring()
    var aPods = Spring()
    var aAuth = Spring()
    var aPerm = Spring()
    var vCard: CGFloat = 0
    var card: AlertKind? = nil
    var battery = BatteryState()
    var pods = PodsState()
    var authOK = false
    var authRunning = false
    var authLabel = ""
    var authStart: Double = -10
    var batteryThreshold = 100
    var silentState = false
    var silentKnown = false
    var glowW: CGFloat = 0
    var glowR: CGFloat = 0

    var isl = CGRect.zero
    var radius: CGFloat = 0
    var blur: CGFloat = 0
    private var pL: CGFloat = 0
    private var pR: CGFloat = 0
    private var pB: CGFloat = 0
    private var firstFrame = true
    var sx: CGFloat = 1
    var sy: CGFloat = 1
    var tx: CGFloat = 0
    var ty: CGFloat = 0
    var xf = CGAffineTransform.identity
    var lay = Lay()

    var down = false
    var dragging = false
    var seeking = false
    var moved = false
    var pressedHit: Hit = .none
    var startPt = CGPoint.zero
    var seekFrac: CGFloat = 0
    var seekHoldUntil: Double = 0
    var seekPos: Double = 0
    var overridePlay = false
    var overridePlayMin: Double = 0
    var overridePlayUntil: Double = 0
    var playingNow = false
    var volHoldUntil: Double = 0
    var lastVolRemote: Float = -1

    var has = false
    var mPlaying = false
    var title = ""
    var artist = ""
    var pos: Double = 0
    var dur: Double = 0
    var stamp = Date()
    var seenTrack = 0
    var seenThumb = 0
    var artImage: CGImage?
    var artColor: (CGFloat, CGFloat, CGFloat) = (1, 1, 1)
    var animating = true

    init() {
        sw.cfg(0.28, 0.86)
        sh.cfg(0.28, 0.86)
        ex.cfg(0.28, 0.86)
        sL.cfg(0.5, 0.42)
        sR.cfg(0.5, 0.42)
        sB.cfg(0.5, 0.42)
        press.cfg(0.18, 0.8)
        aRing.cfg(0.36, 0.62)
        aSilent.cfg(0.36, 0.62)
        aVolS.cfg(0.34, 0.7)
        bellSlide.cfg(0.42, 0.8)
        slashT.cfg(0.357, 0.9)
        aBat.cfg(0.30, 0.80)
        aPods.cfg(0.30, 0.80)
        aAuth.cfg(0.30, 0.80)
        aPerm.cfg(0.30, 0.80)
    }

    func bootstrap() {
        applyMode(.idle)
        sw.snap(sw.target)
        sh.snap(sh.target)
        ex.snap(0)
        sL.snap(0)
        sR.snap(0)
        sB.snap(0)
        aBat.snap(0)
        aPods.snap(0)
        aAuth.snap(0)
        aPerm.snap(0)
        pointer = CGPoint(x: -9999, y: -9999)
        update(0.016)
    }

    // MARK: - Modes

    func alertW(_ k: AlertKind) -> CGFloat {
        switch k {
        case .ring: return 186
        case .silent: return 214
        case .volume: return 206
        case .battery: return 252
        case .pods: return 312
        case .auth: return 238
        case .permission: return 282
        }
    }

    func featureAlertActive() -> Bool {
        guard time < alertUntil else { return false }
        return alertKind == .battery || alertKind == .pods || alertKind == .auth || alertKind == .permission
    }

    func applyMode(_ m: Mode) {
        mode = m
        let S = self.S
        var w: CGFloat = 126
        var h: CGFloat = 37
        switch m {
        case .idle: w = 126; h = 37
        case .compact: w = 192; h = 37
        case .alert: w = alertW(alertKind); h = 37
        case .expanded: w = 372; h = 196
        }
        let grow = (m == .expanded)
        let resp = grow ? 0.46 : 0.28
        let z = grow ? 0.72 : 0.86
        sw.cfg(resp, z)
        sh.cfg(resp, z)
        ex.cfg(resp, z)
        sw.target = Double(w * S)
        sh.target = Double(h * S)
        ex.target = grow ? 1.0 : 0.0
    }

    func triggerAlert(_ kind: AlertKind, _ duration: Double) {
        if kind != alertKind || time >= alertUntil { alertStart = time }
        alertKind = kind
        alertUntil = time + duration
        switch kind {
        case .battery, .pods, .auth, .permission: card = kind
        default: card = nil
        }
    }

    func pollBattery() {
        battery = BatteryMonitor.shared.state
        guard battery.present, !battery.charging else { batteryThreshold = 100; return }
        if battery.percent > 22 { batteryThreshold = 100 }
        for th in [20, 10, 5] where battery.percent <= th && batteryThreshold > th {
            batteryThreshold = th
            triggerAlert(.battery, 10)
            return
        }
    }

    func podsChanged(_ s: PodsState) {
        pods = s
        guard s.connected || !s.name.isEmpty else { return }
        triggerAlert(.pods, s.connected ? 6.0 : 4.5)
    }

    func podsModeChanged() {
        pods = AirPodsMonitor.shared.state
    }

    func beginAuth() {
        authRunning = true
        authOK = false
        authLabel = "Authenticating"
        authStart = time
        triggerAlert(.auth, 60)
    }

    func finishAuth(_ ok: Bool, _ label: String) {
        authRunning = false
        authOK = ok
        authLabel = label
        triggerAlert(.auth, 3.4)
    }

    func showPermission(_ ok: Bool) {
        authRunning = false
        authOK = ok
        authLabel = ok ? "Calendar Access Granted" : "Calendar Access Denied"
        authStart = time
        triggerAlert(.permission, 4.0)
    }

    func pullMedia() {
        let st = MediaState.shared
        has = st.has
        mPlaying = st.playing
        title = st.title
        artist = st.artist
        pos = st.pos
        dur = st.dur
        stamp = st.stamp
        if st.trackSerial != seenTrack {
            seenTrack = st.trackSerial
            artFade = 0
            lastActive = time
        }
        if st.artSerial != seenThumb {
            seenThumb = st.artSerial
            loadArt(st.artData)
        }
    }

    private func loadArt(_ data: Data?) {
        artImage = nil
        artColor = (1, 1, 1)
        guard let data = data,
              let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return }
        artImage = img
        artColor = averageColor(img)
    }

    private func averageColor(_ img: CGImage) -> (CGFloat, CGFloat, CGFloat) {
        var px = [UInt8](repeating: 0, count: 4)
        var ok = false
        px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                      bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.interpolationQuality = .medium
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            ok = true
        }
        guard ok else { return (1, 1, 1) }
        var r = CGFloat(px[0]) / 255
        var g = CGFloat(px[1]) / 255
        var b = CGFloat(px[2]) / 255
        let mx = max(r, max(g, b))
        if mx > 0.05 {
            let k = 0.92 / mx
            r = clampf(r * k, 0, 1)
            g = clampf(g * k, 0, 1)
            b = clampf(b * k, 0, 1)
            r = lerpf(r, 1, 0.15)
            g = lerpf(g, 1, 0.15)
            b = lerpf(b, 1, 0.15)
        } else {
            r = 1; g = 1; b = 1
        }
        return (r, g, b)
    }

    func displayPos() -> Double {
        var p: Double
        if time < seekHoldUntil {
            p = seekPos + (playingNow ? (time - (seekHoldUntil - 1.0)) : 0)
        } else {
            p = pos
            if playingNow && mPlaying { p += Date().timeIntervalSince(stamp) }
        }
        if dur > 0 { p = min(p, dur) }
        return max(p, 0)
    }

    func update(_ dt: Double) {
        time += dt
        pullMedia()

        if overridePlayUntil > 0 && time >= overridePlayMin && (mPlaying == overridePlay || time >= overridePlayUntil) {
            overridePlayUntil = 0
        }
        let playing = overridePlayUntil > 0 ? overridePlay : mPlaying
        playingNow = playing && has
        if playingNow { lastActive = time }

        let m = (expanded ? 6.0 : 4.0) * Double(S)
        let inIsland = Double(pointer.x) >= Double(isl.minX) - m
            && Double(pointer.x) <= Double(isl.maxX) + m
            && Double(pointer.y) <= Double(isl.maxY) + m
            && Double(pointer.y) >= Double(-m)
        if searchMode || down {
            hoverT = 0
            leaveTimer = 0
        } else if inIsland {
            leaveTimer = 0
            if !expanded {
                hoverT += dt
                if hoverT > 0.07 { expanded = true; hoverT = 0 }
            }
        } else {
            hoverT = 0
            if expanded {
                leaveTimer += dt
                if leaveTimer > 0.05 { expanded = false; leaveTimer = 0 }
            }
        }

        let want: Mode
        if expanded { want = .expanded }
        else if time < alertUntil { want = .alert }
        else if has { want = .compact }
        else { want = .idle }
        if want != mode { applyMode(want) }
        if mode == .alert { sw.target = Double(alertW(alertKind) * S) }

        sw.step(dt)
        sh.step(dt)
        ex.step(dt)
        sL.step(dt)
        sR.step(dt)
        sB.step(dt)
        press.step(dt)
        press.target = down ? 1.0 : 0.0

        func sm(_ v: inout CGFloat, _ target: CGFloat, _ up: CGFloat, _ down: CGFloat) {
            let rate = target > v ? up : down
            v += (target - v) * (1 - exp(-rate * CGFloat(dt)))
        }

        let showMedia = card == nil && !searchMode && ((mode == .compact && has) || mode == .expanded)
        sm(&vMedia, showMedia ? 1 : 0, 14, 30)
        sm(&vText, (expanded && !searchMode && card == nil) ? 1 : 0, 14, 34)
        sm(&vSearch, (expanded && searchMode) ? 1 : 0, 14, 34)
        sm(&vAlert, mode == .alert ? 1 : 0, 16, 24)
        sm(&vCal, (!has && !searchMode && card == nil) ? 1 : 0, 10, 14)
        sm(&vCard, (expanded && card != nil && !searchMode) ? 1 : 0, 12, 26)
        sm(&playT, playingNow ? 1 : 0, 10, 10)
        sm(&artFade, 1, 6, 6)
        sm(&barGrow, seeking ? 1 : 0, 18, 18)
        if playingNow { waveTime += CGFloat(dt) }

        aRing.target = (mode == .alert && alertKind == .ring) ? 1 : 0
        aSilent.target = (mode == .alert && alertKind == .silent) ? 1 : 0
        aVolS.target = (mode == .alert && alertKind == .volume) ? 1 : 0
        aBat.target = (mode == .alert && alertKind == .battery) ? 1 : 0
        aPods.target = (mode == .alert && alertKind == .pods) ? 1 : 0
        aAuth.target = (mode == .alert && alertKind == .auth) ? 1 : 0
        aPerm.target = (mode == .alert && alertKind == .permission) ? 1 : 0
        aRing.step(dt)
        aSilent.step(dt)
        aVolS.step(dt)
        aBat.step(dt)
        aPods.step(dt)
        aAuth.step(dt)
        aPerm.step(dt)

        if !expanded && card != nil && time > alertUntil + 0.9 { card = nil }

        if mode == .alert && alertKind != .volume {
            let silentNow = (alertKind == .silent)
            let anyShown = aRing.x > 0.02 || aSilent.x > 0.02
            bellSlide.target = silentNow ? 1.0 : 0.0
            slashT.target = silentNow ? 1.0 : 0.0
            if !anyShown { bellSlide.snap(bellSlide.target) }
        }
        bellSlide.step(dt)
        slashT.step(dt)

        sm(&volShown, VolumeControl.shared.muted ? 0 : CGFloat(VolumeControl.shared.volume), 20, 20)

        let silentAlert = (mode == .alert && alertKind == .silent)
        sm(&glowR, silentAlert ? 1 : 0, 6, 4.5)
        sm(&glowW, (!silentAlert && playingNow) ? 1 : 0, 4.5, 4.5)

        let vw = volWaves()
        for i in 0..<3 { sm(&waveAmt[i], i < vw ? 1 : 0, 16, 16) }
        sm(&muteAmt, VolumeControl.shared.muted ? 1 : 0, 16, 16)

        let cx = canvas.width * 0.5
        let top = topInset
        let w = max(20 * S, CGFloat(sw.x))
        let h = max(14 * S, CGFloat(sh.x))
        let p = CGFloat(press.x)
        let nL = cx - w / 2 - 3 * S * p
        let nR = cx + w / 2 + 3 * S * p
        let nB = top + h + 2 * S * p
        var L = nL + CGFloat(sL.x)
        var R = nR + CGFloat(sR.x)
        var B = nB + CGFloat(sB.x)
        if R - L < 20 * S {
            let mm = (L + R) / 2
            L = mm - 10 * S
            R = mm + 10 * S
        }
        if B - top < 14 * S { B = top + 14 * S }
        isl = CGRect(x: L, y: top, width: R - L, height: B - top)

        if firstFrame { pL = L; pR = R; pB = B; firstFrame = false }
        let speed = (abs(L - pL) + abs(R - pR) + abs(B - pB)) / CGFloat(max(dt, 0.0005)) / S
        let stretch = (abs(CGFloat(sL.x)) + abs(CGFloat(sR.x)) + abs(CGFloat(sB.x))) / S
        let blurTarget = clampf(speed * 0.0055 + stretch * 0.05, 0, 11) * S
        blur += (blurTarget - blur) * (1 - exp(-18 * CGFloat(dt)))
        pL = L; pR = R; pB = B

        let t01 = clampf(CGFloat(ex.x), 0, 1)
        radius = min(lerpf(18.5 * S, 32 * S, t01), (R - L) / 2, (B - top) / 2)
        let nw = max(1, nR - nL)
        let nh = max(1, nB - top)
        sx = (R - L) / nw
        sy = (B - top) / nh
        tx = L - nL * sx
        ty = top * (1 - sy)
        xf = CGAffineTransform(scaleX: sx, y: sy).concatenating(CGAffineTransform(translationX: tx, y: ty))
        lay = ComputeLayout(cL: nL, cT: top, cR: nR, cB: nB, tRaw: CGFloat(ex.x))

        topmostTimer += dt
        if topmostTimer > 2.0 && !searchMode { topmostTimer = 0 }

        animating = sw.moving || sh.moving || ex.moving || sL.moving || sR.moving || sB.moving
            || press.moving || down || (playingNow && vMedia > 0.02)
            || abs(vMedia - (showMedia ? 1 : 0)) > 0.01
            || abs(vAlert - (mode == .alert ? 1 : 0)) > 0.01
            || abs(vCal - ((!has && !searchMode) ? 1 : 0)) > 0.01
            || searchMode || artFade < 0.99
            || abs(playT - (playingNow ? 1 : 0)) > 0.01
            || expanded || hoverT > 0 || time < alertUntil
            || aRing.moving || aSilent.moving || aVolS.moving
            || aBat.moving || aPods.moving || aAuth.moving || aPerm.moving
            || abs(vCard - ((expanded && card != nil && !searchMode) ? 1 : 0)) > 0.01
            || (authRunning && card == .auth)
            || bellSlide.moving || slashT.moving
            || glowR > 0.01 || glowW > 0.01 || blur > 0.15
    }

    func volWaves() -> Int {
        if VolumeControl.shared.muted { return 0 }
        let v = VolumeControl.shared.volume
        if v > 0.66 { return 3 }
        if v > 0.33 { return 2 }
        if v > 0.01 { return 1 }
        return 0
    }

    func alertShowsSilenceOrRing() -> Bool {
        return (alertKind == .silent || alertKind == .ring) && time < alertUntil
    }

    func pollVolume() {
        VolumeControl.shared.refresh()
        let vc = VolumeControl.shared
        let silentNow = vc.muted || vc.volume <= 0.005
        let changed = lastVolRemote >= 0 && abs(vc.volume - lastVolRemote) > 0.004
        lastVolRemote = vc.volume
        if silentKnown && silentNow != silentState {
            triggerAlert(silentNow ? .silent : .ring, 2.4)
        } else if changed && !silentNow && time > volHoldUntil && !alertShowsSilenceOrRing() && !featureAlertActive() {
            triggerAlert(.volume, 1.6)
        }
        silentState = silentNow
        silentKnown = true
    }

    func setVolume(_ v: Float) {
        let v = min(max(v, 0), 1)
        VolumeControl.shared.setVolume(v)
        volShown = CGFloat(v)
        lastVolRemote = v
        volHoldUntil = time + 0.5
        let silentNow = VolumeControl.shared.muted || v <= 0.005
        if silentKnown && silentNow != silentState {
            triggerAlert(silentNow ? .silent : .ring, 2.4)
        } else if !expanded && !silentNow && !alertShowsSilenceOrRing() && !featureAlertActive() {
            triggerAlert(.volume, 1.6)
        }
        silentState = silentNow
        silentKnown = true
    }

    func scroll(_ dy: CGFloat, _ precise: Bool) {
        guard dy != 0 else { return }
        let step: Float = precise ? 0.006 : 0.04
        setVolume(VolumeControl.shared.volume + Float(dy) * step)
    }

    func containsPoint(_ p: CGPoint) -> Bool {
        let m = 2 * S
        return p.x >= isl.minX - m && p.x <= isl.maxX + m && p.y >= isl.minY - m && p.y <= isl.maxY + m
    }

    func wantsMouseEvents() -> Bool {
        if down { return true }
        return containsPoint(pointer)
    }

    func hitTest(_ px: CGFloat, _ py: CGFloat) -> Hit {
        let l = lay
        let x = (px - tx) / sx
        let y = (py - ty) / sy
        if !expanded || ex.x < 0.75 { return .body }
        if let c = card {
            if c == .pods && l.podModeChip.contains(CGPoint(x: x, y: y)) { return .podmode }
            if c == .battery && l.cardHint.contains(CGPoint(x: x, y: y)) { return .settings }
            if c == .pods && l.podHint.contains(CGPoint(x: x, y: y)) { return .settings }
            return .body
        }
        if searchMode {
            if l.bSpot.contains(CGPoint(x: x, y: y)) { return .spot }
            if l.bYt.contains(CGPoint(x: x, y: y)) { return .yt }
            if l.field.contains(CGPoint(x: x, y: y)) { return .field }
            return .body
        }
        if !has { return .body }
        func near(_ p: CGPoint, _ r: CGFloat) -> Bool { abs(x - p.x) < r && abs(y - p.y) < r }
        if near(l.play, 28 * S) { return .play }
        if near(l.prev, 26 * S) { return .prev }
        if near(l.next, 26 * S) { return .next }
        if near(l.vol, 22 * S) { return .vol }
        if near(l.srch, 22 * S) { return .srch }
        let br = CGRect(x: l.bar.minX - 6 * S, y: l.bar.minY - 14 * S, width: l.bar.width + 12 * S, height: l.bar.height + 28 * S)
        if br.contains(CGPoint(x: x, y: y)) { return .seek }
        return .body
    }

    func updateSeek(_ x: CGFloat) {
        let lx = (x - tx) / sx
        seekFrac = clampf((lx - lay.bar.minX) / max(1, lay.bar.width), 0, 1)
    }

    func commitSeek() {
        guard dur > 0 else { return }
        let p = Double(seekFrac) * dur
        seekPos = p
        seekHoldUntil = time + 1.0
        NowPlaying.shared.seek(p)
    }

    func mouseDown(_ p: CGPoint) {
        guard containsPoint(p) else { return }
        down = true
        moved = false
        seeking = false
        dragging = false
        pressedHit = hitTest(p.x, p.y)
        startPt = p
        if pressedHit == .seek {
            seeking = true
            updateSeek(p.x)
        } else {
            dragging = true
            sL.cfg(0.09, 1.0)
            sR.cfg(0.09, 1.0)
            sB.cfg(0.09, 1.0)
        }
        press.cfg(0.18, 0.8)
    }

    func mouseDragged(_ p: CGPoint) {
        guard down else { return }
        if seeking {
            updateSeek(p.x)
            return
        }
        let dx = p.x - startPt.x
        let dy = p.y - startPt.y
        if !moved && sqrt(dx * dx + dy * dy) > 5 * S { moved = true }
        if moved { setDragTargets(dx, dy) }
    }

    func mouseUp(_ p: CGPoint) {
        guard down else { return }
        down = false
        if seeking {
            seeking = false
            updateSeek(p.x)
            commitSeek()
            return
        }
        dragging = false
        sL.cfg(0.50, 0.42)
        sR.cfg(0.50, 0.42)
        sB.cfg(0.50, 0.42)
        sL.target = 0
        sR.target = 0
        sB.target = 0
        if !moved { handleClick(pressedHit) }
    }

    func setDragTargets(_ dx: CGFloat, _ dy: CGFloat) {
        let S = self.S
        let exAmt = rubber(abs(dx), 170 * S)
        let eyAmt = dy >= 0 ? rubber(dy, 150 * S) : -rubber(-dy, 16 * S)
        var tL: CGFloat
        var tR: CGFloat
        if dx >= 0 {
            tR = exAmt
            tL = 0.16 * exAmt
        } else {
            tL = -exAmt
            tR = -0.16 * exAmt
        }
        let sq = dy > 0 ? 0.05 * eyAmt : 0
        tL += sq
        tR -= sq
        sL.target = Double(tL)
        sR.target = Double(tR)
        sB.target = Double(eyAmt)
    }

    func handleClick(_ h: Hit) {
        if !expanded { expanded = true; return }
        switch h {
        case .play:
            overridePlay = !playingNow
            overridePlayMin = time + 0.45
            overridePlayUntil = time + 4.0
            NowPlaying.shared.togglePlay()
        case .next: NowPlaying.shared.next()
        case .prev: NowPlaying.shared.prev()
        case .vol:
            VolumeControl.shared.toggleMute()
            volHoldUntil = time + 0.5
        case .srch: enterSearch()
        case .spot: doSearch(youtube: false)
        case .yt: doSearch(youtube: true)
        case .podmode: AirPodsMonitor.shared.cycleMode()
        case .settings: openSettings()
        default: break
        }
    }

    func openSettings() {
        let batteryURL = "x-apple.systempreferences:com.apple.Battery-Settings.extension"
        let batteryOld = "x-apple.systempreferences:com.apple.preference.battery"
        let btURL = "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension"
        let btOld = "x-apple.systempreferences:com.apple.preference.bluetooth"
        let first = card == .battery ? batteryURL : btURL
        let second = card == .battery ? batteryOld : btOld
        if let u = URL(string: first), NSWorkspace.shared.open(u) { return }
        if let u = URL(string: second) { NSWorkspace.shared.open(u) }
    }

    func enterSearch() {
        searchMode = true
        query = ""
        searchActive(true)
    }

    func exitSearch() {
        guard searchMode else { return }
        searchMode = false
        searchActive(false)
    }

    func doSearch(youtube: Bool) {
        guard !query.isEmpty else { return }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let enc = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        if youtube {
            if let u = URL(string: "https://www.youtube.com/results?search_query=" + enc) {
                NSWorkspace.shared.open(u)
            }
        } else if let u = URL(string: "spotify:search:" + enc) {
            if !NSWorkspace.shared.open(u), let w = URL(string: "https://open.spotify.com/search/" + enc) {
                NSWorkspace.shared.open(w)
            }
        }
        exitSearch()
    }

    func handleKey(_ e: NSEvent) -> Bool {
        guard searchMode else { return false }
        switch e.keyCode {
        case 53:
            exitSearch()
            return true
        case 36, 76:
            doSearch(youtube: e.modifierFlags.contains(.command))
            return true
        case 51:
            if !query.isEmpty { query.removeLast() }
            return true
        default:
            break
        }
        if let chars = e.characters {
            for scalar in chars.unicodeScalars where scalar.value >= 32 && scalar.value != 127 {
                if query.count < 200 { query.unicodeScalars.append(scalar) }
            }
            return true
        }
        return false
    }

    func snapshotSetup() {
        ex.snap(1)
        isl = CGRect(x: 64, y: 36, width: 372, height: 196)
        radius = 36
        sx = 1
        sy = 1
        tx = 0
        ty = 0
        xf = .identity
        lay = ComputeLayout(cL: isl.minX, cT: isl.minY, cR: isl.maxX, cB: isl.maxY, tRaw: 1)
        vCal = 1
        vMedia = 0
        vText = 0
        vSearch = 0
        vAlert = 0
        vMedia = 0
        playT = 0
        has = false
        expanded = true
    }
}
