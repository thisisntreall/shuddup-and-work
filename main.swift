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
    var ringColor = NSColor(red: 0, green: 0.83, blue: 0.67, alpha: 1)
    var trackColor = NSColor(white: 0.15, alpha: 1)
    var glowing = false

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 8
        let lineWidth: CGFloat = 5

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
                ringColor.withAlphaComponent(0.2).setStroke()
                glowArc.stroke()
            }
        }
    }
}

class GradientView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(colors: [
            NSColor(red: 0.03, green: 0.15, blue: 0.30, alpha: 1),
            NSColor(red: 0.05, green: 0.22, blue: 0.40, alpha: 1),
        ])?.draw(in: bounds, angle: 270)
    }
}

class CardView: NSView {
    var bgColor = NSColor(red: 0.04, green: 0.18, blue: 0.34, alpha: 0.8)
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        bgColor.setFill()
        path.fill()
        NSColor(white: 0.2, alpha: 0.3).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

class PillButton: NSButton {
    var fillColor: NSColor = .systemGreen
    var textColor: NSColor = .black
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        fillColor.setFill()
        path.fill()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: textColor, .paragraphStyle: style,
        ]
        let size = title.size(withAttributes: attrs)
        title.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height), withAttributes: attrs)
    }
}

class IconButton: NSButton {
    var symbol: String = ""
    var iconColor = NSColor(white: 0.6, alpha: 1)
    var active = false
    var activeColor = NSColor(red: 0, green: 0.83, blue: 0.67, alpha: 1)

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor(white: 0.15, alpha: active ? 0.8 : 0.4).setFill()
        path.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: active ? activeColor : iconColor,
            .paragraphStyle: style,
        ]
        let size = symbol.size(withAttributes: attrs)
        symbol.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height), withAttributes: attrs)
    }
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

    var settingsCard: CardView!
    var targetCard: CardView!
    var historyCard: CardView!
    var historyText: NSTextView!

    var iconBar: NSView!
    var dockBtn: IconButton!
    var sizeBtn: IconButton!
    var editBtn: IconButton!
    var pinBtn: IconButton!

    var running = false
    var countdown = 0
    var totalInterval = 60
    var sendCount = 0
    var displayTimer: Timer?
    var pulseTimer: Timer?
    var terminalWindows: [TerminalWindow] = []
    var targetWindowId = 0
    var currentMode: ViewMode = .full
    var dockSide: DockSide = .none
    var pinned = true

    let accent = NSColor(red: 0, green: 0.83, blue: 0.67, alpha: 1)
    let stopColor = NSColor(red: 1, green: 0.25, blue: 0.35, alpha: 1)
    let dimText = NSColor(white: 0.4, alpha: 1)
    let lightText = NSColor(white: 0.85, alpha: 1)

    let fullSize = NSSize(width: 320, height: 530)
    let compactSize = NSSize(width: 220, height: 220)
    let miniSize = NSSize(width: 140, height: 140)

    var dockedWidth: CGFloat {
        guard let screen = window?.screen ?? NSScreen.main else { return 200 }
        return screen.visibleFrame.width / 8
    }

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
        view.addSubview(bgView)

        // -- Icon bar (top right) --
        iconBar = NSView(frame: NSRect(x: fullSize.width - 130, y: fullSize.height - 34, width: 122, height: 26))
        view.addSubview(iconBar)

        let iconSymbols = [
            ("[ ]", "size"),
            ("...", "edit"),
            ("pin", "pin"),
        ]
        for (i, (sym, tag)) in iconSymbols.enumerated() {
            let btn = IconButton(frame: NSRect(x: i * 31, y: 0, width: 28, height: 26))
            btn.symbol = sym
            btn.isBordered = false
            btn.target = self
            switch tag {
            case "size": btn.action = #selector(cycleSize); sizeBtn = btn
            case "edit": btn.action = #selector(editMessages); editBtn = btn
            case "pin":  btn.action = #selector(togglePin); pinBtn = btn; btn.active = true
            default: break
            }
            iconBar.addSubview(btn)
        }

        // Header
        let header = NSTextField(labelWithString: "Shuddup&Work")
        header.font = NSFont.systemFont(ofSize: 18, weight: .heavy)
        header.textColor = .white
        header.frame = NSRect(x: 18, y: fullSize.height - 34, width: 160, height: 26)
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
        for (label, _) in intervals { intervalPopup.addItem(withTitle: label) }
        intervalPopup.selectItem(at: 2)
        settingsCard.addSubview(intervalPopup)

        // -- Target card --
        targetCard = CardView(frame: NSRect(x: 14, y: fullSize.height - 160, width: fullSize.width - 28, height: 55))
        view.addSubview(targetCard)

        let winLabel = NSTextField(labelWithString: "TARGET WINDOW")
        winLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        winLabel.textColor = dimText
        winLabel.frame = NSRect(x: 12, y: 34, width: 140, height: 12)
        targetCard.addSubview(winLabel)

        windowPopup = NSPopUpButton(frame: NSRect(x: 8, y: 6, width: targetCard.frame.width - 70, height: 24))
        targetCard.addSubview(windowPopup)

        let refreshBtn = NSButton(frame: NSRect(x: targetCard.frame.width - 58, y: 6, width: 50, height: 24))
        refreshBtn.title = "Refresh"
        refreshBtn.bezelStyle = .rounded
        refreshBtn.font = NSFont.systemFont(ofSize: 9)
        refreshBtn.target = self
        refreshBtn.action = #selector(refreshWindows)
        targetCard.addSubview(refreshBtn)

        // -- Ring + Timer --
        let ringSize: CGFloat = 140
        let ringY: CGFloat = fullSize.height - 330
        ringView = RingView(frame: NSRect(x: (fullSize.width - ringSize) / 2, y: ringY, width: ringSize, height: ringSize))
        ringView.ringColor = accent
        view.addSubview(ringView)

        timerLabel = NSTextField(labelWithString: "--:--")
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 38, weight: .bold)
        timerLabel.textColor = accent
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

        // -- History card --
        historyCard = CardView(frame: NSRect(x: 14, y: 52, width: fullSize.width - 28, height: 90))
        view.addSubview(historyCard)

        let histLabel = NSTextField(labelWithString: "HISTORY")
        histLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        histLabel.textColor = dimText
        histLabel.frame = NSRect(x: 12, y: 72, width: 60, height: 12)
        historyCard.addSubview(histLabel)

        let histScroll = NSScrollView(frame: NSRect(x: 8, y: 4, width: historyCard.frame.width - 16, height: 64))
        histScroll.hasVerticalScroller = true
        histScroll.borderType = .noBorder
        histScroll.backgroundColor = .clear
        histScroll.drawsBackground = false

        historyText = NSTextView(frame: NSRect(x: 0, y: 0, width: histScroll.frame.width - 16, height: 64))
        historyText.isEditable = false
        historyText.isSelectable = false
        historyText.backgroundColor = .clear
        historyText.drawsBackground = false
        historyText.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        historyText.textColor = lightText
        historyText.string = "No nudges yet."
        histScroll.documentView = historyText
        historyCard.addSubview(histScroll)

        // -- Start button --
        startButton = PillButton(frame: NSRect(x: (fullSize.width - 160) / 2, y: 12, width: 160, height: 34))
        startButton.title = "Start"
        startButton.fillColor = accent
        startButton.isBordered = false
        startButton.target = self
        startButton.action = #selector(toggleRunning)
        view.addSubview(startButton)

        // -- Logo button (bottom left) --
        let logoPath = Bundle.main.resourcePath! + "/profuctions.png"
        if let logoImage = NSImage(contentsOfFile: logoPath) {
            let logoBtn = NSButton(frame: NSRect(x: 6, y: 6, width: 56, height: 56))
            logoBtn.image = logoImage
            logoBtn.imageScaling = .scaleProportionallyUpOrDown
            logoBtn.isBordered = false
            logoBtn.target = self
            logoBtn.action = #selector(showAbout)
            logoBtn.tag = 200
            view.addSubview(logoBtn)
        }

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
        aw.backgroundColor = NSColor(red: 0.04, green: 0.2, blue: 0.36, alpha: 1)

        let view = aw.contentView!

        // Logo (big, centered, clickable)
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

        // Version info
        let versionLabel = NSTextField(labelWithString: "Shuddup&Work 1.8")
        versionLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        versionLabel.textColor = .white
        versionLabel.frame = NSRect(x: 0, y: 130, width: 400, height: 22)
        versionLabel.alignment = .center
        view.addSubview(versionLabel)

        let rwrLabel = NSTextField(labelWithString: "RWR.2026")
        rwrLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        rwrLabel.textColor = NSColor(white: 0.55, alpha: 1)
        rwrLabel.frame = NSRect(x: 0, y: 105, width: 400, height: 18)
        rwrLabel.alignment = .center
        view.addSubview(rwrLabel)

        // Link text
        let linkLabel = NSTextField(labelWithString: "profuctions.com")
        linkLabel.font = NSFont.systemFont(ofSize: 12)
        linkLabel.textColor = accent
        linkLabel.frame = NSRect(x: 0, y: 70, width: 400, height: 16)
        linkLabel.alignment = .center
        view.addSubview(linkLabel)

        let linkBtn = NSButton(frame: NSRect(x: 100, y: 65, width: 200, height: 24))
        linkBtn.title = ""
        linkBtn.isTransparent = true
        linkBtn.target = self
        linkBtn.action = #selector(openProfuctions)
        view.addSubview(linkBtn)

        // Tagline
        let tagline = NSTextField(labelWithString: "digital creation, brought to light")
        tagline.font = NSFont.systemFont(ofSize: 11)
        tagline.textColor = NSColor(white: 0.4, alpha: 1)
        tagline.frame = NSRect(x: 0, y: 40, width: 400, height: 16)
        tagline.alignment = .center
        view.addSubview(tagline)

        aw.makeKeyAndOrderFront(nil)
        aboutWindow = aw
    }

    @objc func openProfuctions() {
        NSWorkspace.shared.open(URL(string: "https://profuctions.com")!)
    }

    // MARK: - Icon actions

    @objc func togglePin() {
        pinned = !pinned
        window.level = pinned ? .floating : .normal
        pinBtn.active = pinned
        pinBtn.needsDisplay = true
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
        let newSize: NSSize
        switch mode {
        case .full: newSize = fullSize
        case .compact: newSize = compactSize
        case .mini: newSize = miniSize
        }

        settingsCard.isHidden = mode != .full
        targetCard.isHidden = mode != .full
        historyCard.isHidden = mode != .full
        iconBar.isHidden = false

        if let header = window.contentView?.viewWithTag(100) {
            header.isHidden = mode == .mini
        }

        // In mini mode, show a smaller icon bar with just the size button
        if mode == .mini {
            iconBar.frame = NSRect(x: 4, y: CGFloat(miniSize.height) - 28, width: 122, height: 26)
        }

        let frame = window.frame
        let newFrame = NSRect(
            x: frame.origin.x + (frame.width - CGFloat(newSize.width)) / 2,
            y: frame.origin.y + frame.height - CGFloat(newSize.height),
            width: CGFloat(newSize.width), height: CGFloat(newSize.height)
        )

        window.setFrame(newFrame, display: true, animate: true)
        layoutForCurrentSize()
    }

    func layoutForCurrentSize() {
        let vw = window.contentView!.frame.width
        let vh = window.contentView!.frame.height

        iconBar.frame = NSRect(x: vw - 130, y: vh - 34, width: 122, height: 26)

        // Logo stays 56x56 and centers horizontally
        if let logoBtn = window.contentView?.viewWithTag(200) {
            logoBtn.frame = NSRect(x: (vw - 56) / 2, y: 6, width: 56, height: 56)
        }

        switch currentMode {
        case .full:
            settingsCard.frame = NSRect(x: 14, y: vh - 95, width: vw - 28, height: 55)
            targetCard.frame = NSRect(x: 14, y: vh - 160, width: vw - 28, height: 55)
            historyCard.frame = NSRect(x: 14, y: 68, width: vw - 28, height: 90)
            let ringSize: CGFloat = 140
            let ringY = vh - 330
            ringView.frame = NSRect(x: (vw - ringSize) / 2, y: ringY, width: ringSize, height: ringSize)
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 38, weight: .bold)
            timerLabel.frame = NSRect(x: 0, y: ringY + 46, width: vw, height: 46)
            statusLabel.frame = NSRect(x: 0, y: ringY - 18, width: vw, height: 14)
            statusLabel.isHidden = false
            startButton.frame = NSRect(x: (vw - 160) / 2, y: 14, width: 160, height: 34)
            if let logoBtn = window.contentView?.viewWithTag(200) {
                logoBtn.frame = NSRect(x: (vw - 56) / 2, y: 6, width: 56, height: 56)
                logoBtn.isHidden = false
            }
        case .compact:
            let ringSize: CGFloat = 90
            let ringY = vh - 165
            ringView.frame = NSRect(x: (vw - ringSize) / 2, y: ringY, width: ringSize, height: ringSize)
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .bold)
            timerLabel.frame = NSRect(x: 0, y: ringY + 28, width: vw, height: 36)
            statusLabel.frame = NSRect(x: 0, y: ringY - 14, width: vw, height: 14)
            statusLabel.isHidden = false
            startButton.frame = NSRect(x: (vw - 140) / 2, y: 10, width: 140, height: 30)
            if let logoBtn = window.contentView?.viewWithTag(200) {
                logoBtn.isHidden = true
            }
        case .mini:
            iconBar.frame = NSRect(x: (vw - 122) / 2, y: vh - 28, width: 122, height: 26)
            let ringSize: CGFloat = 70
            ringView.frame = NSRect(x: (vw - ringSize) / 2, y: (vh - ringSize) / 2 - 5, width: ringSize, height: ringSize)
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .bold)
            timerLabel.frame = NSRect(x: 0, y: (vh - 24) / 2 - 5, width: vw, height: 24)
            statusLabel.isHidden = true
            startButton.frame = NSRect(x: (vw - 100) / 2, y: 4, width: 100, height: 22)
            startButton.isHidden = running
            if let logoBtn = window.contentView?.viewWithTag(200) {
                logoBtn.isHidden = true
            }
        }

        ringView.needsDisplay = true
        startButton.needsDisplay = true
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
        let idx = windowPopup.indexOfSelectedItem
        guard idx >= 0, idx < terminalWindows.count else {
            statusLabel.stringValue = "Pick a target window"
            return
        }
        running = true
        sendCount = 0
        startButton.title = "Stop"
        startButton.fillColor = stopColor
        startButton.needsDisplay = true
        intervalPopup.isEnabled = false
        windowPopup.isEnabled = false

        totalInterval = intervals[intervalPopup.indexOfSelectedItem].1
        targetWindowId = terminalWindows[idx].id
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
                self.timerLabel.animator().textColor = bright ? self.accent : self.accent.withAlphaComponent(0.5)
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let ok = typeIntoWindow(windowId: self.targetWindowId, message: msg)
            DispatchQueue.main.async {
                if ok {
                    let ts = self.currentTime()
                    let entry = "\(ts)  \(msg)"
                    self.historyText.string = (self.historyText.string == "No nudges yet." ? "" : self.historyText.string)
                    self.historyText.string = self.historyText.string.isEmpty ? entry : entry + "\n" + self.historyText.string
                    self.statusLabel.stringValue = "Sent \(count) nudge\(count == 1 ? "" : "s")"
                } else {
                    self.statusLabel.stringValue = "Target window lost"
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
        startButton.title = "Start"
        startButton.fillColor = accent
        startButton.isHidden = false
        startButton.needsDisplay = true
        intervalPopup.isEnabled = true
        windowPopup.isEnabled = true
        statusLabel.stringValue = "Stopped"
        timerLabel.stringValue = "--:--"
        timerLabel.textColor = accent
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func windowDidResize(_ notification: Notification) {
        let vh = window.contentView!.frame.height
        let vw = window.contentView!.frame.width
        iconBar.frame = NSRect(x: vw - 130, y: vh - 34, width: 122, height: 26)
        if let header = window.contentView?.viewWithTag(100) {
            header.frame = NSRect(x: 18, y: vh - 34, width: 160, height: 26)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
