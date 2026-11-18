import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var panel: PanelController!
    private var hotkeySpec = ConfigStore.defaultHotkey

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != getpid() else { return }
            MainActor.assumeIsolated { self?.panel.lastExternalApp = app }
        }

        registerHotKey()
        buildStatusItem()
        buildMainMenu()

        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
    }

    private func registerHotKey() {
        hotkeySpec = ConfigStore.load().hotkey ?? ConfigStore.defaultHotkey
        hotKey = HotKey(spec: hotkeySpec) { [weak self] in
            MainActor.assumeIsolated { self?.panel.toggle() }
        }
        if hotKey == nil {
            NSLog("NextKey: could not register hotkey \(hotkeySpec)")
        }
    }

    /// Never shown (menu-bar-only app), but AppKit routes ⌘V/⌘C/⌘X/⌘A/⌘Z to text fields
    /// through the main menu's key equivalents. Without it, paste and Wispr Flow fail.
    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.addItem(NSMenuItem(title: "Quit NextKey",
                                            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(appItem)

        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editItem = NSMenuItem()
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "NextKey")
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let ask = NSMenuItem(title: "Ask NextKey", action: #selector(askFromMenu), keyEquivalent: "")
        ask.target = self
        menu.addItem(ask)
        let hint = NSMenuItem(title: hotKey == nil ? "Hotkey \(HotKey.display(hotkeySpec)) unavailable"
                                                   : "Hotkey: \(HotKey.display(hotkeySpec))",
                              action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let current = ConfigStore.load().model ?? ConfigStore.defaultModel
        let modelMenu = NSMenu()
        for (name, id) in ConfigStore.models {
            let item = NSMenuItem(title: name, action: #selector(pickModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = id == current ? .on : .off
            modelMenu.addItem(item)
        }
        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.submenu = modelMenu
        menu.addItem(modelItem)

        let key = NSMenuItem(title: ConfigStore.apiKey == nil ? "Set OpenRouter API Key…" : "Change OpenRouter API Key…",
                             action: #selector(setAPIKey), keyEquivalent: "")
        key.target = self
        menu.addItem(key)

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NextKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func askFromMenu() {
        // Let the menu close first so the panel can take key focus.
        DispatchQueue.main.async { self.panel.show() }
    }

    @objc private func pickModel(_ sender: NSMenuItem) {
        var config = ConfigStore.load()
        config.model = sender.representedObject as? String
        ConfigStore.save(config)
        rebuildMenu()
    }

    @objc private func setAPIKey() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "OpenRouter API key"
        alert.informativeText = "Saved to ~/.config/nextkey/.env."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "sk-or-…"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { ConfigStore.saveAPIKey(value) }
        }
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
        rebuildMenu()
    }
}
