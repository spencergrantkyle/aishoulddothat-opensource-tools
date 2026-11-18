import AppKit
import SwiftUI

/// Borderless panel. NextKey activates while it is open: dictation tools such as Wispr Flow
/// insert into the active app's focused text field, so the panel's app has to be active.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let session = Session()
    var lastExternalApp: NSRunningApplication?

    /// The app the user was in when the hotkey fired; focus goes back to it on Esc.
    private var returnApp: NSRunningApplication?
    private let panel: KeyPanel
    private let width: CGFloat = 680
    private let cornerRadius: CGFloat = 16

    override init() {
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 76),
                         styleMask: [.borderless],
                         backing: .buffered, defer: false)
        super.init()

        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: cornerRadius)

        let hosting = NSHostingView(rootView: PanelView(
            session: session,
            cornerRadius: cornerRadius,
            onHeight: { [weak self] in self?.setHeight($0) }
        ))
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.contentView = effect

        // Esc closes. A local monitor beats the text field's own Esc handling.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow, event.keyCode == 53 else { return event }
            self.hide()
            return nil
        }

        // Clicking into another app closes the panel (without stealing focus back).
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide(restoreFocus: false) }
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        // Read the user's app and window before NextKey activates and becomes frontmost.
        var app = NSWorkspace.shared.frontmostApplication
        if app?.processIdentifier == getpid() { app = lastExternalApp }
        returnApp = app
        let window = Capture.frontWindow(pid: app?.processIdentifier)
        session.begin(app: app, windowTitle: window.title, windowBounds: window.bounds)

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let top = visible.maxY - visible.height * 0.18
            let height = panel.frame.height
            panel.setFrame(NSRect(x: visible.midX - width / 2, y: top - height, width: width, height: height),
                           display: false)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        session.focusTick += 1
    }

    func hide(restoreFocus: Bool = true) {
        guard panel.isVisible else { return }
        session.cancel()
        panel.orderOut(nil)
        if restoreFocus, NSApp.isActive { returnApp?.activate() }
    }

    /// Grow or shrink downward, keeping the top edge where it is.
    private func setHeight(_ height: CGFloat) {
        let h = ceil(height)
        var frame = panel.frame
        guard abs(frame.height - h) > 0.5 else { return }
        let top = frame.maxY
        frame.size.height = h
        frame.origin.y = top - h
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
