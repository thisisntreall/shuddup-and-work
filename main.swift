import Cocoa
import QuartzCore

var prompts = [
    "Keep going.", "Continue.", "Pick up where you left off.", "Go ahead.",
    "Continue from where you stopped.", "Resume.", "Keep moving.", "Carry on.",
    "Okay, continue.", "Next.", "Keep at it.", "Go on.", "Proceed.",
    "Continue from your last point.", "Alright, keep going.", "Yeah, continue.",
    "Yep, go ahead.", "Right, keep going.", "Sure, continue.",
    "Go ahead and continue.", "Don't stop now.", "You're doing great, keep going.",
    "Keep it up.", "Yeah keep going.", "Looks good, continue.", "Mhm, keep going.",
    "Yep.", "Okay.", "What's next?", "And?", "Go.", "Keep working.",
    "Finish what you were doing.", "Stay on it.", "Don't lose momentum.",
]

let intervals: [(String, Int)] = [
    ("15 sec", 15), ("30 sec", 30), ("1 min", 60),
    ("2 min", 120), ("5 min", 300), ("10 min", 600),
]

let promptsFile = NSString("~/.continue-at-prompts.txt").expandingTildeInPath

func loadCustomPrompts() {
    let path = promptsFile
    if FileManager.default.fileExists(atPath: path),
       let content = try? String(contentsOfFile: path, encoding: .utf8) {
        let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("#") }
        if !lines.isEmpty { prompts = lines }
    }
}

func saveCustomPrompts() {
    let content = "# Shuddup&Work - Custom Messages\n# One message per line. Lines starting with # are ignored.\n\n" + prompts.joined(separator: "\n") + "\n"
    try? content.write(toFile: promptsFile, atomically: true, encoding: .utf8)
}

struct TerminalWindow {
    let id: Int
    let name: String
}

func getTerminalWindows() -> [TerminalWindow] {
    let script = """
    tell application "Terminal"
        set results to {}
        repeat with w in windows
            set wID to id of w
            set wName to name of w as text
            set end of results to (wID as text) & ":::" & wName
        end repeat
        set AppleScript's text item delimiters to "|||"
        return results as text
    end tell
    """
    guard let appleScript = NSAppleScript(source: script) else { return [] }
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error)
    guard error == nil, let output = result.stringValue, !output.isEmpty else { return [] }
    return output.components(separatedBy: "|||").compactMap { entry in
        let parts = entry.components(separatedBy: ":::")
        guard parts.count == 2, let id = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { return nil }
        return TerminalWindow(id: id, name: parts[1].trimmingCharacters(in: .whitespaces))
    }
}

func typeIntoWindow(windowId: Int, message: String) -> Bool {
    let charItems = message.map { c -> String in
        let ch = String(c)
        if ch == "\"" { return "\"\\\"\"" }
        if ch == "\\" { return "\"\\\\\"" }
        return "\"\(ch)\""
    }
    let charList = charItems.joined(separator: ", ")
    let script = """
    tell application "Terminal"
        set targetWindow to missing value
        repeat with w in windows
            if id of w is \(windowId) then
                set targetWindow to w
                exit repeat
            end if
        end repeat
        if targetWindow is missing value then return "window gone"
        activate
        set index of targetWindow to 1
    end tell
    delay 0.15
    tell application "System Events"
        tell process "Terminal"
            set charList to {\(charList)}
            repeat with c in charList
                keystroke (c as text)
                delay (0.02 + (random number from 0.0 to 0.07))
            end repeat
            delay 0.05
            key code 36
        end tell
    end tell
    return "ok"
    """
    guard let appleScript = NSAppleScript(source: script) else { return false }
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error)
    if error != nil { return sendFullLine(windowId: windowId, message: message) }
    return result.stringValue == "ok"
}

func sendFullLine(windowId: Int, message: String) -> Bool {
    let escaped = message.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let script = """
    tell application "Terminal"
        repeat with w in windows
            if id of w is \(windowId) then
                do script "\(escaped)" in (first tab of w)
                return "ok"
            end if
        end repeat
        return "window gone"
    end tell
    """
    guard let appleScript = NSAppleScript(source: script) else { return false }
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error)
    return error == nil && result.stringValue == "ok"
}

// MARK: - Views

class RingView: NSView {
    var progress: CGFloat = 0.0 { didSet { needsDisplay = true } }
    var ringColor = NSColor.white
    var trackColor = NSColor(white: 0.2, alpha: 1)
    var glowing = false

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 8
        let lineWidth: CGFloat = 4

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        trackColor.setStroke()
        track.stroke()

        if progress > 0 {
            let startAngle: CGFloat = 90
            let endAngle = startAngle - (360 * progress)
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            ringColor.setStroke()
            arc.stroke()

            if glowing {
                let glowArc = NSBezierPath()
                glowArc.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                glowArc.lineWidth = lineWidth + 8
                glowArc.lineCapStyle = .round
                ringColor.withAlphaComponent(0.15).setStroke()
                glowArc.stroke()
            }
        }
    }
}

