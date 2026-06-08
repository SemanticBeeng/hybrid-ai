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
    #expect(!sendReply.text.isEmpty)

    var streamedText = ""
    for try await chunk in conversation.stream("Say hello in one sentence.") {
        streamedText += chunk
    }
    #expect(!streamedText.isEmpty)

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