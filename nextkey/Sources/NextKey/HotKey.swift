import Carbon.HIToolbox
import Foundation

/// System-wide hotkey via Carbon RegisterEventHotKey. Needs no Accessibility permission.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var installed = false
    private static var nextID: UInt32 = 1

    private var ref: EventHotKeyRef?
    private let id: UInt32

    init?(spec: String, handler: @escaping () -> Void) {
        guard let (keyCode, mods) = HotKey.parse(spec) else { return nil }
        HotKey.installHandler()
        id = HotKey.nextID
        HotKey.nextID += 1
        let hkID = EventHotKeyID(signature: OSType(0x4E58_4B59), id: id)  // 'NXKY'
        let status = RegisterEventHotKey(keyCode, mods, hkID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else { return nil }
        HotKey.handlers[id] = handler
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.handlers[id] = nil
    }

    private static func installHandler() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async { HotKey.handlers[hkID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    // MARK: - Spec parsing ("cmd+opt+/")

    static func parse(_ spec: String) -> (UInt32, UInt32)? {
        var mods: UInt32 = 0
        var key: UInt32?
        for part in spec.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch part {
            case "cmd", "command", "⌘": mods |= UInt32(cmdKey)
            case "opt", "option", "alt", "⌥": mods |= UInt32(optionKey)
            case "ctrl", "control", "⌃": mods |= UInt32(controlKey)
            case "shift", "⇧": mods |= UInt32(shiftKey)
            default: key = keyCodes[part]
            }
        }
        guard let key, mods != 0 else { return nil }
        return (key, mods)
    }

    /// "cmd+opt+/" → "⌥⌘/" in Apple's modifier order.
    static func display(_ spec: String) -> String {
        let parts = spec.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        var out = ""
        if parts.contains(where: { ["ctrl", "control", "⌃"].contains($0) }) { out += "⌃" }
        if parts.contains(where: { ["opt", "option", "alt", "⌥"].contains($0) }) { out += "⌥" }
        if parts.contains(where: { ["shift", "⇧"].contains($0) }) { out += "⇧" }
        if parts.contains(where: { ["cmd", "command", "⌘"].contains($0) }) { out += "⌘" }
        if let last = parts.last, keyCodes[last] != nil { out += last == "space" ? "Space" : last.uppercased() }
        return out
    }

    private static let keyCodes: [String: UInt32] = {
        let pairs: [(String, Int)] = [
            ("a", kVK_ANSI_A), ("b", kVK_ANSI_B), ("c", kVK_ANSI_C), ("d", kVK_ANSI_D),
            ("e", kVK_ANSI_E), ("f", kVK_ANSI_F), ("g", kVK_ANSI_G), ("h", kVK_ANSI_H),
            ("i", kVK_ANSI_I), ("j", kVK_ANSI_J), ("k", kVK_ANSI_K), ("l", kVK_ANSI_L),
            ("m", kVK_ANSI_M), ("n", kVK_ANSI_N), ("o", kVK_ANSI_O), ("p", kVK_ANSI_P),
            ("q", kVK_ANSI_Q), ("r", kVK_ANSI_R), ("s", kVK_ANSI_S), ("t", kVK_ANSI_T),
            ("u", kVK_ANSI_U), ("v", kVK_ANSI_V), ("w", kVK_ANSI_W), ("x", kVK_ANSI_X),
            ("y", kVK_ANSI_Y), ("z", kVK_ANSI_Z),
            ("0", kVK_ANSI_0), ("1", kVK_ANSI_1), ("2", kVK_ANSI_2), ("3", kVK_ANSI_3),
            ("4", kVK_ANSI_4), ("5", kVK_ANSI_5), ("6", kVK_ANSI_6), ("7", kVK_ANSI_7),
            ("8", kVK_ANSI_8), ("9", kVK_ANSI_9),
            ("/", kVK_ANSI_Slash), (".", kVK_ANSI_Period), (",", kVK_ANSI_Comma),
            (";", kVK_ANSI_Semicolon), ("'", kVK_ANSI_Quote), ("`", kVK_ANSI_Grave),
            ("-", kVK_ANSI_Minus), ("=", kVK_ANSI_Equal), ("[", kVK_ANSI_LeftBracket),
            ("]", kVK_ANSI_RightBracket), ("\\", kVK_ANSI_Backslash),
            ("space", kVK_Space), ("return", kVK_Return), ("tab", kVK_Tab),
        ]
        return Dictionary(uniqueKeysWithValues: pairs.map { ($0.0, UInt32($0.1)) })
    }()
}
