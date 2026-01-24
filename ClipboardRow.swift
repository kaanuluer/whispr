import SwiftUI

struct ClipboardRow: View {
    let item: ClipboardItem
    @State private var isHovered = false
    @State private var showTagInput = false
    @State private var newTagText = ""
    @ObservedObject var tagManager = TagManager.shared
    @AppStorage("enableAI") private var enableAI = true
    
    @AppStorage("showCleanAction") private var showCleanAction = true
    @AppStorage("showSummarizeAction") private var showSummarizeAction = true
    @AppStorage("showRewriteAction") private var showRewriteAction = true
    @AppStorage("showTranslateAction") private var showTranslateAction = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                // Type Icon
                Image(systemName: item.type.symbol)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .center)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Content Preview
                    HStack(spacing: 6) {
                        if item.type == .creditCard {
                            Text(CreditCardUtils.detectCardType(number: item.content) ?? "Card")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(WhisprStyle.accentColor)
                                .cornerRadius(3)
                            
                            Text(CreditCardUtils.maskCardNumber(item.content))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                        } else if item.type == .image, let data = item.imageData, let nsImage = NSImage(data: data) {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 200, maxHeight: 120)
                                    .cornerRadius(4)
                                    .shadow(radius: 1)
                                
                                if !item.content.isEmpty && item.content != "Image Content" {
                                    Text(item.content)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text(item.content)
                                .font(.system(size: 13, weight: .regular))
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Metadata
                    HStack(spacing: 4) {
                        if let source = item.sourceApp {
                            Text(source)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(WhisprStyle.accentColor.opacity(0.8))
                            
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        
                        Text(item.timestamp.relativeDescription())
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WhisprStyle.accentColor)
                        }
                        
                        if let ai = item.advancedAIResult {
                            if ai.riskLevel == "high" {
                                Text("SENSITIVE")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.red)
                                    .cornerRadius(2)
                            }
                            
                            if !ai.intentGuess.isEmpty {
                                Text(ai.intentGuess)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                    
                    // Tags Display
                    if !item.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(item.tags, id: \.self) { tag in
                                TagBadge(tag: tag, onRemove: {
                                    ClipboardManager.shared.removeTag(tag, from: item)
                                })
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                if isHovered {
                    HStack(spacing: 8) {
                        Button(action: {
                            ClipboardManager.shared.togglePin(for: item)
                        }) {
                            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 12))
                                .foregroundColor(item.isPinned ? WhisprStyle.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin" : "Pin")

                        Button(action: {
                            withAnimation(.spring()) {
                                ClipboardManager.shared.removeItem(item)
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Remove from history")
                    }
                    .padding(.trailing, 4)
                }
                
                // Inline AI Progress
                if item.isProcessingAI {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            // Image File Actions or AI Actions
            if isHovered && !item.isProcessingAI {
                if item.type == .image && item.filePath != nil {
                    HStack(spacing: 4) {
                        ActionIcon(symbol: "folder", label: "Open Location") {
                            ClipboardManager.shared.openFileLocation(for: item)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                } else if enableAI {
                    HStack(spacing: 4) {
                        if showCleanAction {
                            ActionIcon(symbol: "wand.and.stars", label: "Clean") {
                                ClipboardManager.shared.performAIAction(item, action: .clean)
                            }
                        }
                        if showSummarizeAction {
                            ActionIcon(symbol: "text.alignleft", label: "Summ") {
                                ClipboardManager.shared.performAIAction(item, action: .summarize)
                            }
                        }
                        if showRewriteAction {
                            ActionIcon(symbol: "pencil", label: "Fix") {
                                ClipboardManager.shared.performAIAction(item, action: .rewrite)
                            }
                        }
                        if showTranslateAction {
                            ActionIcon(symbol: "character.book.closed", label: "Tr") {
                                ClipboardManager.shared.performAIAction(item, action: .translate)
                            }
                        }
                        
                        ActionIcon(symbol: "tag", label: "Tag") {
                            showTagInput.toggle()
                        }
                        
                        Spacer(minLength: 4)
                        
                        Button(action: {
                            ClipboardManager.shared.copyToClipboard(item)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(WhisprStyle.accentColor)
                                .frame(width: 24, height: 24)
                                .background(WhisprStyle.accentColor.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Copy original")
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                }
            }
            
            // Tag Input - Only show when hovered and tag button was clicked
            if showTagInput && isHovered {
                TagInputView(
                    newTagText: $newTagText,
                    availableTags: tagManager.allTags.filter { !item.tags.contains($0) },
                    onAdd: { tag in
                        ClipboardManager.shared.addTag(tag, to: item)
                        newTagText = ""
                        showTagInput = false
                    },
                    onCreateNew: {
                        if !newTagText.isEmpty {
                            ClipboardManager.shared.addTag(newTagText, to: item)
                            newTagText = ""
                            showTagInput = false
                        }
                    },
                    onCancel: {
                        showTagInput = false
                        newTagText = ""
                    }
                )
                .padding(.top, 4)
            }
            
            // AI Result Area
            if let result = item.aiResult {
                AIResultView(result: result, onCopy: {
                    ClipboardManager.shared.copyToClipboard(result)
                }, onClose: {
                    ClipboardManager.shared.clearAIResult(for: item)
                })
                .padding(.top, 4)
            }
        }
        .padding(WhisprStyle.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(WhisprStyle.cornerRadius)
        .contentShape(Rectangle()) // Make the whole row clickable
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                // Visual feedback
            }
            ClipboardManager.shared.copyToClipboard(item)
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovered = hovering
                if !hovering {
                    showTagInput = false
                    newTagText = ""
                }
            }
        }
    }
}

struct ActionIcon: View {
    let symbol: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.primary.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

struct AIResultView: View {
    let result: String
    let onCopy: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Rectangle()
                    .fill(WhisprStyle.accentColor.opacity(0.5))
                    .frame(width: 2)
                    .cornerRadius(1)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("A cleaner version is ready")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WhisprStyle.accentColor)
                    
                    Text(result)
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.8))
                        .lineLimit(4)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10))
                            .foregroundColor(WhisprStyle.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Copy result")
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
            }
            .padding(8)
            .background(WhisprStyle.accentColor.opacity(0.05))
            .cornerRadius(6)
        }
    }
}

struct TagBadge: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 9, weight: .medium))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 8))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(WhisprStyle.accentColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(WhisprStyle.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TagInputView: View {
    @Binding var newTagText: String
    let availableTags: [String]
    let onAdd: (String) -> Void
    let onCreateNew: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Tag name", text: $newTagText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .onSubmit {
                        onCreateNew()
                    }
                
                Button(action: onCreateNew) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(WhisprStyle.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newTagText.isEmpty)
                
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
            
            if !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(availableTags, id: \.self) { tag in
                            Button(action: { onAdd(tag) }) {
                                Text(tag)
                                    .font(.system(size: 9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.08))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

extension Date {
    func relativeDescription() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
