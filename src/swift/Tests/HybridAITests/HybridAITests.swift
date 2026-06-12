import Foundation
import Testing
@testable import HybridAI

@Test func status() {
    #expect(HybridAI().status() == "hybrid-ai swift module ready")
}

@Test func chatMessageInit() {
    let message = ChatMessage(role: .user, text: "hello")

    #expect(message.role == .user)
    #expect(message.text == "hello")
}

@Test func runtimeModeCanRepresentPythonBackend() {
    let url = URL(string: "http://127.0.0.1:8080")!

    #expect(RuntimeMode.pythonBackend(baseURL: url) == .pythonBackend(baseURL: url))
}

@Test func previewAppModelProducesTranscript() async throws {
    let appModel = HybridAI().makePreviewAppModel()
    let conversationID = try await appModel.bootstrapConversation()
    let reply = try await appModel.send("hello abstractions", to: conversationID)
    let transcript = try await appModel.transcript(for: conversationID)

    #expect(reply.role == .assistant)
    #expect(reply.text.contains("hello abstractions"))
    #expect(transcript.count == 3)
}

@Test func previewAppModelSupportsManyConversations() async throws {
    let appModel = HybridAI().makePreviewAppModel()
    let first = try await appModel.createConversation(title: "Alpha")
    let second = try await appModel.createConversation(title: "Beta")

    _ = try await appModel.send("first thread", to: first.id)
    _ = try await appModel.send("second thread", to: second.id)

    let firstTranscript = try await appModel.transcript(for: first.id)
    let secondTranscript = try await appModel.transcript(for: second.id)
    let summaries = await appModel.conversationSummaries()

    #expect(firstTranscript.count == 3)
    #expect(secondTranscript.count == 3)
    #expect(firstTranscript.last?.text.contains("first thread") == true)
    #expect(secondTranscript.last?.text.contains("second thread") == true)
    #expect(summaries.map(\.title) == ["Alpha", "Beta"])

    await appModel.selectConversation(first.id)
    let selected = await appModel.selectedConversation()
    #expect(selected?.id == first.id)

    await appModel.deleteConversation(first.id)
    let remaining = await appModel.conversationSummaries()
    #expect(remaining.map(\.title) == ["Beta"])
}
