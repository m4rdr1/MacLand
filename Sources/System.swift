import Foundation
import AppKit
import IOKit.ps
import CoreAudio
import EventKit
import LocalAuthentication

struct BatteryState {
    var present = false
    var percent = 100
    var charging = false
    var plugged = false
    var minutes = -1
    var fullMinutes = -1
    var lowPower = false
}

final class BatteryMonitor {
    static let shared = BatteryMonitor()

    private(set) var state = BatteryState()
    private var timer: Timer?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        refresh()
        Island.shared.pollBattery()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
            Island.shared.pollBattery()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        var s = BatteryState()
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for src in list {
                guard let d = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any] else { continue }
                if let kind = d[kIOPSTypeKey] as? String, kind != kIOPSInternalBatteryType { continue }
                s.present = true
                s.percent = d[kIOPSCurrentCapacityKey] as? Int ?? 0
                s.charging = d[kIOPSIsChargingKey] as? Bool ?? false
                s.plugged = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                s.minutes = d[kIOPSTimeToEmptyKey] as? Int ?? -1
                s.fullMinutes = d[kIOPSTimeToFullChargeKey] as? Int ?? -1
                break
            }
        }
        s.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        state = s
    }
}

struct PodsState {
    var connected = false
    var name = ""
    var left = -1
    var right = -1
    var caseLevel = -1
    var single = -1
    var listening = -1
    var batteryAt: Double = 0
}

final class AirPodsMonitor {
    static let shared = AirPodsMonitor()

    private(set) var state = PodsState()
    private var timer: Timer?
    private var started = false
    private var fetching = false
    private var lastSerial = ""
    private let queue = DispatchQueue(label: "macland.pods")

    func start() {
        guard !started else { return }
        started = true
        poll()
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func poll() {
        guard let dev = VolumeControl.defaultDevice() else { return }
        let name = deviceName(dev)
        let pods = transport(dev) == Self.fourCC("blue") && Self.looksLikePods(name)
        var s = state
        s.connected = pods
        if pods { s.name = name }
        s.listening = pods ? readMode(dev) : -1
        if !pods {
            s.left = -1
            s.right = -1
            s.caseLevel = -1
            s.single = -1
        } else if Date().timeIntervalSince1970 - s.batteryAt > 20 {
            fetchBattery(name)
        }
        state = s
        let serial = "\(s.connected)|\(s.name)"
        if serial != lastSerial {
            lastSerial = serial
            if s.connected || !s.name.isEmpty {
                Island.shared.podsChanged(s)
            }
        }
    }

    func cycleMode() {
        guard let dev = VolumeControl.defaultDevice(), state.listening > 0 else { return }
        let order = [2, 3, 1]
        var idx = 0
        if let i = order.firstIndex(of: state.listening) { idx = (i + 1) % order.count }
        let next = order[idx]
        var a = AudioObjectPropertyAddress(mSelector: Self.fourCC("lstm"),
                                           mScope: kAudioObjectPropertyScopeGlobal,
                                           mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(dev, &a) else { return }
        var v = UInt32(next)
        if AudioObjectSetPropertyData(dev, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v) == noErr {
            state.listening = next
            Island.shared.podsModeChanged()
        }
    }

    private func fetchBattery(_ name: String) {
        guard !fetching else { return }
        fetching = true
        queue.async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPBluetoothDataType", "-json"]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            do { try p.run() } catch {
                DispatchQueue.main.async { self.fetching = false }
                return
            }
            p.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let parsed = Self.battery(data)
            DispatchQueue.main.async {
                self.fetching = false
                self.state.batteryAt = Date().timeIntervalSince1970
                guard self.state.connected, let b = parsed else { return }
                self.state.left = b.0
                self.state.right = b.1
                self.state.caseLevel = b.2
                self.state.single = b.3
            }
        }
    }

    private static func battery(_ data: Data) -> (Int, Int, Int, Int)? {
        guard let root = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        return findBattery(root)
    }

    private static func findBattery(_ obj: Any) -> (Int, Int, Int, Int)? {
        if let dict = obj as? [String: Any] {
            let minor = (dict["device_minorType"] as? String)?.lowercased() ?? ""
            let l = level(dict["device_batteryLevelLeft"])
            let r = level(dict["device_batteryLevelRight"])
            let c = level(dict["device_batteryLevelCase"])
            let m = level(dict["device_batteryLevelMain"])
            if l >= 0 || r >= 0 || c >= 0 || (m >= 0 && minor.contains("headphone")) {
                return (l, r, c, m)
            }
            for v in dict.values {
                if let x = findBattery(v) { return x }
            }
        } else if let arr = obj as? [Any] {
            for v in arr {
                if let x = findBattery(v) { return x }
            }
        }
        return nil
    }

    private static func level(_ v: Any?) -> Int {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String {
            return Int(s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) ?? -1
        }
        return -1
    }

    private func deviceName(_ d: AudioDeviceID) -> String {
        var a = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                           mScope: kAudioObjectPropertyScopeGlobal,
                                           mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var sz = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(d, &a, 0, nil, &sz, &name) == noErr,
              let cf = name?.takeRetainedValue() else { return "" }
        return cf as String
    }

    private func transport(_ d: AudioDeviceID) -> UInt32 {
        var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                           mScope: kAudioObjectPropertyScopeGlobal,
                                           mElement: kAudioObjectPropertyElementMain)
        var t: UInt32 = 0
        var sz = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(d, &a, 0, nil, &sz, &t) == noErr else { return 0 }
        return t
    }

    private func readMode(_ d: AudioDeviceID) -> Int {
        var a = AudioObjectPropertyAddress(mSelector: Self.fourCC("lstm"),
                                           mScope: kAudioObjectPropertyScopeGlobal,
                                           mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(d, &a) else { return -1 }
        var v: UInt32 = 0
        var sz = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(d, &a, 0, nil, &sz, &v) == noErr else { return -1 }
        let n = Int(v)
        return (n >= 1 && n <= 4) ? n : -1
    }

    static func fourCC(_ s: String) -> UInt32 {
        var r: UInt32 = 0
        for b in s.utf8 { r = (r << 8) + UInt32(b) }
        return r
    }

    private static func looksLikePods(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("airpods") || n.contains("beats") || n.contains("powerbeats")
    }
}

final class AuthService {
    static let shared = AuthService()

    private var started = false
    private var lastPerm = -99
    private var timer: Timer?

    func start() {
        guard !started else { return }
        started = true
        lastPerm = Int(EKEventStore.authorizationStatus(for: .event).rawValue)
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in self?.pollPermission() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func pollPermission() {
        let s = Int(EKEventStore.authorizationStatus(for: .event).rawValue)
        guard s != lastPerm else { return }
        lastPerm = s
        Island.shared.showPermission(granted(EKEventStore.authorizationStatus(for: .event)))
    }

    private func granted(_ s: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            if s == .fullAccess { return true }
        }
        return s == .authorized
    }

    func authenticate() {
        Island.shared.beginAuth()
        NSApp.activate(ignoringOtherApps: true)
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Island.shared.finishAuth(false, "Touch ID Unavailable")
            }
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Confirm it's you to continue") { ok, _ in
            DispatchQueue.main.async {
                Island.shared.finishAuth(ok, ok ? "Authenticated" : "Not Recognized")
            }
        }
    }
}
