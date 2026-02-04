import Foundation
import SwiftUI
import Combine

class FolderManager: ObservableObject {
    static let shared = FolderManager()
    
    @Published var folders: [ClipboardFolder] = []
    @Published var currentFolderId: UUID? = nil
    
    private let storageKey = "whisprFolders"
    private let folderItemsPrefix = "whisprFolderItems_"
    
    private init() {
        loadFolders()
    }
    
    // MARK: - Folder Management
    
    func createFolder(name: String) {
        let folder = ClipboardFolder(name: name)
        folders.append(folder)
        folders.sort { $0.updatedAt > $1.updatedAt }
        saveFolders()
    }
    
    func renameFolder(_ folderId: UUID, newName: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderId }) else { return }
        folders[index].name = newName
        folders[index].updatedAt = Date()
        saveFolders()
    }
    
    func deleteFolder(_ folderId: UUID) {
        // Delete encrypted items data
        let itemsKey = "\(folderItemsPrefix)\(folderId.uuidString)"
        UserDefaults.standard.removeObject(forKey: itemsKey)
        
        folders.removeAll { $0.id == folderId }
        if currentFolderId == folderId {
            currentFolderId = nil
        }
        saveFolders()
    }
    
    // MARK: - Item Management in Folders
    
    func addItemToFolder(_ item: ClipboardItem, folderId: UUID) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else { return }
        
        var folder = folders[folderIndex]
        
        // Check if item already exists in folder
        if folder.itemIds.contains(item.id) {
            return // Already in folder
        }
        
        // Load existing items
        var items = getItemsFromFolder(folderId: folderId)
        
        // Check for duplicate by content
        if items.contains(where: { $0.id == item.id }) {
            return
        }
        
        // Add new item
        items.append(item)
        
        // Save encrypted
        saveItemsToFolder(items: items, folderId: folderId)
        
        // Update folder metadata
        folder.itemIds.append(item.id)
        folder.updatedAt = Date()
        folders[folderIndex] = folder
        saveFolders()
    }
    
    func removeItemFromFolder(_ itemId: UUID, folderId: UUID) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else { return }
        
        var folder = folders[folderIndex]
        var items = getItemsFromFolder(folderId: folderId)
        
        items.removeAll { $0.id == itemId }
        folder.itemIds.removeAll { $0 == itemId }
        folder.updatedAt = Date()
        
        saveItemsToFolder(items: items, folderId: folderId)
        folders[folderIndex] = folder
        saveFolders()
    }
    
    func getItemsFromFolder(folderId: UUID) -> [ClipboardItem] {
        let itemsKey = "\(folderItemsPrefix)\(folderId.uuidString)"
        guard let encryptedData = UserDefaults.standard.data(forKey: itemsKey) else {
            return []
        }
        
        do {
            return try EncryptionManager.shared.decryptItems(encryptedData)
        } catch {
            print("Error decrypting folder items: \(error)")
            return []
        }
    }
    
    private func saveItemsToFolder(items: [ClipboardItem], folderId: UUID) {
        let itemsKey = "\(folderItemsPrefix)\(folderId.uuidString)"
        
        do {
            let encryptedData = try EncryptionManager.shared.encryptItems(items)
            UserDefaults.standard.set(encryptedData, forKey: itemsKey)
        } catch {
            print("Error encrypting folder items: \(error)")
        }
    }
    
    // MARK: - Search in Folders
    
    func searchInFolder(_ folderId: UUID, query: String) -> [ClipboardItem] {
        let items = getItemsFromFolder(folderId: folderId)
        guard !query.isEmpty else { return items }
        
        let queryLower = query.lowercased()
        return items.filter { item in
            let contentMatch = item.content.localizedCaseInsensitiveContains(query)
            let appMatch = item.sourceApp?.localizedCaseInsensitiveContains(query) ?? false
            let tagMatch = item.tags.contains { $0.localizedCaseInsensitiveContains(queryLower) }
            return contentMatch || appMatch || tagMatch
        }
    }
    
    // MARK: - Persistence
    
    private func loadFolders() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ClipboardFolder].self, from: data) {
            self.folders = decoded
        }
    }
    
    private func saveFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
