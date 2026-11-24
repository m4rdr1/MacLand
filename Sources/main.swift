import AppKit

let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--snapshot"), i + 1 < arguments.count {
    Snapshot.render(path: arguments[i + 1])
    exit(0)
}
if let i = arguments.firstIndex(of: "--snapshot-media"), i + 1 < arguments.count {
    Snapshot.renderMedia(path: arguments[i + 1])
    exit(0)
}
if let i = arguments.firstIndex(of: "--snapshot-battery"), i + 1 < arguments.count {
    Snapshot.renderBattery(path: arguments[i + 1])
    exit(0)
}
if let i = arguments.firstIndex(of: "--snapshot-pods"), i + 1 < arguments.count {
    Snapshot.renderPods(path: arguments[i + 1])
    exit(0)
}
if let i = arguments.firstIndex(of: "--snapshot-auth"), i + 1 < arguments.count {
    Snapshot.renderAuth(path: arguments[i + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
