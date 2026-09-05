import AppKit

func watchClicks() {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
        guard let point = event.cgEvent?.location else { return }
        for name in ["usage.popup.panel", "usage.popup.footer", "usage.claude", "usage.codex"] {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
            process.arguments = ["--query", name]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { continue }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let item = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let bounds = item?["bounding_rects"] as? [String: [String: [Double]]] ?? [:]
            for rect in bounds.values {
                guard let origin = rect["origin"], let size = rect["size"], origin.count == 2, size.count == 2 else { continue }
                if CGRect(x: origin[0], y: origin[1], width: size[0], height: size[1]).contains(point) {
                    return
                }
            }
        }
        print("{\"outside\":true}")
        exit(0)
    }
    guard monitor != nil else { exit(1) }
    Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
        print("{\"outside\":false}")
        exit(0)
    }
    NSApplication.shared.run()
}

let arguments = CommandLine.arguments
if arguments.count == 2 && arguments[1] == "--watch" {
    watchClicks()
    exit(0)
}
let width: CGFloat = 480
let inset: CGFloat = 18
let scale: CGFloat = 2
let now = Date().timeIntervalSince1970
let source = try? Data(contentsOf: URL(fileURLWithPath: arguments[1]))
let snapshot = source.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
let providers = [("claude", "Claude", "FFAE87"), ("codex", "Codex", "80D3C2")]
func visibleWindows(_ id: String, _ data: [String: Any]) -> [[String: Any]] {
    let windows = data["windows"] as? [[String: Any]] ?? []
    return windows.filter { id != "codex" || !(($0["label"] as? String ?? "").localizedCaseInsensitiveContains("codex-spark")) }
}
let height = CGFloat(providers.reduce(36) { (total: Int, provider: (String, String, String)) -> Int in
    let data = snapshot[provider.0] as? [String: Any] ?? [:]
    let windows = visibleWindows(provider.0, data)
    return total + 90 + max(1, windows.count) * 54
})
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
context.shouldAntialias = true
context.cgContext.setShouldAntialias(true)
context.cgContext.setShouldSmoothFonts(true)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.scaleBy(x: scale, y: scale)
context.cgContext.translateBy(x: 0, y: height)
context.cgContext.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)

func color(_ hex: String) -> NSColor {
    let value = UInt32(hex, radix: 16)!
    return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
}

func font(_ size: CGFloat) -> NSFont {
    NSFont(name: "BerkeleyMono-Regular", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}

func clean(_ value: String) -> String {
    String(value.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }.joined().prefix(100))
}

@discardableResult
func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, hex: String = "CDD0DD", maxWidth: CGFloat = width - 2 * inset, align: NSTextAlignment = .left) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [.font: font(size), .foregroundColor: color(hex), .paragraphStyle: paragraph]
    let string = clean(value) as NSString
    string.draw(in: NSRect(x: x, y: y, width: maxWidth, height: size * 1.6), withAttributes: attributes)
    return min(maxWidth, string.size(withAttributes: attributes).width)
}

func line(_ y: CGFloat) {
    color("383D50").setFill()
    NSRect(x: inset, y: y, width: width - 2 * inset, height: 1).fill()
}

let formatter = DateFormatter()
formatter.locale = Locale(identifier: "en_US_POSIX")
formatter.timeZone = .current
formatter.dateFormat = "EEE dd MMM · HH:mm"
text("REMAINING SUBSCRIPTION QUOTA", x: inset, y: 17, size: 11, hex: "ACB0C0", align: .center)
var y: CGFloat = 47
for provider in providers {
    let data = snapshot[provider.0] as? [String: Any] ?? [:]
    let windows = visibleWindows(provider.0, data)
    text(provider.1 + " · " + (data["plan"] as? String ?? "Subscription"), x: inset, y: y, size: 17, hex: provider.2)
    y += 38
    if windows.isEmpty {
        text("Waiting for quota", x: inset, y: y, size: 12, hex: "ACB0C0")
        y += 54
    }
    for window in windows {
        let reset = window["resets_at"] as? Double
        let percent = window["remaining"] as? Double
        let valid = percent.map { $0.isFinite && (0...100).contains($0) } ?? false
        let remaining = valid && (reset == nil || reset! > now) ? percent : nil
        let value = remaining.map { "\(Int($0))% left" } ?? "Unknown"
        let resetLabel = reset.map { $0 <= now ? "reset passed · awaiting update" : "resets " + formatter.string(from: Date(timeIntervalSince1970: $0)) } ?? "reset not supplied"
        let rightWidth: CGFloat = 72
        let resetWidth = (resetLabel as NSString).size(withAttributes: [.font: font(11)]).width
        let available = width - 2 * inset - rightWidth - resetWidth - 16
        let nameWidth = text(window["label"] as? String ?? "Limit", x: inset, y: y, size: 13, maxWidth: max(80, available))
        text(resetLabel, x: inset + nameWidth + 8, y: y + 2, size: 11, hex: "ACB0C0", maxWidth: width - 2 * inset - rightWidth - nameWidth - 16)
        text(value, x: width - inset - rightWidth, y: y, size: 13, maxWidth: rightWidth, align: .right)
        let track = NSRect(x: inset, y: y + 25, width: width - 2 * inset, height: 6)
        color("383D50").setFill()
        NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
        if let remaining, remaining > 0 {
            color(provider.2).setFill()
            NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: track.width * remaining / 100, height: track.height), xRadius: 3, yRadius: 3).fill()
        }
        y += 54
    }
    let updated = data["updated_at"] as? Double
    let age = updated.map { max(0, Int((now - $0) / 60)) }
    let error = data["error"] as? String
    let status = error.map { $0 + (age.map { " · saved \($0)m ago" } ?? "") } ?? age.map { "Updated \($0)m ago" } ?? "Waiting for quota"
    text(status, x: inset, y: y - 5, size: 11, hex: error != nil || (updated.map { now - $0 > 1800 } ?? false) ? "F9E2AF" : "ACB0C0", align: .right)
    y += 24
    line(y)
    y += 28
}
NSGraphicsContext.restoreGraphicsState()
let output = bitmap.representation(using: .png, properties: [:])!
try output.write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
