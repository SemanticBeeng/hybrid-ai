import Testing
@testable import HybridAI

private struct InferenceRuntimeContract {
    let makeRuntime: @Sendable () -> any InferenceRuntime

    func assertBasicLifecycle() async throws {
        let runtime = makeRuntime()

        try await runtime.prepare()
        #expect(await runtime.listConversationIDs().isEmpty)

        let first = try await runtime.createConversation(systemPrompt: "You are a contract test runtime.")
        let second = try await runtime.createConversation(systemPrompt: nil)

        let idsAfterCreate = await runtime.listConversationIDs()
        #expect(idsAfterCreate.count == 2)
        #expect(idsAfterCreate.contains(first.id))
        #expect(idsAfterCreate.contains(second.id))
        #expect(first.id != second.id)

        await runtime.removeConversation(first.id)
        let idsAfterDelete = await runtime.listConversationIDs()
        #expect(idsAfterDelete.count == 1)
        #expect(idsAfterDelete.contains(second.id))
        #expect(!idsAfterDelete.contains(first.id))
    }

    func assertSendAndStreamSemantics() async throws {
        let runtime = makeRuntime()

        try await runtime.prepare()

        let sendConversation = try await runtime.createConversation(systemPrompt: "Send contract")
        let sendReply = try await sendConversation.send("hello contract")
        #expect(sendReply.role == .assistant)
        #expect(!sendReply.text.isEmpty)

        let streamConversation = try await runtime.createConversation(systemPrompt: "Stream contract")
        var streamedText = ""
        for try await chunk in streamConversation.stream("stream contract") {
            streamedText += chunk
        }

        #expect(!streamedText.isEmpty)
    }
}

@Test func previewInferenceRuntimeSatisfiesLifecycleContract() async throws {
    let contract = InferenceRuntimeContract(makeRuntime: { PreviewInferenceRuntime() })
    try await contract.assertBasicLifecycle()
}

@Test func previewInferenceRuntimeSatisfiesSendAndStreamContract() async throws {
    let contract = InferenceRuntimeContract(makeRuntime: { PreviewInferenceRuntime() })
    try await contract.assertSendAndStreamSemantics()
}