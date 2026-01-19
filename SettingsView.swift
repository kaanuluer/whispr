import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var llm = LLMService.shared
    @AppStorage("startAtLogin") private var startAtLogin = true
    @AppStorage("pauseWhispr") private var pauseWhispr = false
    @AppStorage("historySize") private var historySize = 50
    @AppStorage("enableAI") private var enableAI = true
    @AppStorage("maxOutputLength") private var maxOutputLength = 200
    @AppStorage("targetLanguage") private var targetLanguage = "English"
    
    // Individual AI Action States
    @AppStorage("showCleanAction") private var showCleanAction = true
    @AppStorage("showSummarizeAction") private var showSummarizeAction = true
    @AppStorage("showRewriteAction") private var showRewriteAction = true
    @AppStorage("showTranslateAction") private var showTranslateAction = true
    
    var body: some View {
        TabView {
            // General
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
                        updateLaunchAtLogin(newValue)
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
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            // Privacy
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
            .tabItem {
                Label("Privacy", systemImage: "hand.raised.fill")
            }
            
            // AI Actions
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
            .tabItem {
                Label("AI Actions", systemImage: "wand.and.stars.inverse")
            }
            
            // Shortcuts & Support
            Form {
                Section {
                    ShortcutRow(label: "Open Whispr", shortcut: "⌥ ␣")
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
                    Text("Whispr v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.1")")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Made with quiet care.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            }
            .tabItem {
                Label("Support", systemImage: "questionmark.circle.fill")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
        .onAppear {
            // Synchronize with actual system status
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