class GradientView: NSView {
    var onDoubleClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        NSGradient(colors: [
            NSColor(white: 0.08, alpha: 1),
            NSColor(white: 0.12, alpha: 1),
        ])?.draw(in: bounds, angle: 270)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
}

class CardView: NSView {
    var bgColor = NSColor(white: 0.15, alpha: 0.8)
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        bgColor.setFill()
        path.fill()
        NSColor(white: 0.25, alpha: 0.4).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

class PillButton: NSButton {
    var fillColor: NSColor = .white
    var textColor: NSColor = .black
    var hovered = false { didSet { needsDisplay = true } }
    private var trackingArea: NSTrackingArea?

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        let color = hovered ? fillColor.highlight(withLevel: 0.2) ?? fillColor : fillColor
        color.setFill()
        path.fill()

        if hovered {
            let glow = NSBezierPath(roundedRect: bounds.insetBy(dx: -3, dy: -3), xRadius: bounds.height / 2 + 3, yRadius: bounds.height / 2 + 3)
            fillColor.withAlphaComponent(0.25).setStroke()
            glow.lineWidth = 2
            glow.stroke()
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: textColor, .paragraphStyle: style,
        ]
        let size = title.size(withAttributes: attrs)
        title.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height), withAttributes: attrs)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
}

class DrawButton: NSButton {
    var drawFunc: ((NSRect, Bool) -> Void)?
    var active = false { didSet { needsDisplay = true } }
    var hovered = false { didSet { needsDisplay = true } }
    var label = "" { didSet { toolTip = label } }
    private var trackingArea: NSTrackingArea?
    private var labelWindow: NSWindow?

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        let bg = active ? 0.28 : hovered ? 0.24 : 0.18
        NSColor(white: CGFloat(bg), alpha: 1).setFill()
        path.fill()
        drawFunc?(bounds, active || hovered)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        guard !label.isEmpty else { return }
        let lw = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 10, height: 18), styleMask: .borderless, backing: .buffered, defer: false)
        lw.backgroundColor = NSColor(white: 0.15, alpha: 0.95)
        lw.isOpaque = false
        lw.level = .floating

        let tf = NSTextField(labelWithString: label)
        tf.font = NSFont.systemFont(ofSize: 10)
        tf.textColor = NSColor(white: 0.85, alpha: 1)
        tf.sizeToFit()
        tf.frame.origin = NSPoint(x: 6, y: 2)
        lw.setContentSize(NSSize(width: tf.frame.width + 12, height: 18))
        lw.contentView?.addSubview(tf)

        let screenPt = self.window!.convertPoint(toScreen: self.convert(NSPoint(x: bounds.midX, y: bounds.minY), to: nil))
        lw.setFrameOrigin(NSPoint(x: screenPt.x - lw.frame.width / 2, y: screenPt.y - 22))
        lw.orderFront(nil)
        labelWindow = lw
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        labelWindow?.orderOut(nil)
        labelWindow = nil
    }
}

// MARK: - Icon drawing functions

func drawPin(_ rect: NSRect, active: Bool) {
    let color = active ? NSColor.white : NSColor(white: 0.55, alpha: 1)
    color.setStroke()
    color.setFill()

    let cx = rect.midX
    let cy = rect.midY

    if active {
        // Pushed-in pin: circle head + short stem + point
        let head = NSBezierPath(ovalIn: NSRect(x: cx - 4, y: cy + 2, width: 8, height: 8))
        head.fill()
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: cx, y: cy + 2))
        stem.line(to: NSPoint(x: cx, y: cy - 6))
        stem.lineWidth = 2
        stem.lineCapStyle = .round
        stem.stroke()
    } else {
        // Angled pin: tilted
        let head = NSBezierPath(ovalIn: NSRect(x: cx - 2, y: cy + 1, width: 7, height: 7))
        head.lineWidth = 1.5
        head.stroke()
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: cx + 1, y: cy + 1))
        stem.line(to: NSPoint(x: cx - 2, y: cy - 6))
        stem.lineWidth = 1.5
        stem.lineCapStyle = .round
        stem.stroke()
    }
}

func drawSize(_ rect: NSRect, active: Bool) {
    let color = active ? NSColor.white : NSColor(white: 0.55, alpha: 1)
    let style = NSMutableParagraphStyle()
    style.alignment = .center

    // Small person (left) + big person (right) using text
    let smallAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 9), .foregroundColor: color, .paragraphStyle: style,
    ]
    let bigAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14), .foregroundColor: color, .paragraphStyle: style,
    ]
    let s = "\u{1F464}"
    s.draw(in: NSRect(x: rect.minX - 2, y: rect.minY + 1, width: rect.width / 2, height: rect.height - 2), withAttributes: smallAttrs)
    s.draw(in: NSRect(x: rect.midX, y: rect.minY - 1, width: rect.width / 2, height: rect.height), withAttributes: bigAttrs)
}

