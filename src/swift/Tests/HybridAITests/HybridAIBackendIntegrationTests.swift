import Foundation
import Testing
@testable import HybridAI
@testable import HybridAIBackend

private func liveBackendBaseURL() -> URL? {
    guard let rawBaseURL = ProcessInfo.processInfo.environment["HYBRID_AI_BACKEND_BASE_URL"] else {
        return nil
    }

    return URL(string: rawBaseURL)
}

private func assertNormalizedAssistantText(_ text: String) {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

    #expect(!normalized.isEmpty)
    #expect(!normalized.hasPrefix("{"))
    #expect(!normalized.contains("'role':"))
    #expect(!normalized.contains("'content':"))
    #expect(!normalized.contains("\"role\":"))
    #expect(!normalized.contains("\"content\":"))
}

private func containsAny(_ text: String, terms: [String]) -> Bool {
    let lower = text.lowercased()
    return terms.contains { lower.contains($0.lowercased()) }
}

@Test func liveBackendPrepareAndConversationLifecycle() async throws {
    guard let baseURL = liveBackendBaseURL() else {
        return
    }

    let runtime = BackendInferenceRuntime(baseURL: baseURL)

    try await runtime.prepare()
    let conversation = try await runtime.createConversation(systemPrompt: "You are a concise local assistant.")

    let idsAfterCreate = await runtime.listConversationIDs()
    #expect(idsAfterCreate.contains(conversation.id))

    await runtime.removeConversation(conversation.id)

    let idsAfterDelete = await runtime.listConversationIDs()
    #expect(!idsAfterDelete.contains(conversation.id))
}

@Test func liveBackendSendAndStreamSemantics() async throws {
    guard let baseURL = liveBackendBaseURL() else {
        return
    }

    let runtime = BackendInferenceRuntime(baseURL: baseURL)

    try await runtime.prepare()
    let conversation = try await runtime.createConversation(systemPrompt: "You are a concise local assistant.")

    let sendReply = try await conversation.send("Say hello in one sentence.")
    #expect(sendReply.role == .assistant)
    assertNormalizedAssistantText(sendReply.text)

    var streamedText = ""
    for try await chunk in conversation.stream("Say hello in one sentence.") {
        streamedText += chunk
    }
    assertNormalizedAssistantText(streamedText)

    await runtime.removeConversation(conversation.id)
}

@Test func liveBackendUnknownConversationSurfacesNotFound() async throws {
    guard let baseURL = liveBackendBaseURL() else {
        return
    }

    let client = BackendClient(baseURL: baseURL, session: .shared)
    let conversation = BackendConversationHandle(id: ConversationID(), client: client)

    do {
        _ = try await conversation.send("This should fail")
        Issue.record("Expected sending to an unknown conversation to fail")
    } catch {
        let description = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        #expect(description.contains("404"))
        #expect(description.contains("conversation not found"))
    }
}

@Test func liveBackendShoppingAssistantDisambiguatesTeeAcrossTurns() async throws {
    guard let baseURL = liveBackendBaseURL() else {
        return
    }

    let runtime = BackendInferenceRuntime(baseURL: baseURL)

    try await runtime.prepare()
    let conversation = try await runtime.createConversation(
        systemPrompt: "You are a helpful shopping assistant. When user intent is ambiguous, ask a clarifying question before recommendations."
    )
    defer {
        Task {
            await runtime.removeConversation(conversation.id)
        }
    }

    let firstReply = try await conversation.send("I want to buy tee")
    print("[liveBackendShoppingAssistantDisambiguatesTeeAcrossTurns] turn1 user: I want to buy tee")
    print("[liveBackendShoppingAssistantDisambiguatesTeeAcrossTurns] turn1 assistant: \(firstReply.text)")
    #expect(firstReply.role == .assistant)
    assertNormalizedAssistantText(firstReply.text)
    #expect(containsAny(firstReply.text, terms: ["tea", "t-shirt", "t shirt", "did you mean", "clarify"]))

    let secondReply = try await conversation.send("I meant tea")
    print("[liveBackendShoppingAssistantDisambiguatesTeeAcrossTurns] turn2 user: I meant tea")
    print("[liveBackendShoppingAssistantDisambiguatesTeeAcrossTurns] turn2 assistant: \(secondReply.text)")
    #expect(secondReply.role == .assistant)
    assertNormalizedAssistantText(secondReply.text)
    #expect(containsAny(secondReply.text, terms: ["tea", "shop", "store", "nearby", "cafe"]))

    let thirdReply = try await conversation.send("Actually, I mean t-shirt for my niece")
    print("[liveBackendShoppingAssistantDisambiguatesTeeAcrossTurns] turn3 user: Actually, I mean t-shirt for my niece")
    print("[liveBackendShoppingAssistantDisambiguatesTeeAcrossTurns] turn3 assistant: \(thirdReply.text)")
    #expect(thirdReply.role == .assistant)
    assertNormalizedAssistantText(thirdReply.text)
    #expect(containsAny(thirdReply.text, terms: ["size", "age", "gender", "fit", "color"]))
}