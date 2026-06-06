public protocol ConversationHandle: Sendable {
    var id: ConversationID { get }

    func send(_ text: String) async throws -> ChatMessage
    func stream(_ text: String) -> AsyncThrowingStream<String, Error>
}