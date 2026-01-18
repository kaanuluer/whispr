import AppKit
import Combine

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var items: [ClipboardItem] = []
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    
    private init() {
        // Add some welcome items
        addItem(content: "Welcome to Whispr! Copy any text to see it here.", type: .text)
        addItem(content: "Hover over items to see local AI actions like Clean or Summarize.", type: .text)
        
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let content = pasteboard.string(forType: .string) {
            if CreditCardUtils.isCreditCard(content) {
                addItem(content: content, type: .creditCard)
            } else {
                addItem(content: content, type: .text)
            }
        }
    }
    
    func addItem(content: String, type: ClipboardContentType) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        DispatchQueue.main.async {
            // 1. Remove any existing item with the same content (Duplicate prevention)
            // We keep the pinned status if we're moving an existing item
            var wasPinned = false
            if let existingIndex = self.items.firstIndex(where: { $0.content == trimmedContent }) {
                wasPinned = self.items[existingIndex].isPinned
                self.items.remove(at: existingIndex)
            }
            
            // 2. Create and insert the new item
            let newItem = ClipboardItem(
                content: trimmedContent,
                type: type,
                timestamp: Date(),
                isPinned: wasPinned
            )
            
            self.items.insert(newItem, at: 0)
            
            // 3. Re-sort to ensure pins stay at top
            self.items.sort { (a, b) in
                if a.isPinned != b.isPinned {
                    return a.isPinned
                }
                return a.timestamp > b.timestamp
            }
            
            // 4. Limit history size
            if self.items.count > 100 {
                self.items.removeLast()
            }
        }
    }
    
    func performAIAction(_ item: ClipboardItem, action: LLMAction) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        items[index].isProcessingAI = true
        
        Task {
            do {
                let result = try await LLMService.shared.process(item.content, action: action)
                await MainActor.run {
                    if let newIndex = self.items.firstIndex(where: { $0.id == item.id }) {
                        self.items[newIndex].aiResult = result
                        self.items[newIndex].isProcessingAI = false
                    }
                }
            } catch {
                await MainActor.run {
                    if let newIndex = self.items.firstIndex(where: { $0.id == item.id }) {
                        self.items[newIndex].isProcessingAI = false
                        // Handle error state in UI
                    }
                }
            }
        }
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func togglePin(for item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        let currentlyPinnedCount = items.filter { $0.isPinned }.count
        
        if !items[index].isPinned && currentlyPinnedCount >= 3 {
            // Optional: Show a notification or alert that max 3 pins are allowed
            return
        }
        
        items[index].isPinned.toggle()
        
        // Re-sort items: Pinned first, then by date
        items.sort { (a, b) in
            if a.isPinned != b.isPinned {
                return a.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }
    
    func clearAIResult(for item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].aiResult = nil
        }
    }
}
