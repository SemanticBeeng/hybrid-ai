import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HybridAI

public struct HybridAIBackend: RuntimeFactory, Sendable {
    public init() {}

    public func makeRuntime(for mode: RuntimeMode) -> any InferenceRuntime {
        switch mode {
        case .pythonBackend(let baseURL):
            return BackendInferenceRuntime(baseURL: baseURL)
        case .appleLiteRT:
            preconditionFailure("HybridAIBackend only supports RuntimeMode.pythonBackend")
        }
    }

    public func makeRuntime(baseURL: URL) -> any InferenceRuntime {
        BackendInferenceRuntime(baseURL: baseURL)
    }
}

public actor BackendInferenceRuntime: InferenceRuntime {
    private let client: BackendClient
    private var prepared = false
    private var conversationIDs: [ConversationID] = []

    public init(baseURL: URL, session: URLSession = .shared) {
        self.client = BackendClient(baseURL: baseURL, session: session)
    }

    public func prepare() async throws {
        guard !prepared else {
            return
        }

        try await client.ensureReady()
        prepared = true
    }

    public func createConversation(systemPrompt: String?) async throws -> any ConversationHandle {
        try await prepare()
        let id = try await client.createConversation(systemPrompt: systemPrompt)
        conversationIDs.append(id)
        return BackendConversationHandle(id: id, client: client)
    }

    public func listConversationIDs() async -> [ConversationID] {
        conversationIDs
    }

    public func removeConversation(_ id: ConversationID) async {
        conversationIDs.removeAll { $0 == id }
        do {
            try await client.deleteConversation(id)
        } catch {
            // Deletion is best-effort from the app model's perspective.
        }
    }
}

public struct BackendConversationHandle: ConversationHandle {
    public let id: ConversationID
    let client: BackendClient

    public func send(_ text: String) async throws -> ChatMessage {
        try await client.sendMessage(text, to: id)
    }

    public func stream(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let reply = try await client.sendMessage(text, to: id)
                    let chunks = reply.text.split(separator: " ").map(String.init)
                    for (index, chunk) in chunks.enumerated() {
                        continuation.yield(index == 0 ? chunk : " " + chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

actor BackendClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
    }

    func ensureReady() async throws {
        let response: ReadyResponse = try await request(path: "/ready", method: "GET", body: nil)
        guard response.ready else {
            throw BackendTransportError.notReady(issues: response.issues)
        }
    }

    func createConversation(systemPrompt: String?) async throws -> ConversationID {
        let response: CreateConversationResponse = try await request(
            path: "/v1/conversations",
            method: "POST",
            body: AnyEncodable(CreateConversationRequest(systemPrompt: systemPrompt))
        )
        return try parseConversationID(response.conversationID)
    }

    func deleteConversation(_ id: ConversationID) async throws {
        try await requestNoContent(path: "/v1/conversations/\(id.rawValue.uuidString)", method: "DELETE")
    }

    func sendMessage(_ text: String, to id: ConversationID) async throws -> ChatMessage {
        let response: SendMessageResponse = try await request(
            path: "/v1/conversations/\(id.rawValue.uuidString)/messages",
            method: "POST",
            body: AnyEncodable(SendMessageRequest(text: text))
        )
        let role = ChatRole(rawValue: response.message.role) ?? .assistant
        return ChatMessage(role: role, text: response.message.text)
    }

    private func request<Response: Decodable>(path: String, method: String, body: AnyEncodable?) async throws -> Response {
        let data = try await send(path: path, method: method, body: body)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw BackendTransportError.invalidResponse(error.localizedDescription)
        }
    }

    private func requestNoContent(path: String, method: String) async throws {
        _ = try await send(path: path, method: method, body: nil)
    }

    private func send(path: String, method: String, body: AnyEncodable?) async throws -> Data {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendTransportError.invalidResponse("missing HTTP response")
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw decodeError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }

    private func decodeError(statusCode: Int, data: Data) -> Error {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return BackendTransportError.server(statusCode: statusCode, message: envelope.error.message)
        }

        let fallback = String(data: data, encoding: .utf8) ?? "unknown backend error"
        return BackendTransportError.server(statusCode: statusCode, message: fallback)
    }

    private func parseConversationID(_ rawValue: String) throws -> ConversationID {
        guard let uuid = UUID(uuidString: rawValue) else {
            throw BackendTransportError.invalidConversationID(rawValue)
        }

        return ConversationID(uuid)
    }
}

struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init(_ wrapped: some Encodable) {
        self.encodeImpl = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}

enum BackendTransportError: LocalizedError {
    case invalidResponse(String)
    case invalidConversationID(String)
    case notReady(issues: [String])
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let detail):
            return "Invalid backend response: \(detail)"
        case .invalidConversationID(let rawValue):
            return "Backend returned an invalid conversation identifier: \(rawValue)"
        case .notReady(let issues):
            let joined = issues.isEmpty ? "backend is not ready" : issues.joined(separator: "; ")
            return "Backend readiness check failed: \(joined)"
        case .server(let statusCode, let message):
            return "Backend request failed with status \(statusCode): \(message)"
        }
    }
}

private struct ReadyResponse: Decodable {
    let ready: Bool
    let issues: [String]
}

private struct CreateConversationRequest: Encodable {
    let systemPrompt: String?

    enum CodingKeys: String, CodingKey {
        case systemPrompt = "system_prompt"
    }
}

private struct CreateConversationResponse: Decodable {
    let conversationID: String

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
    }
}

private struct SendMessageRequest: Encodable {
    let text: String
}

private struct SendMessageResponse: Decodable {
    struct Message: Decodable {
        let role: String
        let text: String
    }

    let conversationID: String
    let message: Message

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case message
    }
}

private struct ErrorEnvelope: Decodable {
    struct ErrorPayload: Decodable {
        let code: String
        let message: String
    }

    let error: ErrorPayload
}