import Cocoa
import ApplicationServices
import Foundation

// NOTE: If ~/.autolift exists, read it into `delayMs`, else default to 1000
let delayMs = Double(try String(contentsOfFile: NSHomeDirectory() + "/.autolift", encoding: .utf8)) ?? 1000

let trustOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(trustOpts) else {
    print("Grant Accessibility permission to this binary (or Terminal), then rerun.")
    exit(1)
}

let systemWide = AXUIElementCreateSystemWide()
var lastPos = NSPoint.zero
var lastMove = Date()
var handled = false
var enabledPids = Set<pid_t>()

@Sendable
func axAttr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

@Sendable
func axPoint(_ el: AXUIElement, _ name: String) -> CGPoint? {
    guard let v = axAttr(el, name), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var p = CGPoint.zero
    AXValueGetValue(v as! AXValue, .cgPoint, &p)
    return p
}

@Sendable
func axSize(_ el: AXUIElement, _ name: String) -> CGSize? {
    guard let v = axAttr(el, name), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var s = CGSize.zero
    AXValueGetValue(v as! AXValue, .cgSize, &s)
    return s
}

// Many apps (Chrome, Electron, etc.) only expose their accessibility tree when asked.
@Sendable
func enableAX(_ pid: pid_t) {
    guard enabledPids.insert(pid).inserted else { return }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
}

func windowUnder(_ p: NSPoint) -> (win: AXUIElement, pid: pid_t)? {
    guard let primary = NSScreen.screens.first else { return nil }
    let cgPt = CGPoint(x: p.x, y: primary.frame.maxY - p.y)   // top-left origin, like AX and CG

    // 1. Accessibility hit-test
    var el: AXUIElement?
    if AXUIElementCopyElementAtPosition(systemWide, Float(cgPt.x), Float(cgPt.y), &el) == .success,
       let e = el {
        var pid: pid_t = 0
        AXUIElementGetPid(e, &pid)
        if NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.dock" { return nil }
        enableAX(pid)
        if let w = axAttr(e, kAXWindowAttribute as String), CFGetTypeID(w) == AXUIElementGetTypeID() {
            return (w as! AXUIElement, pid)
        }
    }

    // 2. Fallback: topmost normal window per CoreGraphics, matched to its AX window by frame
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                kCGNullWindowID) as? [[String: Any]] else { return nil }
    for w in list {
        guard (w[kCGWindowLayer as String] as? Int) == 0,
              let pid = w[kCGWindowOwnerPID as String] as? pid_t,
              let bounds = w[kCGWindowBounds as String],
              let r = CGRect(dictionaryRepresentation: bounds as! CFDictionary),
              r.contains(cgPt) else { continue }
        enableAX(pid)
        let app = AXUIElementCreateApplication(pid)
        let wins = axAttr(app, kAXWindowsAttribute as String) as? [AXUIElement] ?? []
        for aw in wins {
            if let pos = axPoint(aw, kAXPositionAttribute as String),
               let sz = axSize(aw, kAXSizeAttribute as String),
               abs(pos.x - r.origin.x) < 3, abs(pos.y - r.origin.y) < 3, abs(sz.width - r.width) < 3 {
                return (aw, pid)
            }
        }
        return nil   // topmost window found but unmatched; don't raise one behind it
    }
    return nil
}

func raise(_ win: AXUIElement, _ pid: pid_t) {
    NSRunningApplication(processIdentifier: pid)?.activate()          // activate first...
    AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
    AXUIElementPerformAction(win, kAXRaiseAction as CFString)         // ...then raise the exact window
}

Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
    let p = NSEvent.mouseLocation
    if hypot(p.x - lastPos.x, p.y - lastPos.y) > 0.5 {
        lastPos = p
        lastMove = Date()
        handled = false
        return
    }
    guard !handled, Date().timeIntervalSince(lastMove) * 1000 >= delayMs else { return }
    handled = true
    if let r = windowUnder(p) { raise(r.win, r.pid) }
}

if CommandLine.arguments.contains("--test") {
    exit(runAllTests())
}

print("autolift running, delay \(Int(delayMs)) ms. Ctrl+C to quit.")
RunLoop.main.run()

// TESTS

func assertTest(_ condition: Bool, _ name: String) -> Bool {
    print("\(condition ? "PASS" : "FAIL"): \(name)")
    return condition
}

func testAxAttrMissingAttributeReturnsNil() -> Bool {
    let app = AXUIElementCreateApplication(getpid())
    return assertTest(axAttr(app, "AXDoesNotExistAttribute") == nil,
                      "axAttr returns nil for a nonexistent attribute")
}

func testAxPointMissingAttributeReturnsNil() -> Bool {
    let app = AXUIElementCreateApplication(getpid())
    return assertTest(axPoint(app, "AXDoesNotExistAttribute") == nil,
                      "axPoint returns nil when attribute is missing")
}

func testAxSizeMissingAttributeReturnsNil() -> Bool {
    let app = AXUIElementCreateApplication(getpid())
    return assertTest(axSize(app, "AXDoesNotExistAttribute") == nil,
                      "axSize returns nil when attribute is missing")
}

func testEnableAXRecordsPidOnce() -> Bool {
    let pid = getpid()
    enableAX(pid)
    let countAfterFirst = enabledPids.count
    enableAX(pid)
    let ok1 = assertTest(enabledPids.contains(pid),
                         "enableAX records the pid")
    let ok2 = assertTest(enabledPids.count == countAfterFirst,
                         "enableAX does not duplicate an already-enabled pid")
    return ok1 && ok2
}

func testWindowUnderFarOffscreenReturnsNil() -> Bool {
    let result = windowUnder(NSPoint(x: -1_000_000, y: -1_000_000))
    return assertTest(result == nil,
                      "windowUnder returns nil for a point far off every screen")
}

func testRaiseInvalidPidDoesNotCrash() -> Bool {
    // Should silently fail rather than crash.
    raise(systemWide, 999_999)
    return assertTest(true, "raise handles an invalid pid without crashing")
}

func runAllTests() -> Int32 {
    let tests: [() -> Bool] = [
        testAxAttrMissingAttributeReturnsNil,
        testAxPointMissingAttributeReturnsNil,
        testAxSizeMissingAttributeReturnsNil,
        testEnableAXRecordsPidOnce,
        testWindowUnderFarOffscreenReturnsNil,
        testRaiseInvalidPidDoesNotCrash,
    ]
    let results = tests.map { $0() }
    let passed = results.filter { $0 }.count
    print("\(passed)/\(results.count) tests passed")
    return passed == results.count ? 0 : 1
}
