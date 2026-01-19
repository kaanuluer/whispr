import Foundation
import Combine

enum LLMModelState: String {
    case notLoaded = "Not Loaded"
    case loading = "Loading Models..."
    case ready = "Ready"
    case error = "Model Error"
}

enum LLMAction: String {
    case clean = "Clean"
    case summarize = "Summarize"
    case rewrite = "Rewrite"
    case translate = "Translate"
    case explain = "Explain"
    
    var promptPrefix: String {
        switch self {
        case .clean: return "Clean the following text by removing tracking parameters, messy whitespace, and unnecessary metadata. Return ONLY the cleaned text: "
        case .summarize: return "Summarize the following text professionally and concisely. Focus on the core message: "
        case .rewrite: return "Fix the grammar, spelling, and tone of the following text to make it more professional and clear. Return ONLY the improved text: "
        case .translate: return "Translate the following text into the target language. Return ONLY the translation: "
        case .explain: return "Briefly explain what this text or code snippet does: "
        }
    }
}

class LLMService: ObservableObject {
    static let shared = LLMService()
    
    @Published var state: LLMModelState = .notLoaded
    @Published var progress: Double = 0.0
    @Published var availableModels: [AIModel] = []
    @Published var capabilityMapping: [AICapability: String] = [:]
    @Published var isOllamaConnected: Bool = true
    
    private init() {
        loadCapabilityMapping()
    }
    
    private func loadCapabilityMapping() {
        if let data = UserDefaults.standard.data(forKey: "capabilityMapping"),
           let mapping = try? JSONDecoder().decode([AICapability: String].self, from: data) {
            self.capabilityMapping = mapping
        } else {
            self.capabilityMapping = [:]
        }
    }
    
    func saveCapabilityMapping() {
        if let data = try? JSONEncoder().encode(capabilityMapping) {
            UserDefaults.standard.set(data, forKey: "capabilityMapping")
        }
    }
    
    /// Detects real local models from Ollama API
    func detectLocalModels() async {
        await MainActor.run { 
            self.state = .loading
            self.progress = 0.1
        }
        
        let url = URL(string: "http://127.0.0.1:11434/api/tags")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelsArray = json["models"] as? [[String: Any]] {
                    
                    var detected: [AIModel] = []
                    
                    for m in modelsArray {
                        if let name = m["name"] as? String {
                            // Assign capabilities based on model name keywords
                            var caps: [AICapability] = [.classification, .rewrite, .grouping, .ranking, .summarize, .clean, .translate]
                            if name.contains("code") {
                                caps.append(.suggestion)
                            }
                            
                            detected.append(AIModel(
                                name: name,
                                type: name.contains("code") ? "code" : "chat",
                                capabilities: caps,
                                maxTokens: 4096
                            ))
                        }
                    }
                    
                    await MainActor.run {
                        self.availableModels = detected
                        self.isOllamaConnected = true
                        
                        // Auto-assign first available model to missing capabilities
                        if let firstModel = detected.first {
                            for capability in AICapability.allCases {
                                if self.capabilityMapping[capability] == nil || 
                                   !detected.contains(where: { $0.name == self.capabilityMapping[capability] }) {
                                    self.capabilityMapping[capability] = firstModel.name
                                }
                            }
                        }
                        self.saveCapabilityMapping()
                        self.state = .ready
                        self.progress = 1.0
                    }
                }
            }
        } catch {
            print("Failed to fetch models from Ollama: \(error)")
            await MainActor.run {
                self.isOllamaConnected = false
                self.state = .error
                self.progress = 0.0
            }
        }
    }
    
    func loadModel() {
        Task {
            await detectLocalModels()
        }
    }
    
    private func mapActionToCapability(_ action: LLMAction) -> AICapability {
        switch action {
        case .clean: return .clean
        case .summarize: return .summarize
        case .rewrite: return .rewrite
        case .translate: return .translate
        case .explain: return .rewrite
        }
    }
    
    func process(_ content: String, action: LLMAction) async throws -> String {
        let capability = mapActionToCapability(action)
        let maxLength = UserDefaults.standard.integer(forKey: "maxOutputLength") > 0 ? UserDefaults.standard.integer(forKey: "maxOutputLength") : 200
        let targetLang = UserDefaults.standard.string(forKey: "targetLanguage") ?? "English"
        
        guard let modelName = capabilityMapping[capability], modelName != "None" else {
            throw NSError(domain: "LLMService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No model assigned for \(capability.displayName)"])
        }
        
        let url = URL(string: "http://127.0.0.1:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var prompt = ""
        if action == .translate {
            prompt = "Translate the following text strictly into \(targetLang). Return ONLY the translation, no explanation:\n\n\"\(content)\""
        } else {
            prompt = action.promptPrefix + content
        }
        
        let body: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "num_predict": maxLength,
                "temperature": 0.3
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let responseText = json["response"] as? String {
                        await MainActor.run { self.isOllamaConnected = true }
                        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else if httpResponse.statusCode == 404 {
                    return "Error: Model '\(modelName)' not found in Ollama. Please pull it or select another model."
                }
            }
        } catch {
            await MainActor.run { self.isOllamaConnected = false }
            return "Connection Error: Ensure Ollama is running."
        }
        
        return "Unexpected error occurred."
    }
    
    func processAdvanced(_ item: ClipboardItem) async -> AIProcessingResult {
        var modelsUsed: [String: String] = [:]
        var featureSkipped = false
        
        for capability in AICapability.allCases {
            if let assignedModel = capabilityMapping[capability],
               availableModels.contains(where: { $0.name == assignedModel }) {
                modelsUsed[capability.rawValue] = assignedModel
            } else {
                if let fallback = availableModels.first(where: { $0.capabilities.contains(capability) }) {
                    modelsUsed[capability.rawValue] = fallback.name
                } else {
                    featureSkipped = true
                }
            }
        }
        
        let isSensitive = CreditCardUtils.isCreditCard(item.content) || item.content.contains("password") || item.content.contains("key-")
        let riskLevel = isSensitive ? "high" : "low"
        
        return AIProcessingResult(
            modelsDetected: availableModels,
            capabilityMapping: Dictionary(uniqueKeysWithValues: capabilityMapping.map { ($0.key.rawValue, $0.value) }),
            modelsUsed: modelsUsed,
            classification: ["type": item.type.rawValue, "sensitive": isSensitive ? "true" : "false"],
            riskLevel: riskLevel,
            intentGuess: isOllamaConnected ? "Ollama Ready" : "Ollama Offline",
            suggestions: isSensitive ? [] : ["Analyze with AI"],
            grouping: [item.type.rawValue.capitalized],
            rewriteAllowed: !isSensitive,
            featureSkipped: featureSkipped,
            noModelAvailable: availableModels.isEmpty
        )
    }
}
