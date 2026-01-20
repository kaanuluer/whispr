import SwiftUI
import AppKit

struct MenuView: View {
    @State private var searchText = ""
    @ObservedObject var clipboard = ClipboardManager.shared
    @ObservedObject var llm = LLMService.shared
    @Environment(\.openWindow) private var openWindow
    
    enum WhisprStatus: String {
        case running = "Running"
        case paused = "Paused"
        
        var color: Color {
            switch self {
            case .running: return .green
            case .paused: return .orange
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Header
            VStack(spacing: 0) {
                HStack {
                    Text("Whispr")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // LLM Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(llm.state == .ready ? WhisprStyle.accentColor : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(llm.state.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 10)
                        
                        // App Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green) // Mock running
                                .frame(width: 6, height: 6)
                            Text("Running")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        openWindow(id: "settings_window")
                        NSApp.activate(ignoringOtherApps: true)
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .help("Settings")

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .help("Quit Whispr")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if llm.state == .loading {
                    ProgressView(value: llm.progress)
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
            }
            
            // 2. Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                TextField("Search clipboard", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
                .opacity(0.5)
            
            // 3. Clipboard List
            ScrollView {
                VStack(spacing: 2) {
                    let filteredItems = clipboard.items.filter { 
                        if searchText.isEmpty { return true }
                        let contentMatch = $0.content.localizedCaseInsensitiveContains(searchText)
                        let appMatch = $0.sourceApp?.localizedCaseInsensitiveContains(searchText) ?? false
                        return contentMatch || appMatch
                    }
                    
                    if filteredItems.isEmpty {
                        Text(searchText.isEmpty ? "Clipboard is empty" : "No results found")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredItems) { item in
                            ClipboardRow(item: item)
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 400)
            
            Divider()
                .opacity(0.5)
            
            // Footer (Keyboard Hints)
            HStack {
                Text("⌘V to paste")
                Spacer()
                Text("↵ to copy")
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
    }
}

// macOS Background Blur Helper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material {
            nsView.material = material
        }
        if nsView.blendingMode != blendingMode {
            nsView.blendingMode = blendingMode
        }
    }
}
