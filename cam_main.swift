import AppKit
import ScreenSaver

// Matrix Rain Cam — kamera jako obraz złożony z kodu Matrixa.

final class KeyWindow: NSWindow {
    var onKey: ((NSEvent) -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) { onKey?(event) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var win: KeyWindow!
    var view: MatrixRainView!
    var hint: NSTextField!
    var status: NSTextField!
    var timer: Timer?
    var hintShown = Date()
    var theme = 0, color = 0, mirror = 1, glitchIdx = 1, crtIdx = 1, zoomIdx = 0, fxIdx = 0, vigIdx = 1, size = 14.0, mix = 1.0, mode = 4
    var en = !(Locale.preferredLanguages.first?.hasPrefix("pl") ?? false)
    var helpText: String {
        en ? """
        1 camera   2 rain   3 clock     T theme   C photo colors   M mirror
        + / −  glyph size   [ / ]  image strength   G glitch   K CRT   V vignette   Z auto-zoom   P effects
        F / Enter  fullscreen   H  hide/show help   L  language   Esc / Q  quit
        """ : """
        1 kamera   2 deszcz   3 zegar     T motyw   C kolory obrazu   M lustro
        + / −  rozmiar znaków   [ / ]  widoczność obrazu   G glitch   K CRT   V winieta   Z auto-zoom   P efekty
        F / Enter  pełny ekran   H  ukryj/pokaż pomoc   L  język   Esc / Q  wyjście
        """
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular)
        let frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        win = KeyWindow(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                        backing: .buffered, defer: false)
        win.title = "Matrix Rain Cam"
        win.backgroundColor = .black
        win.collectionBehavior = [.fullScreenPrimary]
        let container = NSView(frame: frame)
        container.autoresizingMask = [.width, .height]
        view = MatrixRainView(frame: frame, isPreview: false)!
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)

        hint = NSTextField(labelWithString: helpText)
        hint.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        hint.textColor = NSColor(red: 0.3, green: 1, blue: 0.5, alpha: 0.9)
        hint.backgroundColor = NSColor.black.withAlphaComponent(0.55)
        hint.drawsBackground = true
        hint.frame = NSRect(x: 16, y: 16, width: 640, height: 54)
        hint.autoresizingMask = [.maxXMargin, .maxYMargin]
        container.addSubview(hint)

        status = NSTextField(wrappingLabelWithString: "")
        status.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        status.textColor = NSColor(red: 1, green: 0.45, blue: 0.4, alpha: 1)
        status.alignment = .center
        status.frame = NSRect(x: 100, y: 380, width: 1080, height: 60)
        status.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        container.addSubview(status)

        win.contentView = container
        win.onKey = { [weak self] e in self?.key(e) }
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        apply()
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.frame() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func apply() {
        view.setOption("lang", NSNumber(value: en ? 1 : 0))
        view.setOption("mode", NSNumber(value: mode))
        view.setOption("theme", NSNumber(value: theme))
        view.setOption("photoColor", NSNumber(value: color))
        view.setOption("mirror", NSNumber(value: mirror))
        view.setOption("size", NSNumber(value: size))
        view.setOption("imgMix", NSNumber(value: mix))
        let lv = NSNumber(value: [0.0, 0.35, 0.8][crtIdx])
        for k in ["curve", "scan", "mask", "roll"] { view.setOption(k as NSString, lv) }
        view.setOption("vignette", NSNumber(value: [0.0, 0.5, 1.0][vigIdx]))
        let fx: [[Double]] = [[0, 0, 0, 0, 0], [0.7, 0.6, 0, 0, 0], [0, 0.5, 0.7, 0.8, 0], [0.6, 0.6, 0.7, 0.8, 0.6]]
        for (i, k) in ["wet", "ghost", "wave", "depth", "noise"].enumerated() { view.setOption(k as NSString, NSNumber(value: fx[fxIdx][i])) }
        view.setOption("zoom", NSNumber(value: [0.0, 0.5, 1.0][zoomIdx]))
        view.setOption("glitch", NSNumber(value: [0.0, 0.2, 0.6][glitchIdx]))
    }

    func frame() {
        view.animateOneFrame()
        status.stringValue = mode == 4 ? view.cameraStatus : ""
        hint.alphaValue = hintShown.timeIntervalSinceNow > -10 ? 1 : max(0, 1 + (hintShown.timeIntervalSinceNow + 10) / 2)
    }

    func key(_ e: NSEvent) {
        let k = e.charactersIgnoringModifiers?.lowercased() ?? ""
        switch k {
        case "1": mode = 4
        case "2": mode = 0
        case "3": mode = 2
        case "t": theme = (theme + 1) % 6
        case "c": color = 1 - color
        case "m": mirror = 1 - mirror
        case "+", "=": size = min(40, size + 2)
        case "-": size = max(8, size - 2)
        case "]": mix = min(1, mix + 0.1)
        case "[": mix = max(0.2, mix - 0.1)
        case "l": en.toggle(); hint.stringValue = helpText; hintShown = Date()
        case "g": glitchIdx = (glitchIdx + 1) % 3
        case "p": fxIdx = (fxIdx + 1) % 4
        case "z": zoomIdx = (zoomIdx + 1) % 3
        case "k": crtIdx = (crtIdx + 1) % 3
        case "v": vigIdx = (vigIdx + 1) % 3
        case "h": hintShown = hint.alphaValue < 0.5 ? Date() : Date.distantPast
        case "f", "\r": win.toggleFullScreen(nil)
        case "q": NSApp.terminate(nil)
        case "\u{1b}":
            if win.styleMask.contains(.fullScreen) { win.toggleFullScreen(nil) } else { NSApp.terminate(nil) }
        default: break
        }
        apply()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