func drawEdit(_ rect: NSRect, active: Bool) {
    let color = active ? NSColor.white : NSColor(white: 0.55, alpha: 1)
    color.setStroke()

    let cx = rect.midX
    let cy = rect.midY

    // Pencil icon
    let pencil = NSBezierPath()
    pencil.move(to: NSPoint(x: cx - 5, y: cy - 6))
    pencil.line(to: NSPoint(x: cx + 5, y: cy + 4))
    pencil.line(to: NSPoint(x: cx + 7, y: cy + 6))
    pencil.line(to: NSPoint(x: cx + 5, y: cy + 4))
    pencil.lineWidth = 2
    pencil.lineCapStyle = .round
    pencil.stroke()

    // Pencil tip
    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: cx - 5, y: cy - 6))
    tip.line(to: NSPoint(x: cx - 7, y: cy - 8))
    tip.lineWidth = 1.5
    tip.lineCapStyle = .round
    tip.stroke()

    // Lines
    for i in 0..<3 {
        let line = NSBezierPath()
        let y = cy - 3 + CGFloat(i) * 4
        line.move(to: NSPoint(x: cx - 6, y: y))
        line.line(to: NSPoint(x: cx - 1, y: y))
        line.lineWidth = 1
        line.stroke()
    }
}

func drawRefresh(_ rect: NSRect, active: Bool) {
    let color = active ? NSColor.white : NSColor(white: 0.55, alpha: 1)
    color.setStroke()

    let cx = rect.midX
    let cy = rect.midY
    let r: CGFloat = 6

    let arc = NSBezierPath()
    arc.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: 60, endAngle: 330)
    arc.lineWidth = 2
    arc.lineCapStyle = .round
    arc.stroke()

    // Arrow head
    let arrow = NSBezierPath()
    let endAngle: CGFloat = 60 * .pi / 180
    let ex = cx + r * cos(endAngle)
    let ey = cy + r * sin(endAngle)
    arrow.move(to: NSPoint(x: ex - 4, y: ey + 2))
    arrow.line(to: NSPoint(x: ex, y: ey))
    arrow.line(to: NSPoint(x: ex + 1, y: ey + 5))
    arrow.lineWidth = 2
    arrow.lineCapStyle = .round
    arrow.stroke()
}

func drawHistory(_ rect: NSRect, active: Bool) {
    let color = active ? NSColor.white : NSColor(white: 0.55, alpha: 1)
    color.setStroke()

    let cx = rect.midX
    let cy = rect.midY
    let r: CGFloat = 7

    // Clock circle
    let circle = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    circle.lineWidth = 1.5
    circle.stroke()

    // Clock hands
    let hands = NSBezierPath()
    hands.move(to: NSPoint(x: cx, y: cy))
    hands.line(to: NSPoint(x: cx, y: cy + 4))
    hands.move(to: NSPoint(x: cx, y: cy))
    hands.line(to: NSPoint(x: cx + 3, y: cy))
    hands.lineWidth = 1.5
    hands.lineCapStyle = .round
    hands.stroke()
}

// MARK: - App

