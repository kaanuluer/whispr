import SwiftUI
import AppKit

struct MenuView: View {
    @State private var searchText = ""
    @State private var selectedView: ViewMode = .clipboard
    @ObservedObject var clipboard = ClipboardManager.shared
    @ObservedObject var llm = LLMService.shared
    @ObservedObject var folderManager = FolderManager.shared
    @Environment(\.openWindow) private var openWindow
    
    enum ViewMode: Equatable {
        case clipboard
        case folder(UUID)
        
        static func == (lhs: ViewMode, rhs: ViewMode) -> Bool {
            switch (lhs, rhs) {
            case (.clipboard, .clipboard):
                return true
            case (.folder(let lhsId), .folder(let rhsId)):
                return lhsId == rhsId
            default:
                return false
            }
        }
    }
    
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
            
            // 2. View Mode Selector
            HStack(spacing: 0) {
                Button(action: {
                    selectedView = .clipboard
                    searchText = ""
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                        Text("Clipboard")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundColor(selectedView == .clipboard ? WhisprStyle.accentColor : .secondary)
                    .background(selectedView == .clipboard ? WhisprStyle.accentColor.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
                
                if !folderManager.folders.isEmpty {
                    Menu {
                        ForEach(folderManager.folders) { folder in
                            Button(action: {
                                selectedView = .folder(folder.id)
                                searchText = ""
                            }) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                    Text(folder.name)
                                    Spacer()
                                    Text("\(folder.itemIds.count)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            openWindow(id: "settings_window")
                            NSApp.activate(ignoringOtherApps: true)
                        }) {
                            Label("Manage Folders", systemImage: "gearshape")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedView.isFolder ? "folder.fill" : "folder")
                                .font(.system(size: 11))
                            Text(selectedView.folderName(folderManager: folderManager) ?? "Folders")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundColor(selectedView.isFolder ? WhisprStyle.accentColor : .secondary)
                        .background(selectedView.isFolder ? WhisprStyle.accentColor.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.primary.opacity(0.03))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            // 3. Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                TextField(selectedView.isFolder ? "Search in folder" : "Search clipboard", text: $searchText)
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
            
            // 4. Content List (Clipboard or Folder)
            ScrollView {
                VStack(spacing: 12) {
                    let filteredItems: [ClipboardItem] = {
                        switch selectedView {
                        case .clipboard:
                            let items = clipboard.items
                            return items.filter {
                                if searchText.isEmpty { return true }
                                let searchLower = searchText.lowercased()
                                let contentMatch = $0.content.localizedCaseInsensitiveContains(searchText)
                                let appMatch = $0.sourceApp?.localizedCaseInsensitiveContains(searchText) ?? false
                                let tagMatch = $0.tags.contains { $0.localizedCaseInsensitiveContains(searchLower) }
                                return contentMatch || appMatch || tagMatch
                            }
                        case .folder(let folderId):
                            return searchText.isEmpty ? folderManager.getItemsFromFolder(folderId: folderId) : folderManager.searchInFolder(folderId, query: searchText)
                        }
                    }()
                    
                    if filteredItems.isEmpty {
                        Text(emptyMessage(for: selectedView, hasSearch: !searchText.isEmpty))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        // For folders, show items directly (sorted by timestamp)
                        if case .folder(let folderId) = selectedView {
                            ForEach(filteredItems.sorted(by: { $0.timestamp > $1.timestamp })) { item in
                                FolderItemRow(item: item, folderId: folderId)
                            }
                        } else {
                            // For clipboard, show pinned/recent separation
                            let pinnedItems = filteredItems.filter { $0.isPinned }
                            let unpinnedItems = filteredItems.filter { !$0.isPinned }
                            
                            if !pinnedItems.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 10))
                                        Text("Pinned")
                                            .font(.system(size: 10, weight: .bold))
                                        Rectangle()
                                            .fill(WhisprStyle.accentColor.opacity(0.2))
                                            .frame(height: 1)
                                    }
                                    .foregroundColor(WhisprStyle.accentColor)
                                    .padding(.horizontal, 4)
                                    
                                    ForEach(pinnedItems) { item in
                                        ClipboardRow(item: item)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                            
                            if !unpinnedItems.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Recent")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Rectangle()
                                            .fill(Color.primary.opacity(0.1))
                                            .frame(height: 1)
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    ForEach(unpinnedItems) { item in
                                        ClipboardRow(item: item)
                                    }
                                }
                            }
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
    
    private func emptyMessage(for viewMode: ViewMode, hasSearch: Bool) -> String {
        if hasSearch {
            return "No results found"
        }
        
        switch viewMode {
        case .clipboard:
            return "Clipboard is empty"
        case .folder:
            return "Folder is empty"
        }
    }
}

extension MenuView.ViewMode {
    var isFolder: Bool {
        if case .folder = self {
            return true
        }
        return false
    }
    
    func folderName(folderManager: FolderManager) -> String? {
        if case .folder(let id) = self {
            return folderManager.folders.first(where: { $0.id == id })?.name
        }
        return nil
    }
}

struct FolderItemRow: View {
    let item: ClipboardItem
    let folderId: UUID
    @ObservedObject var folderManager = FolderManager.shared
    
    var body: some View {
        ClipboardRow(item: item)
            .contextMenu {
                Button(action: {
                    ClipboardManager.shared.copyToClipboard(item)
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    withAnimation(.spring()) {
                        folderManager.removeItemFromFolder(item.id, folderId: folderId)
                    }
                }) {
                    Label("Remove from Folder", systemImage: "trash")
                }
            }
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
