public actor ChatAppModel {
    private let runtime: any InferenceRuntime
    private var conversations: [ConversationID: any ConversationHandle] = [:]
    private var transcripts: [ConversationID: [ChatMessage]] = [:]
    private var selectedConversationID: ConversationID?

    public init(runtime: any InferenceRuntime) {
        self.runtime = runtime
    }

    @discardableResult
    public func bootstrapConversation(title: String = "Preview Chat") async throws -> ConversationID {
        try await runtime.prepare()

        let conversation = try await runtime.createConversation(
            systemPrompt: "You are a concise local Hybrid AI assistant."
        )

        conversations[conversation.id] = conversation
        transcripts[conversation.id] = [
            ChatMessage(role: .assistant, text: "Hybrid AI runtime ready. Inference abstractions are connected.")
        ]
        selectedConversationID = conversation.id

        return conversation.id
    }

    @discardableResult
    public func send(_ text: String, to conversationID: ConversationID? = nil) async throws -> ChatMessage {
        let activeID = try await ensureConversation(conversationID)
        guard let conversation = conversations[activeID] else {
            fatalError("Conversation disappeared after validation")
        }

        transcripts[activeID, default: []].append(ChatMessage(role: .user, text: text))

        let reply = try await conversation.send(text)
        transcripts[activeID, default: []].append(reply)
        return reply
    }

    public func transcript(for conversationID: ConversationID? = nil) async throws -> [ChatMessage] {
        let activeID = try await ensureConversation(conversationID)
        return transcripts[activeID, default: []]
    }

    private func ensureConversation(_ conversationID: ConversationID?) async throws -> ConversationID {
        if let conversationID, conversations[conversationID] != nil {
            return conversationID
        }

        if let selectedConversationID, conversations[selectedConversationID] != nil {
            return selectedConversationID
        }

        return try await bootstrapConversation()
    }
}