enum ViewMode: Int { case full = 0, compact = 1, mini = 2 }
enum DockSide { case none, left, right }

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var bgView: GradientView!
    var ringView: RingView!
    var timerLabel: NSTextField!
    var statusLabel: NSTextField!
    var startButton: PillButton!
    var intervalPopup: NSPopUpButton!
    var windowPopup: NSPopUpButton!
    var targetListLabel: NSTextField!
    var targetIds: [Int] = []
    var targetNames: [String] = []

    var settingsCard: CardView!
    var targetCard: CardView!
    var historyText: NSTextView!
    var historyWindow: NSWindow?

    var iconBar: NSView!
    var sizeBtn: DrawButton!
    var editBtn: DrawButton!
    var pinBtn: DrawButton!
    var refreshBtn: DrawButton!

    var running = false
    var countdown = 0
    var totalInterval = 60
    var sendCount = 0
    var displayTimer: Timer?
    var pulseTimer: Timer?
    var terminalWindows: [TerminalWindow] = []
    var currentMode: ViewMode = .full
    var dockSide: DockSide = .none
    var pinned = true

    let accent = NSColor.white
    let stopColor = NSColor(red: 0.9, green: 0.2, blue: 0.25, alpha: 1)
    let dimText = NSColor(white: 0.45, alpha: 1)
    let lightText = NSColor(white: 0.8, alpha: 1)

    let fullSize = NSSize(width: 320, height: 440)
    let compactSize = NSSize(width: 240, height: 280)
    let miniSize = NSSize(width: 160, height: 160)

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadCustomPrompts()

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: fullSize.width, height: fullSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        w.title = "Shuddup&Work"
        w.center()
        w.isReleasedWhenClosed = false
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.level = .floating
        w.backgroundColor = .clear
        w.delegate = self
        w.minSize = miniSize

        let view = w.contentView!
        view.wantsLayer = true

        bgView = GradientView(frame: view.bounds)
        bgView.autoresizingMask = [.width, .height]
        bgView.onDoubleClick = { [weak self] in
            guard let self = self, self.currentMode == .mini else { return }
            self.switchToMode(.full)
        }
        view.addSubview(bgView)

        // -- Icon bar (top right) --
        let iconBarW: CGFloat = 165
        iconBar = NSView(frame: NSRect(x: fullSize.width - iconBarW - 8, y: fullSize.height - 34, width: iconBarW, height: 26))
        view.addSubview(iconBar)

        // Refresh
        refreshBtn = DrawButton(frame: NSRect(x: 0, y: 0, width: 28, height: 26))
        refreshBtn.drawFunc = drawRefresh
        refreshBtn.isBordered = false
        refreshBtn.target = self
        refreshBtn.action = #selector(refreshWindows)
        refreshBtn.label = "Refresh windows"
        iconBar.addSubview(refreshBtn)

        // History (clock)
        let histBtn = DrawButton(frame: NSRect(x: 33, y: 0, width: 28, height: 26))
        histBtn.drawFunc = drawHistory
        histBtn.isBordered = false
        histBtn.target = self
        histBtn.action = #selector(showHistory)
        histBtn.label = "History"
        iconBar.addSubview(histBtn)

        // Size (stick figures)
        sizeBtn = DrawButton(frame: NSRect(x: 66, y: 0, width: 28, height: 26))
        sizeBtn.drawFunc = drawSize
        sizeBtn.isBordered = false
        sizeBtn.target = self
        sizeBtn.action = #selector(cycleSize)
        sizeBtn.label = "Resize"
        iconBar.addSubview(sizeBtn)

        // Edit (pencil)
        editBtn = DrawButton(frame: NSRect(x: 99, y: 0, width: 28, height: 26))
        editBtn.drawFunc = drawEdit
        editBtn.isBordered = false
        editBtn.target = self
        editBtn.action = #selector(editMessages)
        editBtn.label = "Edit messages"
        iconBar.addSubview(editBtn)

        // Pin
        pinBtn = DrawButton(frame: NSRect(x: 132, y: 0, width: 28, height: 26))
        pinBtn.drawFunc = drawPin
        pinBtn.active = true
        pinBtn.isBordered = false
        pinBtn.target = self
        pinBtn.action = #selector(togglePin)
        pinBtn.label = "Pin on top"
        iconBar.addSubview(pinBtn)

        // Header
        let header = NSTextField(labelWithString: "Shuddup&Work")
        header.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
        header.textColor = .white
        header.frame = NSRect(x: 14, y: fullSize.height - 30, width: 120, height: 20)
        header.tag = 100
        view.addSubview(header)

        // -- Settings card --
        settingsCard = CardView(frame: NSRect(x: 14, y: fullSize.height - 95, width: fullSize.width - 28, height: 55))
        view.addSubview(settingsCard)

        let intLabel = NSTextField(labelWithString: "HOW OFTEN")
        intLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        intLabel.textColor = dimText
        intLabel.frame = NSRect(x: 12, y: 34, width: 100, height: 12)
        settingsCard.addSubview(intLabel)

        intervalPopup = NSPopUpButton(frame: NSRect(x: 8, y: 6, width: settingsCard.frame.width - 16, height: 24))
        intervalPopup.appearance = NSAppearance(named: .darkAqua)
        for (label, _) in intervals { intervalPopup.addItem(withTitle: label) }
        intervalPopup.selectItem(at: 2)
        settingsCard.addSubview(intervalPopup)

        // -- Target card --
        targetCard = CardView(frame: NSRect(x: 14, y: fullSize.height - 175, width: fullSize.width - 28, height: 70))
        view.addSubview(targetCard)

        let winLabel = NSTextField(labelWithString: "TARGET WINDOW")
        winLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        winLabel.textColor = dimText
        winLabel.frame = NSRect(x: 12, y: 50, width: 110, height: 12)
        targetCard.addSubview(winLabel)

        // + button next to title
        let addBtn = DrawButton(frame: NSRect(x: 122, y: 48, width: 18, height: 16))
        addBtn.drawFunc = { rect, active in
            let color = active ? NSColor.white : NSColor(white: 0.55, alpha: 1)
            color.setStroke()
            let plus = NSBezierPath()
            plus.move(to: NSPoint(x: rect.midX, y: rect.midY - 4))
            plus.line(to: NSPoint(x: rect.midX, y: rect.midY + 4))
            plus.move(to: NSPoint(x: rect.midX - 4, y: rect.midY))
            plus.line(to: NSPoint(x: rect.midX + 4, y: rect.midY))
            plus.lineWidth = 2
            plus.lineCapStyle = .round
            plus.stroke()
        }
        addBtn.isBordered = false
        addBtn.target = self
        addBtn.action = #selector(addTargetWindow)
        addBtn.label = "Add target"
        targetCard.addSubview(addBtn)

        windowPopup = NSPopUpButton(frame: NSRect(x: 8, y: 24, width: targetCard.frame.width - 16, height: 24))
        windowPopup.appearance = NSAppearance(named: .darkAqua)
        targetCard.addSubview(windowPopup)

        targetListLabel = NSTextField(labelWithString: "")
        targetListLabel.font = NSFont.systemFont(ofSize: 9)
        targetListLabel.textColor = NSColor(white: 0.55, alpha: 1)
        targetListLabel.frame = NSRect(x: 12, y: 4, width: targetCard.frame.width - 24, height: 14)
        targetListLabel.lineBreakMode = .byTruncatingTail
        targetCard.addSubview(targetListLabel)

        let targetClickBtn = NSButton(frame: NSRect(x: 12, y: 2, width: targetCard.frame.width - 24, height: 16))
        targetClickBtn.isTransparent = true
        targetClickBtn.target = self
        targetClickBtn.action = #selector(showTargetMenu)
        targetCard.addSubview(targetClickBtn)

        // -- Ring + Timer --
        let ringSize: CGFloat = 140
        let ringY: CGFloat = 98 + ((fullSize.height - 160 - 98) - ringSize) / 2
        ringView = RingView(frame: NSRect(x: (fullSize.width - ringSize) / 2, y: ringY, width: ringSize, height: ringSize))
        view.addSubview(ringView)

        timerLabel = NSTextField(labelWithString: "--:--")
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 38, weight: .bold)
        timerLabel.textColor = .white
        timerLabel.frame = NSRect(x: 0, y: ringY + 46, width: fullSize.width, height: 46)
        timerLabel.alignment = .center
        timerLabel.isBezeled = false
        timerLabel.drawsBackground = false
        view.addSubview(timerLabel)

        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = dimText
        statusLabel.frame = NSRect(x: 0, y: ringY - 18, width: fullSize.width, height: 14)
        statusLabel.alignment = .center
        view.addSubview(statusLabel)

        // -- Start button --
        startButton = PillButton(frame: NSRect(x: (fullSize.width - 60) / 2, y: 70, width: 60, height: 28))
        startButton.title = "Go"
        startButton.fillColor = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1)
        startButton.textColor = .white
        startButton.isBordered = false
        startButton.target = self
        startButton.action = #selector(toggleRunning)
        view.addSubview(startButton)

        // -- Logo button (bottom left) --
        let logoPath = Bundle.main.resourcePath! + "/profuctions.png"
        if let logoImage = NSImage(contentsOfFile: logoPath) {
            let logoBtn = NSButton(frame: NSRect(x: 10, y: 10, width: 80, height: 80))
            logoBtn.image = logoImage
            logoBtn.imageScaling = .scaleProportionallyUpOrDown
            logoBtn.isBordered = false
            logoBtn.target = self
            logoBtn.action = #selector(showAbout)
            logoBtn.tag = 200
            view.addSubview(logoBtn)
        }

        // -- History text view (created but not added to main window, used by popout) --
        historyText = NSTextView(frame: NSRect(x: 0, y: 0, width: 280, height: 200))
        historyText.isEditable = false
        historyText.isSelectable = false
        historyText.backgroundColor = .clear
        historyText.drawsBackground = false
        historyText.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        historyText.textColor = NSColor(white: 0.6, alpha: 1)
        historyText.string = "No nudges yet."

        refreshWindows()
        w.makeKeyAndOrderFront(nil)
        self.window = w
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - About screen

    var aboutWindow: NSWindow?

    @objc func showAbout() {
        if let aw = aboutWindow, aw.isVisible {
            aw.makeKeyAndOrderFront(nil)
            return
        }

        let aw = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        aw.title = "About Shuddup&Work"
        aw.center()
        aw.isReleasedWhenClosed = false
        aw.titlebarAppearsTransparent = true
        aw.titleVisibility = .hidden
        aw.backgroundColor = NSColor(white: 0.08, alpha: 1)

        let view = aw.contentView!

        let logoPath = Bundle.main.resourcePath! + "/profuctions.png"
        if let logoImage = NSImage(contentsOfFile: logoPath) {
            let logoView = NSButton(frame: NSRect(x: 50, y: 180, width: 300, height: 240))
            logoView.image = logoImage
            logoView.imageScaling = .scaleProportionallyUpOrDown
            logoView.isBordered = false
            logoView.target = self
            logoView.action = #selector(openProfuctions)
            view.addSubview(logoView)
        }

        let versionLabel = NSTextField(labelWithString: "Shuddup&Work 1.8")
        versionLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        versionLabel.textColor = .white
        versionLabel.frame = NSRect(x: 0, y: 130, width: 400, height: 22)
        versionLabel.alignment = .center
        view.addSubview(versionLabel)

        let rwrLabel = NSTextField(labelWithString: "RWR.2026")
        rwrLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        rwrLabel.textColor = NSColor(white: 0.5, alpha: 1)
        rwrLabel.frame = NSRect(x: 0, y: 105, width: 400, height: 18)
        rwrLabel.alignment = .center
        view.addSubview(rwrLabel)

        let linkLabel = NSTextField(labelWithString: "profuctions.com")
        linkLabel.font = NSFont.systemFont(ofSize: 12)
        linkLabel.textColor = NSColor(white: 0.7, alpha: 1)
        linkLabel.frame = NSRect(x: 0, y: 70, width: 400, height: 16)
        linkLabel.alignment = .center
        view.addSubview(linkLabel)

        let linkBtn = NSButton(frame: NSRect(x: 100, y: 65, width: 200, height: 24))
        linkBtn.title = ""
        linkBtn.isTransparent = true
        linkBtn.target = self
        linkBtn.action = #selector(openProfuctions)
        view.addSubview(linkBtn)

        let tagline = NSTextField(labelWithString: "digital creation, brought to light")
        tagline.font = NSFont.systemFont(ofSize: 11)
        tagline.textColor = NSColor(white: 0.35, alpha: 1)
        tagline.frame = NSRect(x: 0, y: 40, width: 400, height: 16)
        tagline.alignment = .center
        view.addSubview(tagline)

        aw.makeKeyAndOrderFront(nil)
        aboutWindow = aw
    }

    @objc func openProfuctions() {
        NSWorkspace.shared.open(URL(string: "https://profuctions.com")!)
    }

    @objc func showHistory() {
        if let hw = historyWindow, hw.isVisible {
            hw.makeKeyAndOrderFront(nil)
            return
        }

        let hw = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        hw.title = "History"
        hw.isReleasedWhenClosed = false
        hw.titlebarAppearsTransparent = true
        hw.backgroundColor = NSColor(white: 0.1, alpha: 1)
        hw.level = .floating

        // Position next to main window
        let mainFrame = window.frame
        hw.setFrameOrigin(NSPoint(x: mainFrame.maxX + 8, y: mainFrame.origin.y + mainFrame.height - 260))

        let hview = hw.contentView!

        let label = NSTextField(labelWithString: "HISTORY")
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = dimText
        label.frame = NSRect(x: 14, y: 230, width: 80, height: 14)
        hview.addSubview(label)

        let scroll = NSScrollView(frame: NSRect(x: 10, y: 10, width: 300, height: 216))
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.backgroundColor = .clear
        scroll.drawsBackground = false
        scroll.autoresizingMask = [.width, .height]

        // Move historyText into this window
        historyText.frame = NSRect(x: 0, y: 0, width: 280, height: 216)
        scroll.documentView = historyText
        hview.addSubview(scroll)

        hw.makeKeyAndOrderFront(nil)
        historyWindow = hw
    }

    // MARK: - Icon actions

    @objc func togglePin() {
        pinned = !pinned
        window.level = pinned ? .floating : .normal
        pinBtn.active = pinned
    }

    func windowDidMove(_ notification: Notification) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let vis = screen.visibleFrame
        let f = window.frame
        let snapDistance: CGFloat = 20

        if f.minX <= vis.minX + snapDistance && dockSide != .left {
            dockSide = .left
            let snapped = NSRect(x: vis.minX, y: f.origin.y, width: f.width, height: f.height)
            window.setFrame(snapped, display: true)
        } else if f.maxX >= vis.maxX - snapDistance && dockSide != .right {
            dockSide = .right
            let snapped = NSRect(x: vis.maxX - f.width, y: f.origin.y, width: f.width, height: f.height)
            window.setFrame(snapped, display: true)
        } else if f.minX > vis.minX + snapDistance && f.maxX < vis.maxX - snapDistance {
            dockSide = .none
        }
    }

    @objc func cycleSize() {
        let next = ViewMode(rawValue: (currentMode.rawValue + 1) % 3) ?? .full
        switchToMode(next)
    }

    func switchToMode(_ mode: ViewMode) {
        currentMode = mode

        let frame = window.frame
        let tw = mode == .full ? fullSize.width : mode == .compact ? compactSize.width : miniSize.width
        let th = mode == .full ? fullSize.height : mode == .compact ? compactSize.height : miniSize.height

        let newFrame = NSRect(
            x: frame.origin.x + (frame.width - tw) / 2,
            y: frame.origin.y + frame.height - th,
            width: tw, height: th
        )

        window.setFrame(newFrame, display: true, animate: true)

        // Now layout everything based on the actual final size
        let vw = tw
        let vh = th

        // Visibility
        settingsCard.isHidden = mode != .full
        targetCard.isHidden = mode != .full
        iconBar.isHidden = false
        startButton.isHidden = false

        if let header = window.contentView?.viewWithTag(100) as? NSTextField {
            header.isHidden = mode == .mini
            switch mode {
            case .full:
                header.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
                header.frame = NSRect(x: 14, y: vh - 30, width: 120, height: 20)
            case .compact:
                header.font = NSFont.systemFont(ofSize: 10, weight: .heavy)
                header.frame = NSRect(x: 10, y: vh - 26, width: 90, height: 16)
            case .mini:
                break
            }
        }

        // Icon bar — always top right, hidden in mini (double-click to expand)
        iconBar.isHidden = mode == .mini
        iconBar.frame = NSRect(x: vw - 173, y: vh - 34, width: 165, height: 26)

        // Logo — bottom left, always visible
        if let logoBtn = window.contentView?.viewWithTag(200) {
            logoBtn.isHidden = false
            switch mode {
            case .full:
                logoBtn.frame = NSRect(x: 10, y: 10, width: 80, height: 80)
            case .compact:
                logoBtn.frame = NSRect(x: 6, y: 6, width: 44, height: 44)
            case .mini:
                logoBtn.frame = NSRect(x: 4, y: 4, width: 32, height: 32)
            }
        }

        switch mode {
        case .full:
            settingsCard.frame = NSRect(x: 14, y: vh - 95, width: vw - 28, height: 55)
            targetCard.frame = NSRect(x: 14, y: vh - 175, width: vw - 28, height: 70)
            let ringSize: CGFloat = 140
            let availTop = vh - 175
            let availBot: CGFloat = 100
            let ringY = availBot + (availTop - availBot - ringSize) / 2
            ringView.frame = NSRect(x: (vw - ringSize) / 2, y: ringY, width: ringSize, height: ringSize)
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 38, weight: .bold)
            timerLabel.frame = NSRect(x: 0, y: ringY + 46, width: vw, height: 46)
            statusLabel.frame = NSRect(x: 0, y: ringY - 18, width: vw, height: 14)
            statusLabel.isHidden = false
            startButton.frame = NSRect(x: (vw - 60) / 2, y: 70, width: 60, height: 28)

        case .compact:
            let ringSize: CGFloat = 110
            let ringY = vh - 210
            ringView.frame = NSRect(x: (vw - ringSize) / 2, y: ringY, width: ringSize, height: ringSize)
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 30, weight: .bold)
            timerLabel.frame = NSRect(x: 0, y: ringY + 32, width: vw, height: 40)
            statusLabel.frame = NSRect(x: 0, y: ringY - 16, width: vw, height: 14)
            statusLabel.isHidden = false
            startButton.frame = NSRect(x: (vw - 60) / 2, y: 14, width: 60, height: 26)

        case .mini:
            let ringSize: CGFloat = 100
            let ringY = (vh - ringSize) / 2
            ringView.frame = NSRect(x: (vw - ringSize) / 2, y: ringY, width: ringSize, height: ringSize)
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .bold)
            timerLabel.frame = NSRect(x: 0, y: ringY + 32, width: vw, height: 34)
            statusLabel.isHidden = true
            startButton.isHidden = true
        }

        ringView.needsDisplay = true
        startButton.needsDisplay = true
        window.contentView?.needsDisplay = true
    }

    @objc func editMessages() {
        saveCustomPrompts()
        NSWorkspace.shared.openFile(promptsFile, withApplication: "TextEdit")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let alert = NSAlert()
            alert.messageText = "Edit your messages"
            alert.informativeText = "The messages file is open in TextEdit.\nOne message per line. Lines starting with # are ignored.\n\nClick Reload when done editing."
            alert.addButton(withTitle: "Reload")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                loadCustomPrompts()
            }
        }
    }

    // MARK: - Targets

    @objc func addTargetWindow() {
        let idx = windowPopup.indexOfSelectedItem
        guard idx >= 0, idx < terminalWindows.count else { return }
        let tw = terminalWindows[idx]
        if targetIds.contains(tw.id) { return }
        targetIds.append(tw.id)
        let short = tw.name.count <= 20 ? tw.name : String(tw.name.prefix(17)) + "..."
        targetNames.append(short)
        updateTargetLabel()
    }

    @objc func showTargetMenu() {
        guard !targetIds.isEmpty else { return }
        let menu = NSMenu()
        for (i, name) in targetNames.enumerated() {
            let item = NSMenuItem(title: "Remove: \(name)", action: #selector(removeTarget(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: "Clear all", action: #selector(clearTargets), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let pt = targetListLabel.convert(NSPoint(x: 0, y: targetListLabel.bounds.height), to: nil)
        let screenPt = window.convertPoint(toScreen: pt)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: targetListLabel.bounds.height), in: targetListLabel)
    }

    @objc func removeTarget(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx >= 0, idx < targetIds.count else { return }
        targetIds.remove(at: idx)
        targetNames.remove(at: idx)
        updateTargetLabel()
    }

    @objc func clearTargets() {
        targetIds = []
        targetNames = []
        updateTargetLabel()
    }

    func updateTargetLabel() {
        if targetNames.isEmpty {
            targetListLabel.stringValue = ""
        } else {
            targetListLabel.stringValue = "\(targetIds.count) target\(targetIds.count == 1 ? "" : "s"): " + targetNames.joined(separator: ", ")
        }
    }

    // MARK: - Window

    @objc func refreshWindows() {
        terminalWindows = getTerminalWindows()
        windowPopup.removeAllItems()
        for tw in terminalWindows {
            let display = tw.name.count <= 32 ? tw.name : String(tw.name.prefix(29)) + "..."
            windowPopup.addItem(withTitle: display)
        }
    }

    @objc func toggleRunning() {
        if running { stopRunning() } else { startRunning() }
    }

    func startRunning() {
        // If no targets added via "+", use whatever is selected in the dropdown
        if targetIds.isEmpty {
            let idx = windowPopup.indexOfSelectedItem
            guard idx >= 0, idx < terminalWindows.count else {
                statusLabel.stringValue = "Pick a target window"
                return
            }
            let tw = terminalWindows[idx]
            targetIds.append(tw.id)
            let short = tw.name.count <= 20 ? tw.name : String(tw.name.prefix(17)) + "..."
            targetNames.append(short)
            updateTargetLabel()
        }

        running = true
        sendCount = 0
        startButton.title = "Stop"
        startButton.fillColor = NSColor(red: 0.9, green: 0.2, blue: 0.25, alpha: 1)
        startButton.textColor = .white
        startButton.needsDisplay = true
        intervalPopup.isEnabled = false
        windowPopup.isEnabled = false

        totalInterval = intervals[intervalPopup.indexOfSelectedItem].1
        countdown = jitteredInterval()
        totalInterval = countdown

        statusLabel.stringValue = "Running"
        historyText.string = ""
        ringView.glowing = true
        startPulse()

        if currentMode == .mini { startButton.isHidden = true }

        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.running else { return }
            self.countdown -= 1
            let m = self.countdown / 60
            let s = self.countdown % 60
            self.timerLabel.stringValue = String(format: "%02d:%02d", m, s)
            self.ringView.progress = 1.0 - (CGFloat(self.countdown) / CGFloat(self.totalInterval))

            if self.countdown <= 0 {
                self.sendNudge()
                self.countdown = self.jitteredInterval()
                self.totalInterval = self.countdown
            }
        }
    }

    func startPulse() {
        var bright = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, self.running else { return }
            bright.toggle()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 1.5
                self.timerLabel.animator().textColor = bright ? NSColor.white : NSColor(white: 0.5, alpha: 1)
            }
        }
    }

    func jitteredInterval() -> Int {
        let base = Double(intervals[intervalPopup.indexOfSelectedItem].1)
        return max(5, Int(base * Double.random(in: 0.75...1.25)))
    }

    func sendNudge() {
        let msg = prompts[Int.random(in: 0..<prompts.count)]
        sendCount += 1
        let count = sendCount
        let ids = targetIds

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var anyOk = false
            for wid in ids {
                let ok = typeIntoWindow(windowId: wid, message: msg)
                if ok { anyOk = true }
            }
            DispatchQueue.main.async {
                if anyOk {
                    let ts = self.currentTime()
                    let entry = "\(ts)  \(msg) (\(ids.count) window\(ids.count == 1 ? "" : "s"))"
                    self.historyText.string = (self.historyText.string == "No nudges yet." ? "" : self.historyText.string)
                    self.historyText.string = self.historyText.string.isEmpty ? entry : entry + "\n" + self.historyText.string
                    self.statusLabel.stringValue = "Sent \(count) nudge\(count == 1 ? "" : "s")"
                } else {
                    self.statusLabel.stringValue = "All targets lost"
                    self.stopRunning()
                }
            }
        }
    }

    func currentTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"
        return f.string(from: Date())
    }

    func stopRunning() {
        running = false
        displayTimer?.invalidate()
        displayTimer = nil
        pulseTimer?.invalidate()
        pulseTimer = nil
        ringView.glowing = false
        ringView.progress = 0
        ringView.needsDisplay = true
        startButton.title = "Go"
        startButton.fillColor = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1)
        startButton.textColor = .white
        startButton.isHidden = false
        startButton.needsDisplay = true
        intervalPopup.isEnabled = true
        windowPopup.isEnabled = true
        targetIds = []
        targetNames = []
        updateTargetLabel()
        statusLabel.stringValue = "Stopped"
        timerLabel.stringValue = "--:--"
        timerLabel.textColor = .white
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func windowDidResize(_ notification: Notification) {
        // Re-layout on manual resize
        switchToMode(currentMode)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
