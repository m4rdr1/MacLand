import AppKit
import CoreAudio
import EventKit
import Foundation

final class MediaState {
    static let shared = MediaState()
    var has = false
    var playing = false
    var title = ""
    var artist = ""
    var pos: Double = 0
    var dur: Double = 0
    var stamp = Date()
    var trackSerial = 0
    var artSerial = 0
    var artData: Data?
}

private typealias MRInfoBlock = @convention(block) (CFDictionary?) -> Void
private typealias MRPlayingBlock = @convention(block) (Bool) -> Void

final class NowPlaying {
    static let shared = NowPlaying()

    private var getInfo: (@convention(c) (DispatchQueue, MRInfoBlock) -> Void)?
    private var getPlaying: (@convention(c) (DispatchQueue, MRPlayingBlock) -> Void)?
    private var sendCmd: (@convention(c) (UInt32, CFDictionary?) -> Bool)?
    private var setElapsed: (@convention(c) (Double) -> Void)?

    private var timer: Timer?
    private var lastKey = ""
    private var helper: Process?
    private var helperBroken = false
    private var nextHelperTry: TimeInterval = 0

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let h = dlopen(path, RTLD_NOW) else { return }
        if let s = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(s, to: (@convention(c) (DispatchQueue, MRInfoBlock) -> Void).self)
        }
        if let s = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getPlaying = unsafeBitCast(s, to: (@convention(c) (DispatchQueue, MRPlayingBlock) -> Void).self)
        }
        if let s = dlsym(h, "MRMediaRemoteSendCommand") {
            sendCmd = unsafeBitCast(s, to: (@convention(c) (UInt32, CFDictionary?) -> Bool).self)
        }
        if let s = dlsym(h, "MRMediaRemoteSetElapsedTime") {
            setElapsed = unsafeBitCast(s, to: (@convention(c) (Double) -> Void).self)
        }
    }

    func start() {
        startHelper()
        tick()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func startHelper() {
        guard helper == nil, !helperBroken else { return }
        nextHelperTry = Date().timeIntervalSince1970 + 3
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/perl"),
              let dylib = Bundle.main.path(forResource: "MacLandMedia", ofType: "dylib"),
              let script = Bundle.main.path(forResource: "macland-media", ofType: "pl") else {
            helperBroken = true
            return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script, dylib]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.helper = nil }
        }
        do { try p.run() } catch {
            helperBroken = true
            return
        }
        helper = p
        let handle = pipe.fileHandleForReading
        DispatchQueue(label: "macland.media.reader").async { [weak self] in
            self?.readLoop(handle)
        }
    }

    private func readLoop(_ fh: FileHandle) {
        func readExact(_ n: Int) -> Data? {
            var out = Data()
            while out.count < n {
                let part = fh.readData(ofLength: n - out.count)
                if part.isEmpty { return nil }
                out.append(part)
            }
            return out
        }
        while true {
            var header = Data()
            while true {
                let b = fh.readData(ofLength: 1)
                if b.isEmpty { return }
                if b[b.startIndex] == 0x0A { break }
                header.append(b)
                if header.count > 32 { return }
            }
            guard let len = Int(String(data: header, encoding: .utf8) ?? ""), len >= 0,
                  let payload = readExact(len) else { return }
            guard let plist = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil),
                  let dict = plist as? [String: Any] else { continue }
            DispatchQueue.main.async { [weak self] in
                self?.apply(dict as CFDictionary)
            }
        }
    }

    private func tick() {
        if helper == nil && !helperBroken && Date().timeIntervalSince1970 > nextHelperTry {
            startHelper()
        }
        guard helper == nil else { return }
        if let f = getInfo {
            let block: MRInfoBlock = { [weak self] info in
                self?.apply(info)
            }
            f(DispatchQueue.main, block)
        }
        if let p = getPlaying {
            let block: MRPlayingBlock = { playing in
                MediaState.shared.playing = playing
            }
            p(DispatchQueue.main, block)
        }
    }

    private func apply(_ info: CFDictionary?) {
        let st = MediaState.shared
        guard let d = info as? [String: Any] else { reset(); return }
        let title = (d["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? ""
        let artist = (d["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
        if title.isEmpty && artist.isEmpty { reset(); return }

        let key = title + "\u{1}" + artist
        let dur = (d["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue ?? 0
        var pos = (d["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue ?? 0
        let rate = (d["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
        let ts = (d["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date) ?? Date()
        let playing = rate > 0.5
        if playing { pos += max(0, Date().timeIntervalSince(ts)) }
        if dur > 0 { pos = min(max(pos, 0), dur) }
        if pos < 0 { pos = 0 }

        st.has = true
        st.title = title
        st.artist = artist
        st.pos = pos
        st.dur = dur
        st.stamp = Date()
        if rate != 0 { st.playing = playing }

        if key != lastKey {
            lastKey = key
            st.trackSerial += 1
            st.artSerial += 1
            st.artData = nil
        }
        if st.artData == nil, let data = d["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
            st.artData = data
            st.artSerial += 1
        }
    }

    private func reset() {
        let st = MediaState.shared
        if !lastKey.isEmpty {
            lastKey = ""
            st.trackSerial += 1
            st.artSerial += 1
            st.artData = nil
        }
        st.has = false
        st.playing = false
    }

    func togglePlay() { _ = sendCmd?(2, nil) }
    func next() { _ = sendCmd?(4, nil) }
    func prev() { _ = sendCmd?(5, nil) }
    func seek(_ seconds: Double) { setElapsed?(seconds) }
}

// MARK: - System output volume

final class VolumeControl {
    static let shared = VolumeControl()

    var volume: Float = 0.5
    var muted = false
    var known = false

    private var dev = AudioDeviceID(0)
    private var elem: AudioObjectPropertyElement = 0

    static func address(_ sel: AudioObjectPropertySelector,
                        _ scope: AudioObjectPropertyScope,
                        _ e: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: e)
    }

    static func defaultDevice() -> AudioDeviceID? {
        var a = address(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, 0)
        var d = AudioDeviceID(0)
        var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
        let r = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &sz, &d)
        return (r == noErr && d != 0) ? d : nil
    }

    func refresh() {
        guard let d = Self.defaultDevice() else { return }
        dev = d
        if let v = getFloat(d, kAudioDevicePropertyVolumeScalar, 0) {
            elem = 0
            volume = v
        } else if let v = getFloat(d, kAudioDevicePropertyVolumeScalar, 1) {
            elem = 1
            volume = v
        }
        if let m = getU32(d, kAudioDevicePropertyMute, elem) {
            muted = m != 0
        } else if let m = getU32(d, kAudioDevicePropertyMute, 1) {
            muted = m != 0
        }
        known = true
    }

    func setVolume(_ v: Float) {
        if dev == 0 { refresh() }
        guard dev != 0 else { return }
        var val = min(max(v, 0), 1)
        var a = Self.address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, elem)
        AudioObjectSetPropertyData(dev, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &val)
        volume = val
    }

    func toggleMute() {
        if dev == 0 { refresh() }
        guard dev != 0 else { return }
        var m: UInt32 = muted ? 0 : 1
        var a = Self.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput, elem)
        AudioObjectSetPropertyData(dev, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
        muted = m != 0
    }

    private func getFloat(_ d: AudioDeviceID, _ sel: AudioObjectPropertySelector,
                          _ e: AudioObjectPropertyElement) -> Float32? {
        var a = Self.address(sel, kAudioObjectPropertyScopeOutput, e)
        guard AudioObjectHasProperty(d, &a) else { return nil }
        var v: Float32 = 0
        var sz = UInt32(MemoryLayout<Float32>.size)
        let r = AudioObjectGetPropertyData(d, &a, 0, nil, &sz, &v)
        return r == noErr ? v : nil
    }

    private func getU32(_ d: AudioDeviceID, _ sel: AudioObjectPropertySelector,
                        _ e: AudioObjectPropertyElement) -> UInt32? {
        var a = Self.address(sel, kAudioObjectPropertyScopeOutput, e)
        guard AudioObjectHasProperty(d, &a) else { return nil }
        var v: UInt32 = 0
        var sz = UInt32(MemoryLayout<UInt32>.size)
        let r = AudioObjectGetPropertyData(d, &a, 0, nil, &sz, &v)
        return r == noErr ? v : nil
    }
}

struct CalendarInfo {
    var weekday = "TUESDAY"
    var day = "24"
    var hasNext = true
    var nextLabel = "THURSDAY, 26 NOV"
    var nextTitle = "Thanksgiving"
    var status1 = "No events today"
    var status2 = "Your day is clear"
}

final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    private(set) var info = CalendarInfo()
    private var started = false

    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
    private static let nextFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    func start() {
        guard !started else { return }
        started = true
        refreshNow()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.refreshNow() }
        RunLoop.main.add(t, forMode: .common)
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refreshNow()
        }
        requestAccess()
    }

    private func hasAccess() -> Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return s == .fullAccess
        }
        return s == .authorized
    }

    private func requestAccess() {
        if hasAccess() { return }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] _, _ in
                DispatchQueue.main.async { self?.refreshNow() }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] _, _ in
                DispatchQueue.main.async { self?.refreshNow() }
            }
        }
    }

    func refreshNow() {
        let now = Date()
        let cal = Calendar.current
        var out = CalendarInfo()
        out.weekday = Self.weekdayFmt.string(from: now).uppercased()
        out.day = String(cal.component(.day, from: now))

        let today = todaysEvents(now)

        var nextTitle: String?
        var nextDate: Date?
        if hasAccess(), let end = cal.date(byAdding: .day, value: 30, to: now) {
            let events = store.events(matching: store.predicateForEvents(withStart: now, end: end, calendars: nil))
                .sorted { $0.startDate < $1.startDate }
            if let e = events.first, let title = e.title, !title.isEmpty {
                nextTitle = title
                nextDate = e.startDate
            }
        }
        if nextTitle == nil, let h = nextHoliday(after: now) {
            nextTitle = h.0
            nextDate = h.1
        }
        if let title = nextTitle, let date = nextDate {
            out.hasNext = true
            out.nextTitle = title
            out.nextLabel = Self.nextFmt.string(from: date).uppercased()
        } else {
            out.hasNext = false
            out.nextTitle = ""
            out.nextLabel = ""
        }

        if today.isEmpty {
            out.status1 = "No events today"
            out.status2 = "Your day is clear"
        } else if today.count == 1 {
            let e = today[0]
            out.status1 = "1 event today"
            out.status2 = e.isAllDay ? (e.title ?? "All day") : Self.timeFmt.string(from: e.startDate) + " · " + (e.title ?? "")
        } else {
            out.status1 = "\(today.count) events today"
            if let e = today.first {
                out.status2 = e.isAllDay ? (e.title ?? "All day") : "Next: " + Self.timeFmt.string(from: e.startDate) + " · " + (e.title ?? "")
            }
        }
        info = out
    }

    private func todaysEvents(_ now: Date) -> [EKEvent] {
        guard hasAccess() else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let all = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        return all.filter { $0.status != .canceled }.sorted { $0.startDate < $1.startDate }
    }

    private func nextHoliday(after date: Date) -> (String, Date)? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let year = cal.component(.year, from: date)
        for y in [year, year + 1] {
            for h in Self.holidays(year: y) where h.1 >= today {
                return (h.0, h.1)
            }
        }
        return nil
    }

    static func holidays(year: Int) -> [(String, Date)] {
        let cal = Calendar.current
        func day(_ month: Int, _ d: Int) -> Date? {
            cal.date(from: DateComponents(year: year, month: month, day: d))
        }
        func nth(_ month: Int, _ weekday: Int, _ n: Int) -> Date? {
            guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
            let wd = cal.component(.weekday, from: first)
            let d = 1 + ((weekday - wd + 7) % 7) + (n - 1) * 7
            return cal.date(from: DateComponents(year: year, month: month, day: d))
        }
        func last(_ month: Int, _ weekday: Int) -> Date? {
            guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
                  let range = cal.range(of: .day, in: .month, for: first) else { return nil }
            let lastDay = range.count
            guard let ld = cal.date(from: DateComponents(year: year, month: month, day: lastDay)) else { return nil }
            let wd = cal.component(.weekday, from: ld)
            let d = lastDay - ((wd - weekday + 7) % 7)
            return cal.date(from: DateComponents(year: year, month: month, day: d))
        }
        var list: [(String, Date)] = []
        if let x = day(1, 1) { list.append(("New Year's Day", x)) }
        if let x = nth(1, 2, 3) { list.append(("Martin Luther King Jr. Day", x)) }
        if let x = nth(2, 2, 3) { list.append(("Presidents' Day", x)) }
        if let x = last(5, 2) { list.append(("Memorial Day", x)) }
        if let x = day(7, 4) { list.append(("Independence Day", x)) }
        if let x = nth(9, 2, 1) { list.append(("Labor Day", x)) }
        if let x = nth(11, 5, 4) { list.append(("Thanksgiving", x)) }
        if let x = day(12, 25) { list.append(("Christmas", x)) }
        return list.sorted { $0.1 < $1.1 }
    }
}
