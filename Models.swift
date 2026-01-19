import Foundation
import SwiftUI

enum ClipboardContentType: String, CaseIterable {
    case text
    case link
    case code
    case image
    case creditCard
    
    var symbol: String {
        switch self {
        case .text: return "doc.text"
        case .link: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .creditCard: return "creditcard.fill"
        }
    }
}

struct ClipboardItem: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let type: ClipboardContentType
    let timestamp: Date
    let sourceApp: String? // Name of the app the content was copied from
    var isPinned: Bool = false
    var aiResult: String? = nil
    var advancedAIResult: AIProcessingResult? = nil
    var isProcessingAI: Bool = false
}

// Design Tokens
enum WhisprStyle {
    static let cornerRadius: CGFloat = 8
    static let rowPadding: CGFloat = 8
    static let horizontalPadding: CGFloat = 12
    static let accentColor = Color.orange // Warm, legible orange
    static let secondaryText = Color.secondary
}

struct CreditCardUtils {
    struct CardNetwork {
        let key: String
        let displayName: String
        let regex: String
        let lengths: [Int]
    }
    
    static let networks: [CardNetwork] = [
        CardNetwork(key: "AMERICAN_EXPRESS", displayName: "American Express", regex: "^3[47][0-9]{13}$", lengths: [15]),
        CardNetwork(key: "DINERS_CLUB", displayName: "Diners Club", regex: "^(30[0-5]|36|38)[0-9]{11}$", lengths: [14]),
        CardNetwork(key: "JCB", displayName: "JCB", regex: "^35[0-9]{14}$", lengths: [16]),
        CardNetwork(key: "DISCOVER", displayName: "Discover", regex: "^(6011|65|64[4-9])[0-9]{12,15}$", lengths: [16, 19]),
        CardNetwork(key: "MASTERCARD", displayName: "Mastercard", regex: "^(5[1-5][0-9]{14}|2[2-7][0-9]{14})$", lengths: [16]),
        CardNetwork(key: "VISA", displayName: "Visa", regex: "^4[0-9]{12}(?:[0-9]{3}|[0-9]{6})?$", lengths: [13, 16, 19]),
        CardNetwork(key: "MAESTRO", displayName: "Maestro", regex: "^(50|56|57|58|6)[0-9]{10,17}$", lengths: [12, 13, 14, 15, 16, 17, 18, 19]),
        CardNetwork(key: "UNIONPAY", displayName: "UnionPay", regex: "^62[0-9]{14,17}$", lengths: [16, 17, 18, 19]),
        CardNetwork(key: "RUPAY", displayName: "RuPay", regex: "^60[0-9]{14,17}$", lengths: [16, 17, 18, 19]),
        CardNetwork(key: "MIR", displayName: "MIR", regex: "^220[0-4][0-9]{12}$", lengths: [16]),
        CardNetwork(key: "TROY", displayName: "TROY", regex: "^9792[0-9]{12}$", lengths: [16])
    ]
    
    static func detectCardType(number: String) -> String? {
        let cleaned = number.replacingOccurrences(of: "\\s|-", with: "", options: .regularExpression)
        
        for network in networks {
            if cleaned.range(of: network.regex, options: .regularExpression) != nil {
                if network.lengths.contains(cleaned.count) {
                    return network.displayName
                }
            }
        }
        
        return nil
    }
    
    static func maskCardNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: "\\s|-", with: "", options: .regularExpression)
        guard cleaned.count >= 4 else { return number }
        
        let lastFour = cleaned.suffix(4)
        return "**** **** **** \(lastFour)"
    }
    
    static func isCreditCard(_ text: String) -> Bool {
        let cleaned = text.replacingOccurrences(of: "\\s|-", with: "", options: .regularExpression)
        // Check against all known network regexes and lengths
        for network in networks {
            if cleaned.range(of: network.regex, options: .regularExpression) != nil {
                if network.lengths.contains(cleaned.count) {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Advanced AI Models

enum AICapability: String, CaseIterable, Codable {
    case classification = "classification"
    case suggestion = "suggestion"
    case ranking = "ranking"
    case grouping = "grouping"
    case rewrite = "rewrite"
    case clean = "clean"
    case summarize = "summarize"
    case translate = "translate"
    
    var displayName: String {
        self.rawValue.capitalized
    }
}

struct AIModel: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let type: String // chat, code, general
    let capabilities: [AICapability]
    let maxTokens: Int
}

struct AIProcessingResult: Codable, Hashable {
    let modelsDetected: [AIModel]
    let capabilityMapping: [String: String]
    let modelsUsed: [String: String]
    let classification: [String: String]
    let riskLevel: String // low, medium, high
    let intentGuess: String
    let suggestions: [String]
    let grouping: [String]
    let rewriteAllowed: Bool
    let featureSkipped: Bool
    let noModelAvailable: Bool
}
