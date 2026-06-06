import Foundation

public struct ChatMessage: Identifiable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public var text: String

    public init(id: UUID = UUID(), role: ChatRole, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}