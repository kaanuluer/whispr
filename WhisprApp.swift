import SwiftUI
import AppKit
import ServiceManagement

@main
struct WhisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Window("Settings", id: "settings_window") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start model loading
        LLMService.shared.loadModel()
        
        // Handle Start at Login
        let startAtLogin = UserDefaults.standard.object(forKey: "startAtLogin") as? Bool ?? true
        if startAtLogin {
            if SMAppService.mainApp.status != .enabled {
                try? SMAppService.mainApp.register()
            }
        }
        
        // Create the popover
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuView())
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Using a simple SF Symbol for the menu bar icon
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: "Whispr")
            button.action = #selector(togglePopover(_:))
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
