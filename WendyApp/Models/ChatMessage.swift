import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case error
    case confirmation
}

/// Lifecycle of a gated tool-call confirmation bubble.
enum ConfirmResolution: String, Codable {
    case pending
    case approved
    case denied
    case expired
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    // Confirmation-only fields (role == .confirmation); optional so
    // previously saved chats still decode.
    let turnID: String?
    let confirmationID: Int?
    var resolution: ConfirmResolution?

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.turnID = nil
        self.confirmationID = nil
        self.resolution = nil
    }

    init(confirmationMessage: String, turnID: String, confirmationID: Int) {
        self.id = UUID()
        self.role = .confirmation
        self.content = confirmationMessage
        self.timestamp = Date()
        self.turnID = turnID
        self.confirmationID = confirmationID
        self.resolution = .pending
    }
}
