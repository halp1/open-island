import AppKit
import Carbon.HIToolbox

/// A key plus modifiers, stored with Carbon key codes so it can be
/// registered as a system-wide hot key.
struct HotKeyShortcut: Equatable, Codable, Sendable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags.RawValue

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(Self.relevantModifiers)
    }

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    init(keyCode: UInt32, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifierFlags.intersection(Self.relevantModifiers).rawValue
    }

    /// Builds a shortcut from a key press, or nil when it lacks a
    /// non-Shift modifier (a bare key would swallow normal typing).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(Self.relevantModifiers)
        guard !flags.subtracting(.shift).isEmpty else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifierFlags: flags)
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        let flags = modifierFlags
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayString: String {
        let flags = modifierFlags
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: break
        }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "#\(keyCode)"
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return "#\(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

/// Registers one system-wide hot key through Carbon. Carbon hot keys need
/// no Accessibility grant and consume the key press so it does not leak
/// into the frontmost app.
@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private let identifier: UInt32
    private let action: @MainActor () -> Void

    private static var nextIdentifier: UInt32 = 1
    private static var actions: [UInt32: @MainActor () -> Void] = [:]
    private static var handlerRef: EventHandlerRef?

    init(action: @escaping @MainActor () -> Void) {
        identifier = Self.nextIdentifier
        Self.nextIdentifier += 1
        self.action = action
    }

    /// Returns false when the system refused the combination (for example
    /// because another app already owns it).
    @discardableResult
    func register(_ shortcut: HotKeyShortcut?) -> Bool {
        unregister()
        guard let shortcut else { return true }
        Self.installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F49_534C), id: identifier) // 'OISL'
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        Self.actions[identifier] = action
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        Self.actions.removeValue(forKey: identifier)
    }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return OSStatus(eventNotHandledErr) }
            let id = hotKeyID.id
            MainActor.assumeIsolated { GlobalHotKey.actions[id]?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}
