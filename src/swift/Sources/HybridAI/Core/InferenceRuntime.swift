public protocol InferenceRuntime: Sendable {
    func prepare() async throws
    func createConversation(systemPrompt: String?) async throws -> any ConversationHandle
    func listConversationIDs() async -> [ConversationID]
    func removeConversation(_ id: ConversationID) async
}