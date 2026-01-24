import Foundation
import SwiftUI
import Combine

class TagManager: ObservableObject {
    static let shared = TagManager()
    
    @Published var allTags: [String] = []
    private let storageKey = "whisprTags"
    
    private init() {
        loadTags()
    }
    
    private func loadTags() {
        if let tags = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            self.allTags = tags
        }
    }
    
    private func saveTags() {
        UserDefaults.standard.set(allTags, forKey: storageKey)
    }
    
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !allTags.contains(trimmed) else { return }
        allTags.append(trimmed)
        allTags.sort()
        saveTags()
    }
    
    func removeTag(_ tag: String) {
        allTags.removeAll { $0 == tag.lowercased() }
        saveTags()
    }
    
    func renameTag(oldTag: String, newTag: String) {
        let oldLower = oldTag.lowercased()
        let newLower = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !newLower.isEmpty, let index = allTags.firstIndex(of: oldLower) else { return }
        
        allTags[index] = newLower
        allTags.sort()
        saveTags()
        
        // Update all items with this tag
        ClipboardManager.shared.renameTagInAllItems(oldTag: oldLower, newTag: newLower)
    }
}
