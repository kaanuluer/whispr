import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var llm = LLMService.shared
    @ObservedObject var tagManager = TagManager.shared
    @AppStorage("startAtLogin") private var startAtLogin = true
    @AppStorage("pauseWhispr") private var pauseWhispr = false
    @AppStorage("historySize") private var historySize = 50
    @AppStorage("enableAI") private var enableAI = true
    @AppStorage("maxOutputLength") private var maxOutputLength = 200
    @AppStorage("targetLanguage") private var targetLanguage = "English"
    @AppStorage("screenshotFolderPath") private var screenshotFolderPath = ""
    @State private var newTagName = ""
    
    // Individual AI Action States
    @AppStorage("showCleanAction") private var showCleanAction = true
    @AppStorage("showSummarizeAction") private var showSummarizeAction = true
    @AppStorage("showRewriteAction") private var showRewriteAction = true
    @AppStorage("showTranslateAction") private var showTranslateAction = true
    
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case privacy = "Privacy"
        case tags = "Tags"
        case aiActions = "AI Actions"
        case support = "Support"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .privacy: return "hand.raised.fill"
            case .tags: return "tag.fill"
            case .aiActions: return "wand.and.stars.inverse"
            case .support: return "questionmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Menu Bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedTab == tab ? WhisprStyle.accentColor : .secondary)
                        .background(selectedTab == tab ? WhisprStyle.accentColor.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.primary.opacity(0.05))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.primary.opacity(0.1)),
                alignment: .bottom
            )
            
            // Content Area
            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView(
                            startAtLogin: $startAtLogin,
                            pauseWhispr: $pauseWhispr,
                            historySize: $historySize,
                            screenshotFolderPath: $screenshotFolderPath,
                            onUpdateLaunchAtLogin: updateLaunchAtLogin,
                            onSelectScreenshotFolder: selectScreenshotFolder
                        )
                    case .privacy:
                        PrivacySettingsView()
                    case .tags:
                        TagsSettingsView(tagManager: tagManager, newTagName: $newTagName)
                    case .aiActions:
                        AIActionsSettingsView(
                            llm: llm,
                            enableAI: $enableAI,
                            showCleanAction: $showCleanAction,
                            showSummarizeAction: $showSummarizeAction,
                            showRewriteAction: $showRewriteAction,
                            showTranslateAction: $showTranslateAction,
                            targetLanguage: $targetLanguage,
                            maxOutputLength: $maxOutputLength
                        )
                    case .support:
                        SupportSettingsView(llm: llm)
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 420)
        .onAppear {
            startAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update launch at login status: \(error)")
        }
    }
    
    private func selectScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the folder where your screenshots are saved."
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                screenshotFolderPath = url.path
                NotificationCenter.default.post(name: .screenshotFolderChanged, object: nil)
            }
        }
    }
}

// MARK: - Settings Views

struct GeneralSettingsView: View {
    @Binding var startAtLogin: Bool
    @Binding var pauseWhispr: Bool
    @Binding var historySize: Int
    @Binding var screenshotFolderPath: String
    let onUpdateLaunchAtLogin: (Bool) -> Void
    let onSelectScreenshotFolder: () -> Void
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $startAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start at login")
                        Text("Launch Whispr automatically when you start your Mac.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .onChange(of: startAtLogin) { newValue in
                    onUpdateLaunchAtLogin(newValue)
                }
                
