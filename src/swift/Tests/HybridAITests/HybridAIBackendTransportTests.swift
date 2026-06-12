import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import HybridAI
@testable import HybridAIBackend

private final class MockBackendURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    private static var handlers: [String: Handler] = [:]

    static func register(host: String, handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        handlers[host] = handler
    }

    static func unregister(host: String) {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeValue(forKey: host)
    }

    private static func handler(for host: String) -> Handler? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[host]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host(), let handler = Self.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class MockBackendServer: @unchecked Sendable {
    private let lock = NSLock()
    private var conversations: [String] = []
    private let ready: Bool
    private let readinessIssues: [String]

    init(ready: Bool = true, readinessIssues: [String] = []) {
        self.ready = ready
        self.readinessIssues = readinessIssues
    }

    func handle(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        switch (request.httpMethod ?? "GET", url.path) {
        case ("GET", "/ready"):
            return jsonResponse(
                url: url,
                statusCode: ready ? 200 : 503,
                payload: ["ready": ready, "issues": readinessIssues]
            )

        case ("GET", "/v1/conversations"):
            lock.lock()
            let ids = conversations
            lock.unlock()
            return jsonResponse(url: url, statusCode: 200, payload: ["conversation_ids": ids])

        case ("POST", "/v1/conversations"):
            let conversationID = UUID().uuidString.lowercased()
            lock.lock()
            conversations.append(conversationID)
            lock.unlock()
            return jsonResponse(url: url, statusCode: 201, payload: ["conversation_id": conversationID])

        case ("DELETE", let path) where path.hasPrefix("/v1/conversations/"):
            let id = path.replacingOccurrences(of: "/v1/conversations/", with: "")
            lock.lock()
            conversations.removeAll { $0 == id }
            lock.unlock()
            return emptyResponse(url: url, statusCode: 204)

        case ("POST", let path) where path.hasPrefix("/v1/conversations/") && path.hasSuffix("/messages"):
            let id = path
                .replacingOccurrences(of: "/v1/conversations/", with: "")
                .replacingOccurrences(of: "/messages", with: "")

            lock.lock()
            let exists = conversations.contains(id)
            lock.unlock()

            guard exists else {
                return jsonResponse(
                    url: url,
                    statusCode: 404,
                    payload: ["error": ["code": "not_found", "message": "conversation not found: \(id)"]]
                )
            }

            let requestBody = try decodeJSONObject(from: request)
            let text = requestBody["text"] as? String ?? ""
            return jsonResponse(
                url: url,
                statusCode: 200,
                payload: [
                    "conversation_id": id,
                    "message": [
                        "role": "assistant",
                        "text": "Mock backend reply to: \(text)"
                    ]
                ]
            )

        default:
            return jsonResponse(
                url: url,
                statusCode: 404,
                payload: ["error": ["code": "not_found", "message": "endpoint not found"]]
            )
        }
    }

    private func decodeJSONObject(from request: URLRequest) throws -> [String: Any] {
        guard let body = request.httpBody, !body.isEmpty else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: body)
        return object as? [String: Any] ?? [:]
    }

    private func jsonResponse(url: URL, statusCode: Int, payload: [String: Any]) -> (HTTPURLResponse, Data) {
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, data)
    }

    private func emptyResponse(url: URL, statusCode: Int) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }
}

private func makeMockSession(host: String, handler: @escaping MockBackendURLProtocol.Handler) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockBackendURLProtocol.self]
    MockBackendURLProtocol.register(host: host, handler: handler)
    return URLSession(configuration: configuration)
}

private func makeMockBaseURL(host: String) -> URL {
    URL(string: "http://\(host)")!
}

private func makeMockHost() -> String {
    "backend-\(UUID().uuidString.lowercased()).test"
}

@Test func backendTransportSatisfiesContractAgainstBackendResponses() async throws {
    let host = makeMockHost()
    let server = MockBackendServer()
    let session = makeMockSession(host: host) { request in
        try server.handle(request)
    }
    defer {
        session.invalidateAndCancel()
        MockBackendURLProtocol.unregister(host: host)
    }

    let runtime = BackendInferenceRuntime(baseURL: makeMockBaseURL(host: host), session: session)

    try await runtime.prepare()
    #expect(await runtime.listConversationIDs().isEmpty)

    let first = try await runtime.createConversation(systemPrompt: "You are a contract test runtime.")
    let second = try await runtime.createConversation(systemPrompt: nil)

    let idsAfterCreate = await runtime.listConversationIDs()
    #expect(idsAfterCreate.count == 2)
    #expect(idsAfterCreate.contains(first.id))
    #expect(idsAfterCreate.contains(second.id))
    #expect(first.id != second.id)

    let sendReply = try await first.send("hello contract")
    #expect(sendReply.role == .assistant)
    #expect(sendReply.text == "Mock backend reply to: hello contract")

    var streamedText = ""
    for try await chunk in second.stream("stream contract") {
        streamedText += chunk
    }
    #expect(streamedText == "Mock backend reply to: stream contract")

    await runtime.removeConversation(first.id)
    let idsAfterDelete = await runtime.listConversationIDs()
    #expect(idsAfterDelete.count == 1)
    #expect(idsAfterDelete.contains(second.id))
    #expect(!idsAfterDelete.contains(first.id))
}

@Test func backendTransportSurfacesReadinessFailures() async throws {
    let host = makeMockHost()
    let server = MockBackendServer(ready: false, readinessIssues: ["failed to initialize LiteRT-LM engine"])
    let session = makeMockSession(host: host) { request in
        try server.handle(request)
    }
    defer {
        session.invalidateAndCancel()
        MockBackendURLProtocol.unregister(host: host)
    }

    let runtime = BackendInferenceRuntime(baseURL: makeMockBaseURL(host: host), session: session)

    do {
        try await runtime.prepare()
        Issue.record("Expected prepare() to fail when /ready reports ready=false")
    } catch {
        let description = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        #expect(description.contains("failed to initialize LiteRT-LM engine"))
    }
}

@Test func backendTransportSupportsShoppingAssistantTeeDisambiguationMultiTurn() async throws {
    let host = makeMockHost()
    let server = MockBackendServer()
    let session = makeMockSession(host: host) { request in
        try server.handle(request)
    }
    defer {
        session.invalidateAndCancel()
        MockBackendURLProtocol.unregister(host: host)
    }

    let runtime = BackendInferenceRuntime(baseURL: makeMockBaseURL(host: host), session: session)

    try await runtime.prepare()
    let conversation = try await runtime.createConversation(
        systemPrompt: "You are a shopping assistant. Clarify ambiguous requests before recommending items."
    )

    let firstReply = try await conversation.send("I want to buy tee")
    #expect(firstReply.role == .assistant)
    #expect(!firstReply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

    let secondReply = try await conversation.send("I mean tea")
    #expect(secondReply.role == .assistant)
    #expect(!secondReply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

    let thirdReply = try await conversation.send("Actually t-shirt for my niece")
    #expect(thirdReply.role == .assistant)
    #expect(!thirdReply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

    let ids = await runtime.listConversationIDs()
    #expect(ids.contains(conversation.id))

    await runtime.removeConversation(conversation.id)
    let idsAfterDelete = await runtime.listConversationIDs()
    #expect(!idsAfterDelete.contains(conversation.id))
}