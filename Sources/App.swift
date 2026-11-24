import AppKit
import ImageIO

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { Island.shared.searchMode }
    override var canBecomeMain: Bool { false }
}

final class IslandView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        return Island.shared.containsPoint(p) ? self : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        renderIsland(cg, size: bounds.size)
    }

    override func mouseDown(with event: NSEvent) {
        Island.shared.mouseDown(convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        Island.shared.mouseDragged(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        Island.shared.mouseUp(p)
        if Island.shared.searchMode { window?.makeFirstResponder(self) }
    }

    override func rightMouseDown(with event: NSEvent) {
        let m = NSMenu()
        m.addItem(withTitle: "Preview “Ring” alert", action: #selector(previewRing), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview “Silent” alert", action: #selector(previewSilent), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview volume pill", action: #selector(previewVolume), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview battery warning", action: #selector(previewBattery), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview AirPods connection", action: #selector(previewPods), keyEquivalent: "").target = self
        m.addItem(withTitle: "Authenticate with Touch ID", action: #selector(runAuth), keyEquivalent: "").target = self
        m.addItem(.separator())
        m.addItem(withTitle: "Quit MacLand", action: #selector(quitApp), keyEquivalent: "q").target = self
        NSMenu.popUpContextMenu(m, with: event, for: self)
    }

    override func scrollWheel(with event: NSEvent) {
        Island.shared.scroll(event.scrollingDeltaY, event.hasPreciseScrollingDeltas)
    }

    override func keyDown(with event: NSEvent) {
        if Island.shared.handleKey(event) { return }
        super.keyDown(with: event)
    }

    @objc private func previewRing() { Island.shared.triggerAlert(.ring, 2.4) }
    @objc private func previewSilent() { Island.shared.triggerAlert(.silent, 2.4) }
    @objc private func previewVolume() { Island.shared.triggerAlert(.volume, 2.0) }
    @objc private func previewBattery() {
        var b = Island.shared.battery
        if !b.present { b.present = true; b.percent = 14; b.minutes = 74 }
        Island.shared.battery = b
        Island.shared.triggerAlert(.battery, 10)
    }
    @objc private func previewPods() {
        var s = PodsState()
        s.connected = true
        s.name = "Shea's AirPods"
        s.left = 75
        s.right = 70
        s.caseLevel = 45
        s.listening = 2
        Island.shared.pods = s
        Island.shared.triggerAlert(.pods, 7)
    }
    @objc private func runAuth() { AuthService.shared.authenticate() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: IslandPanel!
    private var view: IslandView!
    private var statusItem: NSStatusItem?
    private var loop: Timer?
    private var lastFrame: CFTimeInterval = CACurrentMediaTime()
    private var lastDraw: CFTimeInterval = 0
    private var lastVolPoll: CFTimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NowPlaying.shared.start()
        CalendarService.shared.start()
        BatteryMonitor.shared.start()
        AirPodsMonitor.shared.start()
        AuthService.shared.start()

        let island = Island.shared
        island.bootstrap()
        island.S = 1

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let w: CGFloat = 720
        let h: CGFloat = 460
        let frame = CGRect(x: screen.frame.midX - w / 2,
                           y: screen.frame.maxY - h,
                           width: w,
                           height: h)

        panel = IslandPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none

        view = IslandView(frame: CGRect(x: 0, y: 0, width: w, height: h))
        panel.contentView = view
        panel.orderFrontRegardless()

        island.canvas = CGSize(width: w, height: h)
        island.searchActive = { [weak self] on in
            guard let self = self else { return }
            if on {
                NSApp.activate(ignoringOtherApps: true)
                self.panel.orderFrontRegardless()
                self.panel.makeKey()
                self.panel.makeFirstResponder(self.view)
            } else {
                self.panel.resignKey()
                self.panel.orderFrontRegardless()
            }
        }

        setupStatusItem()

        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.frameTick() }
        RunLoop.main.add(t, forMode: .common)
        loop = t
    }

    private func frameTick() {
        let now = CACurrentMediaTime()
        var dt = now - lastFrame
        lastFrame = now
        if dt > 0.05 { dt = 0.05 }
        if dt <= 0 { dt = 0.001 }

        let mouse = NSEvent.mouseLocation
        let pf = panel.frame
        Island.shared.pointer = CGPoint(x: mouse.x - pf.minX, y: pf.maxY - mouse.y)

        if now - lastVolPoll > 0.12 {
            lastVolPoll = now
            Island.shared.pollVolume()
        }

        Island.shared.update(dt)

        let ignore = !Island.shared.wantsMouseEvents()
        if panel.ignoresMouseEvents != ignore { panel.ignoresMouseEvents = ignore }

        if Island.shared.animating || now - lastDraw > 1.0 {
            if now - lastDraw > 1.0 / 62.0 {
                lastDraw = now
                view.needsDisplay = true
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "MacLand")
                ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "MacLand")
        }
        let m = NSMenu()
        m.addItem(withTitle: "Preview “Ring” alert", action: #selector(menuRing), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview “Silent” alert", action: #selector(menuSilent), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview volume pill", action: #selector(menuVolume), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview battery warning", action: #selector(menuBattery), keyEquivalent: "").target = self
        m.addItem(withTitle: "Preview AirPods connection", action: #selector(menuPods), keyEquivalent: "").target = self
        m.addItem(withTitle: "Authenticate with Touch ID", action: #selector(menuAuth), keyEquivalent: "").target = self
        m.addItem(.separator())
        m.addItem(withTitle: "Quit MacLand", action: #selector(menuQuit), keyEquivalent: "q").target = self
        statusItem?.menu = m
    }

    @objc private func menuRing() { Island.shared.triggerAlert(.ring, 2.4) }
    @objc private func menuSilent() { Island.shared.triggerAlert(.silent, 2.4) }
    @objc private func menuVolume() { Island.shared.triggerAlert(.volume, 2.0) }
    @objc private func menuBattery() {
        var b = Island.shared.battery
        if !b.present { b.present = true; b.percent = 14; b.minutes = 74 }
        Island.shared.battery = b
        Island.shared.triggerAlert(.battery, 10)
    }
    @objc private func menuPods() {
        var s = PodsState()
        s.connected = true
        s.name = "Shea's AirPods"
        s.left = 75
        s.right = 70
        s.caseLevel = 45
        s.listening = 2
        Island.shared.pods = s
        Island.shared.triggerAlert(.pods, 7)
    }
    @objc private func menuAuth() { AuthService.shared.authenticate() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}

enum Snapshot {
    static func render(path: String) {
        CalendarService.shared.refreshNow()
        Island.shared.snapshotSetup()
        output(path)
    }

    static func renderBattery(path: String) {
        let I = Island.shared
        I.snapshotSetup()
        var b = BatteryState()
        b.present = true
        b.percent = 14
        b.minutes = 74
        I.battery = b
        I.card = .battery
        I.vCard = 1
        I.vCal = 0
        output(path)
    }

    static func renderPods(path: String) {
        let I = Island.shared
        I.snapshotSetup()
        var s = PodsState()
        s.connected = true
        s.name = "Shea's AirPods"
        s.left = 75
        s.right = 70
        s.caseLevel = 45
        s.listening = 2
        I.pods = s
        I.card = .pods
        I.vCard = 1
        I.vCal = 0
        output(path)
    }

    static func renderAuth(path: String) {
        let I = Island.shared
        I.snapshotSetup()
        I.card = .auth
        I.authRunning = true
        I.authLabel = "Authenticating"
        I.authStart = I.time - 0.7
        I.vCard = 1
        I.vCal = 0
        output(path)
    }

    static func renderMedia(path: String) {
        CalendarService.shared.refreshNow()
        let I = Island.shared
        I.snapshotSetup()
        I.has = true
        I.title = "Blinding Lights"
        I.artist = "The Weeknd"
        I.pos = 74
        I.dur = 201
        I.vCal = 0
        I.vMedia = 1
        I.vText = 1
        I.playT = 1
        I.waveTime = 1.4
        output(path)
    }

    private static func output(_ path: String) {
        let I = Island.shared
        let w: CGFloat = 500
        let h: CGFloat = 268
        let scale: CGFloat = 2
        guard let ctx = CGContext(data: nil, width: Int(w * scale), height: Int(h * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: gColorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: h)
        ctx.scaleBy(x: 1, y: -1)

        ctx.setFillColor(rgb(0.62, 0.64, 0.67))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        _ = I
        renderIsland(ctx, size: CGSize(width: w, height: h))

        guard let img = ctx.makeImage() else { return }
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
}