                Toggle(isOn: $pauseWhispr) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause Whispr")
                        Text("Temporarily stop tracking clipboard changes.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Application")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("History size")
                        Spacer()
                        Text("\(historySize) items")
                            .foregroundColor(WhisprStyle.accentColor)
                            .fontWeight(.medium)
                    }
                    Slider(value: Binding(
                        get: { Double(historySize) },
                        set: { historySize = Int($0) }
                    ), in: 10...500, step: 10)
                    
                    Text("Older items will be removed automatically to save memory.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Storage")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screenshots Folder")
                        .font(.system(size: 13, weight: .medium))
                    
                    HStack {
                        Text(screenshotFolderPath.isEmpty ? "Default (Desktop & Downloads)" : screenshotFolderPath)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button("Select Folder") {
                            onSelectScreenshotFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        if !screenshotFolderPath.isEmpty {
                            Button(action: { screenshotFolderPath = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Whispr will monitor this folder for new screenshots and use it for image actions.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Screenshots & Images")
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                InfoRow(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "Local AI Processing",
                    description: "Your data stays on your Mac. No cloud, no tracking, no leaks."
                )
                
                InfoRow(
                    icon: "eye.slash.fill",
                    color: WhisprStyle.accentColor,
                    title: "Sensitive Fields",
                    description: "Passwords and secure text entries are ignored automatically."
                )
            } header: {
                Text("Security")
            }
            
            Section {
                Button(role: .destructive) {
                    ClipboardManager.shared.clearAllHistory()
                } label: {
                    HStack {
                        Spacer()
                        Text("Clear All History")
                        Spacer()
                    }
                }
                .controlSize(.large)
            }
        }
        .formStyle(.grouped)
    }
}

struct TagsSettingsView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var newTagName: String
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("New tag name", text: $newTagName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .onSubmit {
                                if !newTagName.isEmpty {
                                    tagManager.addTag(newTagName)
                                    newTagName = ""
                                }
                            }
                        
                        Button(action: {
                            if !newTagName.isEmpty {
                                tagManager.addTag(newTagName)
                                newTagName = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(WhisprStyle.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTagName.isEmpty)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                    
                    if tagManager.allTags.isEmpty {
                        Text("No tags yet. Create your first tag above.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                ForEach(tagManager.allTags, id: \.self) { tag in
                                    TagManagementBadge(tag: tag, onDelete: {
                                        tagManager.removeTag(tag)
                                    })
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    
                    Text("Tags help you organize and quickly find clipboard items. Use the search bar to filter by tag names.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Tags")
            } footer: {
                Text("Create tags to organize your clipboard history. Tags are searchable from the main menu.")
            }
        }
        .formStyle(.grouped)
    }
}

struct AIActionsSettingsView: View {
    @ObservedObject var llm: LLMService
    @Binding var enableAI: Bool
    @Binding var showCleanAction: Bool
    @Binding var showSummarizeAction: Bool
    @Binding var showRewriteAction: Bool
    @Binding var showTranslateAction: Bool
    @Binding var targetLanguage: String
    @Binding var maxOutputLength: Int
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enableAI) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable AI features")
                            .fontWeight(.medium)
                        Text("Unlock local intelligence for your clipboard.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            if enableAI {
                Section {
                    ForEach(AICapability.allCases, id: \.self) { capability in
                        Picker(capability.displayName, selection: Binding(
                            get: { llm.capabilityMapping[capability] ?? "None" },
                            set: { newValue in
                                llm.capabilityMapping[capability] = newValue
                                llm.saveCapabilityMapping()
                            }
                        )) {
                            Text("None").tag("None")
                            ForEach(llm.availableModels.filter { $0.capabilities.contains(capability) }) { model in
                                Text(model.name).tag(model.name)
                            }
                        }
                    }
                } header: {
                    Text("Capability Model Mapping")
                } footer: {
                    Text("Assign local models to specific AI tasks.")
                }
                
                Section {
                    Toggle(isOn: $showCleanAction) {
                        Label("Clean", systemImage: "wand.and.stars")
                    }
                    Toggle(isOn: $showSummarizeAction) {
                        Label("Summarize", systemImage: "text.alignleft")
                    }
                    Toggle(isOn: $showRewriteAction) {
                        Label("Rewrite", systemImage: "pencil")
                    }
                    Toggle(isOn: $showTranslateAction) {
                        Label("Translate", systemImage: "character.book.closed")
                    }
                } header: {
                    Text("Active Actions")
                }
                
                Section {
                    Picker("Target language", selection: $targetLanguage) {
                        Text("English").tag("English")
                        Text("Turkish").tag("Turkish")
                        Text("German").tag("German")
                        Text("French").tag("French")
                        Text("Spanish").tag("Spanish")
                    }
                    
                    Picker("Max output length", selection: $maxOutputLength) {
                        Text("Short (100)").tag(100)
                        Text("Medium (200)").tag(200)
                        Text("Long (500)").tag(500)
                    }
                } header: {
                    Text("Response Style")
                }
            }
        }
        .formStyle(.grouped)
    }
}

extension Notification.Name {
    static let screenshotFolderChanged = Notification.Name("screenshotFolderChanged")
}

struct TagManagementBadge: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 11, weight: .medium))
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(WhisprStyle.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WhisprStyle.accentColor.opacity(0.1))
        .cornerRadius(6)
    }
}

struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SupportSettingsView: View {
    @ObservedObject var llm: LLMService
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Open Whispr")
                    Spacer()
                    ShortcutRecorder()
                }
            } header: {
                Text("Global Shortcuts")
            }
            
            Section {
                if llm.isPolling {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching for Ollama...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if !llm.isOllamaConnected {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Ollama is not reachable.")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        
                        Button(action: {
                            llm.loadModel()
                            llm.startOllamaPolling()
                        }) {
                            Label("Retry Connection", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                
                if !llm.availableModels.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Detected Models")
                                .font(.headline)
                            Spacer()
                            Button(action: { llm.loadModel() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .help("Refresh models")
                        }
                        
                        ForEach(llm.availableModels) { model in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(model.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(model.type.capitalized)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(model.maxTokens) tokens")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                } else if !llm.isPolling {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No models detected.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            llm.loadModel()
                            llm.startOllamaPolling()
                        }) {
                            Label("Scan for Ollama", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Local AI Infrastructure")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Need help or have feedback?")
                        .font(.system(size: 12))
                    
                    Link(destination: URL(string: "mailto:support@kaanuluer.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("support@kaanuluer.com")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .padding(10)
                        .background(WhisprStyle.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(WhisprStyle.accentColor)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Support")
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text("Whispr v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6")")
                    .font(.system(size: 10, weight: .semibold))
                Text("Made with quiet care.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRow: View {
    let label: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(4)
        }
    }
}
