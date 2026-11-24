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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
