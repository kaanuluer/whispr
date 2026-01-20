import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @StateObject private var manager = ShortcutManager.shared
    @State private var isRecording = false
    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32?
    
    var body: some View {
        Button(action: {
            isRecording.toggle()
        }) {
            HStack {
                Text(isRecording ? "Press keys..." : manager.shortcutText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(minWidth: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .background(ShortcutRecorderHandler(isRecording: $isRecording) { keyCode, modifiers in
            manager.register(keyCode: keyCode, modifiers: modifiers)
            isRecording = false
        })
    }
}

struct ShortcutRecorderHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onRecord: (UInt32, UInt32) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ShortcutNSView()
        view.onRecord = onRecord
        view.isRecording = isRecording
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ShortcutNSView {
            view.isRecording = isRecording
        }
    }
    
    class ShortcutNSView: NSView {
        var onRecord: ((UInt32, UInt32) -> Void)?
        var isRecording = false {
            didSet {
                if isRecording {
                    window?.makeFirstResponder(self)
                }
            }
        }
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if isRecording && event.keyCode == 53 { // Escape
                isRecording = false
                return
            }
            
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            
            let modifiers = event.modifierFlags
            let carbonModifiers = mapToCarbonModifiers(modifiers)
            
            // Ignore if only modifier is pressed
            if isOnlyModifier(event.keyCode) {
                return
            }
            
            onRecord?(UInt32(event.keyCode), carbonModifiers)
        }
        
        private func isOnlyModifier(_ keyCode: UInt16) -> Bool {
            // Command, Option, Control, Shift key codes
            return [54, 55, 56, 57, 58, 59, 60, 61, 62].contains(keyCode)
        }
        
        private func mapToCarbonModifiers(_ modifiers: NSEvent.ModifierFlags) -> UInt32 {
            var carbonModifiers: UInt32 = 0
            if modifiers.contains(.command) { carbonModifiers |= UInt32(commandKey) }
            if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            return carbonModifiers
        }
    }
}
