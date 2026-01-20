import Foundation
import Cocoa
import Carbon
import Combine

class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    @Published var shortcutText: String = "⌥ Space"
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private let keyPath = "globalShortcutKeyCode"
    private let modifiersPath = "globalShortcutModifiers"
    
    init() {
        loadAndRegister()
    }
    
    func loadAndRegister() {
        if UserDefaults.standard.object(forKey: keyPath) == nil {
            // Default: Option (2048) + Space (49)
            register(keyCode: 49, modifiers: UInt32(optionKey))
        } else {
            let keyCode = UserDefaults.standard.integer(forKey: keyPath)
            let modifiers = UserDefaults.standard.integer(forKey: modifiersPath)
            register(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
        }
    }
    
    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        
        UserDefaults.standard.set(Int(keyCode), forKey: keyPath)
        UserDefaults.standard.set(Int(modifiers), forKey: modifiersPath)
        
        updateShortcutText(keyCode: keyCode, modifiers: modifiers)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x57485350) // 'WHSP'
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return
        }
        
        if eventHandler == nil {
            var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            
            InstallApplicationEventHandler({ (nextHandler, event, userData) -> OSStatus in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .toggleWhisprPopover, object: nil)
                }
                return noErr
            }, 1, &eventSpec, nil, &eventHandler)
        }
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private func updateShortcutText(keyCode: UInt32, modifiers: UInt32) {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃ " }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥ " }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧ " }
        if modifiers & UInt32(commandKey) != 0 { text += "⌘ " }
        
        text += keyName(for: keyCode)
        self.shortcutText = text
    }
    
    private func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let key = keyMap[Int(keyCode)] {
                return key
            }
            return "Key \(keyCode)"
        }
    }
    
    private let keyMap: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: "."
    ]
}

extension Notification.Name {
    static let toggleWhisprPopover = Notification.Name("toggleWhisprPopover")
}
