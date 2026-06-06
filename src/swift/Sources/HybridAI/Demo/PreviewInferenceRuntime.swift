import Foundation

public actor PreviewInferenceRuntime: InferenceRuntime {
    private var conversationIDs: [ConversationID] = []

    public init() {}

    public func prepare() async throws {}

    public func createConversation(systemPrompt: String?) async throws -> any ConversationHandle {
        let conversation = PreviewConversationHandle(systemPrompt: systemPrompt)
        conversationIDs.append(conversation.id)
        return conversation
    }

    public func listConversationIDs() async -> [ConversationID] {
        conversationIDs
    }

    public func removeConversation(_ id: ConversationID) async {
        conversationIDs.removeAll { $0 == id }
    }
}

public struct PreviewConversationHandle: ConversationHandle {
    public let id: ConversationID
    private let systemPrompt: String?

    public init(id: ConversationID = ConversationID(), systemPrompt: String?) {
        self.id = id
        self.systemPrompt = systemPrompt
    }

    public func send(_ text: String) async throws -> ChatMessage {
        ChatMessage(role: .assistant, text: makeReply(for: text))
    }

    public func stream(_ text: String) -> AsyncThrowingStream<String, Error> {
        let reply = makeReply(for: text)
        let chunks = reply.split(separator: " ").map(String.init)

        return AsyncThrowingStream { continuation in
            for (index, chunk) in chunks.enumerated() {
                continuation.yield(index == 0 ? chunk : " " + chunk)
            }
            continuation.finish()
        }
    }

    private func makeReply(for text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let systemSummary = systemPrompt ?? "no system prompt"
        return "Preview runtime reply to: \(normalized). Engine model: one runtime with many conversations. System prompt: \(systemSummary)."
    }
}