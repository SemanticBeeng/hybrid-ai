public actor ChatAppModel {
    private let runtime: any InferenceRuntime
    private var conversations: [ConversationID: any ConversationHandle] = [:]
    private var conversationSummariesByID: [ConversationID: ConversationSummary] = [:]
    private var transcripts: [ConversationID: [ChatMessage]] = [:]
    private var selectedConversationID: ConversationID?

    public init(runtime: any InferenceRuntime) {
        self.runtime = runtime
    }

    @discardableResult
    public func bootstrapConversation(title: String = "Preview Chat") async throws -> ConversationID {
        let summary = try await createConversation(title: title)
        return summary.id
    }

    @discardableResult
    public func createConversation(
        title: String? = nil,
        systemPrompt: String = "You are a concise local Hybrid AI assistant."
    ) async throws -> ConversationSummary {
        try await runtime.prepare()

        let conversation = try await runtime.createConversation(systemPrompt: systemPrompt)
        let summary = ConversationSummary(
            id: conversation.id,
            title: title ?? "Conversation \(conversationSummariesByID.count + 1)"
        )

        conversations[conversation.id] = conversation
        conversationSummariesByID[conversation.id] = summary
        transcripts[conversation.id] = [
            ChatMessage(role: .assistant, text: "Hybrid AI runtime ready. Inference abstractions are connected.")
        ]
        selectedConversationID = conversation.id

        return summary
    }

    public func conversationSummaries() async -> [ConversationSummary] {
        conversationSummariesByID.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func selectedConversation() async -> ConversationSummary? {
        guard let selectedConversationID else {
            return nil
        }

        return conversationSummariesByID[selectedConversationID]
    }

    public func selectConversation(_ id: ConversationID) {
        guard conversations[id] != nil else {
            return
        }

        selectedConversationID = id
    }

    public func deleteConversation(_ id: ConversationID) async {
        conversations.removeValue(forKey: id)
        conversationSummariesByID.removeValue(forKey: id)
        transcripts.removeValue(forKey: id)
        await runtime.removeConversation(id)

        if selectedConversationID == id {
            selectedConversationID = conversationSummariesByID.keys.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }.first
        }
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

    public func selectedTranscript() async throws -> [ChatMessage] {
        try await transcript(for: selectedConversationID)
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