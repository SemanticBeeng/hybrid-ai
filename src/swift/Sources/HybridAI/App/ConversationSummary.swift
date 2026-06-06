public struct ConversationSummary: Sendable {
    public let id: ConversationID
    public var title: String

    public init(id: ConversationID, title: String) {
        self.id = id
        self.title = title
    }
}