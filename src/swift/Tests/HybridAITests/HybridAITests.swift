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
