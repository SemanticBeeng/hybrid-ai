## LiteRT-LM Gemma 4 E4B Endpoint And Swift Integration Runbook

Date: 2026-06-05
Status: Review and implementation roadmap
Scope: Introduce an LLM endpoint using Google LiteRT-LM, serve Gemma 4 E4B through it, expose Swift bindings, and call it from the Swift UI app.

## Findings

1. The current Swift UI target and the upstream LiteRT-LM Swift bindings do not line up on platform support.
The app in this repo is a Linux GTK/libadwaita target gated behind `src/swift/Package.swift`, and the current UI executable is only a proof shell in `src/swift/Sources/HybridAIMobileChat/main.swift`. Upstream LiteRT-LM Swift support is currently early-preview and aimed at iOS/macOS, not Linux. If the goal is "call LiteRT directly from the current Linux Swift UI app", that is the main architectural blocker. The practical Linux path is a service boundary, with Swift consuming an API client rather than the native LiteRT engine.

2. There is no LLM-serving layer in the repo yet.
The existing Python server is only a health endpoint that returns env metadata in `src/python/hybrid_ai/server.py`. The use-case doc also describes that server as a lightweight JSON responder, not an inference API, in `docs/usecases/02-python-cli-and-server.md`. So "introduce an LLM endpoint" is net-new application work, not an extension of an existing chat service.

3. The current LiteRT-LM integration is bootstrap-only and not production-shaped.
The local inference path is a wrapper that shells out to LiteRT-LM CLI or Python module in `scripts/env/run_inference_local.sh`. The setup script resolves the latest release and installs from GitHub HEAD/tag into the environment in `scripts/env/setup_litert_lm.sh`. That is acceptable for exploration, but weak for a durable endpoint because it leaves version pinning, model import, and server contract undefined.

4. The inference environment does not yet declare a complete runtime contract.
The inference manifest currently only installs curl, jq, and git and activates directory path exports in `env/inference/manifest.toml`. That means model runtime dependencies are being pulled dynamically rather than represented as a first-class repo contract. For a service you will want explicit package ownership, pinned LiteRT-LM versioning, and a defined model bootstrap/import step.

5. The Swift shared layer is not ready to host chat state or transport abstractions.
The shared Swift library only exposes a static status string in `src/swift/Sources/HybridAI/HybridAI.swift`. The existing roadmap already points toward shared app state and platform-specific shells in `docs/chat/swift_ui_cross_platform_roadmap.md`, but that architecture has not been implemented yet. Without that layer, wiring the UI straight to HTTP or inference details will create avoidable churn.

6. Test coverage is currently only baseline smoke coverage.
The Python package only declares numpy and pytest in `src/python/pyproject.toml`, and the Swift tests only cover the trivial status path described in `docs/usecases/03-swift-build-and-test.md`. There is no endpoint contract testing, streaming behavior testing, or model availability verification yet.

## Questions / Assumptions

1. I’m assuming the current Linux GTK app remains the near-term UI target.
2. I’m assuming "expose swift bindings" means "provide a clean Swift client API for the app", not necessarily "embed the LiteRT native engine directly in the Linux app".
3. I’m assuming the endpoint should be OpenAI-compatible unless you want a smaller project-specific API.

## Recommended Direction

Use a two-surface design:

1. Python service surface on Linux for actual LiteRT-LM inference.
2. Shared Swift client surface in the HybridAI package for the UI.
3. Optional Apple-native direct LiteRT-LM Swift integration later for macOS/iOS only.

That keeps the current Linux UI viable and avoids blocking on upstream Swift/Linux support.

## Roadmap

1. Define the contract first.
Choose one of these:
- OpenAI-compatible: `/v1/models`, `/v1/chat/completions`, optional streaming.
- Project-specific: `/health`, `/models`, `/chat`, `/chat/stream`.

My recommendation is OpenAI-compatible for the server boundary, with a thin project-local Swift wrapper around it. Upstream LiteRT-LM CLI already exposes an OpenAI-compatible server path, so this aligns with the underlying engine instead of inventing an incompatible shape.

2. Turn LiteRT-LM bootstrap into a pinned runtime.
Do this in the existing direction already sketched in `docs/chat/devenv_portable_workflow.md`:
- Pin a specific LiteRT-LM release in repo metadata instead of always using latest.
- Define the exact Gemma 4 E4B model artifact and import/bootstrap workflow.
- Add a smoke check that proves model presence and engine startup before the app runs.

3. Build the Python inference service.
Replace the current health-only server in `src/python/hybrid_ai/server.py` with:
- a real web framework, preferably FastAPI
- startup lifecycle that loads or validates Gemma 4 E4B availability
- `/health` and `/ready` endpoints
- chat completion endpoint
- optional streaming via SSE
- structured error mapping for missing model, engine init failure, and backend unsupported

Keep the direct CLI wrapper in `scripts/env/run_inference_local.sh` as a smoke tool, not as the application integration path.

4. Add a model manager layer.
Create a small Python service layer around LiteRT-LM with responsibilities:
- resolve configured model path/name
- initialize engine once
- create per-request conversation/session state
- support prompt templating and system prompts
- expose generation options like temperature, max tokens, backend
- surface timing and token usage if LiteRT-LM exposes them

Do not let HTTP handlers call LiteRT-LM directly.

5. Add a shared Swift client API in the HybridAI module.
Evolve `src/swift/Sources/HybridAI/HybridAI.swift` into something like:
- `HybridAIClient`
- `ChatService`
- `ChatMessage`
- `ChatRequest`
- `ChatResponse`
- `ChatStreamEvent`
- `AppModel` or `ChatViewModel`

That gives you "Swift bindings" for the app immediately, even on Linux, because they bind to your endpoint rather than to the native LiteRT engine.

6. Refactor the Linux UI to consume shared state, not transport details.
Keep the Linux UI proof target in `src/swift/Package.swift`, but move all networking and state management into the shared package. The UI should only:
- render messages
- send prompts
- display loading/streaming/error states
- allow endpoint/model selection if needed

This matches the existing cross-platform UI roadmap in `docs/chat/swift_ui_cross_platform_roadmap.md`.

7. Defer native LiteRT-LM Swift binding work to Apple platforms.
If you later add a macOS or iOS SwiftUI shell, then add the upstream LiteRT-LM Swift package there. Treat that as a second integration mode:
- Linux app: Swift client -> Python LiteRT service
- Apple app: either Swift client -> service, or direct LiteRTLM in-app if you want on-device inference

Do not couple the Linux plan to the Apple-only Swift package.

8. Add verification gates.
Minimum tests I’d add:
- Python unit tests for model config and request translation
- Python API tests for `/health`, `/ready`, `/v1/models`, `/v1/chat/completions`
- one streaming integration test
- Swift unit tests for decoding endpoint responses
- Swift view-model tests for loading, success, and error states
- one end-to-end smoke script: start server, send prompt, verify non-empty response

## Suggested Milestones

1. Milestone A: Stable local inference
Outcome:
- pinned LiteRT-LM version
- pinned Gemma 4 E4B model bootstrap
- CLI smoke command works reproducibly

2. Milestone B: LLM endpoint
Outcome:
- FastAPI service with health, ready, models, chat completion
- manual curl test succeeds
- endpoint contract documented

3. Milestone C: Swift client bindings
Outcome:
- shared Swift client types and service abstraction in the HybridAI module
- Linux UI can submit a prompt and render a full response

4. Milestone D: Streaming chat UX
Outcome:
- SSE or chunked streaming
- incremental token rendering in the GTK app
- cancellation/retry/error handling

5. Milestone E: Apple-native path
Outcome:
- decide whether macOS/iOS use the service client or direct LiteRTLM Swift integration
- only then add the upstream Swift package

## Baseline Status

Current baseline is healthy:
- `swift:test` passes
- `env:doctor` reports OK

So I would not spend time on toolchain repair before starting the endpoint work.

## Recommendation

The most defensible roadmap is:

1. Treat Linux as service-based inference.
2. Treat Swift bindings as a shared client/domain layer first.
3. Add native LiteRT-LM Swift integration only for Apple targets later.

That path fits the repo you have now, fits the current Linux UI target, and avoids betting the project on unsupported Linux Swift bindings upstream.

## macOS/iOS Direct Integration Design

If the project target is macOS or iOS, the first working integration should avoid a Python service and use the upstream LiteRT-LM Swift API directly in-process.

The upstream sample and test flow is:
- resolve a bundled `.litertlm` model file
- resolve a writable cache directory
- construct `EngineConfig`
- create `Engine`
- call `initialize()` off the main thread
- create a `Conversation`
- call `sendMessage(...)` or `sendMessageStream(...)`
- bind generated text back into UI state

That runtime flow is correct for Apple platforms, but the view should not own engine lifecycle directly. The integration layer should preserve the same app-facing abstractions that Linux will use later.

### Design Goals

The integration design should target:
- one runtime engine with many conversations
- Swift API based abstractions first
- minimal surface area
- direct LiteRT-LM Swift usage on macOS/iOS
- a Linux backend path that preserves realistic sandbox and process-boundary behavior

### Recommended Runtime Model

Use one shared Swift core with two runtime adapters:
- `AppleLiteRTRuntime`
- `PythonBackendRuntime`

The app should talk only to shared `HybridAI` abstractions.

Mapping:
- Apple runtime: one LiteRT `Engine`, many LiteRT `Conversation` instances
- Linux runtime: one Python backend process, many backend conversation identifiers

This preserves the same conceptual contract on both platforms:
- one engine/runtime
- many conversations
- one Swift-facing app model

### Why Not Make PythonKit The Main Linux Path

`PythonKit` is acceptable only as an optional debug or experimental adapter. It should not be the primary Linux backend strategy.

Reasons:
- it is not a viable shared path for iOS
- it collapses the process boundary and weakens sandbox realism
- it mixes Swift UI lifecycle, Python interpreter lifecycle, and inference lifecycle in one process
- it avoids testing the same backend startup, transport, and failure boundaries the Linux app should exercise in practice

For Linux, the better default is a separate Python backend process behind a small transport surface such as loopback HTTP or a Unix domain socket.

## Shared Swift Abstractions

The shared Swift core should own:
- domain types
- runtime protocols
- conversation lifecycle
- view model / app model state

It should not depend directly on LiteRT-LM Swift or Python modules.

### Core Protocol Surface

Use a small contract:

```swift
public struct ConversationID: Hashable, Sendable {
	public let rawValue: UUID

	public init(_ rawValue: UUID = UUID()) {
		self.rawValue = rawValue
	}
}

public enum ChatRole: String, Sendable {
	case system
	case user
	case assistant
}

public struct ChatMessage: Identifiable, Sendable {
	public let id: UUID
	public let role: ChatRole
	public var text: String

	public init(id: UUID = UUID(), role: ChatRole, text: String) {
		self.id = id
		self.role = role
		self.text = text
	}
}

public protocol ConversationHandle: Sendable {
	var id: ConversationID { get }
	func send(_ text: String) async throws -> ChatMessage
	func stream(_ text: String) -> AsyncThrowingStream<String, Error>
}

public protocol InferenceRuntime: Sendable {
	func prepare() async throws
	func createConversation(systemPrompt: String?) async throws -> ConversationHandle
	func listConversationIDs() async -> [ConversationID]
	func removeConversation(_ id: ConversationID) async
}
```

This is intentionally minimal. It is enough to represent:
- one engine/runtime with many conversations
- direct local LiteRT inference on Apple platforms
- a Linux backend that manages conversations out of process

### App Model

Use a single shared app model that depends only on `InferenceRuntime`:

```swift
@MainActor
public final class ChatAppModel: ObservableObject {
	@Published public var conversations: [ConversationSummary] = []
	@Published public var selectedConversationID: ConversationID?
	@Published public var transcripts: [ConversationID: [ChatMessage]] = [:]
	@Published public var draft: String = ""
	@Published public var isPreparing: Bool = false
	@Published public var isGenerating: Bool = false
	@Published public var errorText: String?

	private let runtime: InferenceRuntime

	public init(runtime: InferenceRuntime) {
		self.runtime = runtime
	}
}
```

The view model or app model should own:
- startup preparation
- create/select/delete conversation actions
- prompt submission
- streaming accumulation into transcript state

The UI should not know about:
- `EngineConfig`
- LiteRT `Engine`
- LiteRT `Conversation`
- backend request or response payloads

## Platform Adapters

### AppleLiteRTRuntime

Responsibilities:
- own exactly one LiteRT `Engine`
- initialize it once
- create many LiteRT `Conversation` instances from that engine
- track active conversation wrappers by `ConversationID`

Shape:

```swift
public actor AppleLiteRTRuntime: InferenceRuntime {
	private let engineProvider: AppleEngineProvider
	private var engine: Engine?
	private var conversations: [ConversationID: AppleLiteRTConversation] = [:]

	public func prepare() async throws { /* initialize engine once */ }

	public func createConversation(systemPrompt: String?) async throws -> ConversationHandle {
		/* create a fresh LiteRT Conversation and wrap it */
	}

	public func listConversationIDs() async -> [ConversationID] {
		Array(conversations.keys)
	}

	public func removeConversation(_ id: ConversationID) async {
		conversations.removeValue(forKey: id)
	}
}
```

This is the intended Apple runtime interpretation of "one engine with many conversations".

### PythonBackendRuntime

Responsibilities:
- own one backend client / one backend service relationship
- create many backend-managed conversations or sessions
- preserve the same Swift-facing protocol surface as the Apple runtime

Shape:

```swift
public actor PythonBackendRuntime: InferenceRuntime {
	private let client: BackendClient
	private var conversations: [ConversationID: PythonBackendConversation] = [:]

	public func prepare() async throws { /* ensure backend is reachable */ }

	public func createConversation(systemPrompt: String?) async throws -> ConversationHandle {
		/* create a backend conversation and wrap it */
	}

	public func listConversationIDs() async -> [ConversationID] {
		Array(conversations.keys)
	}

	public func removeConversation(_ id: ConversationID) async {
		conversations.removeValue(forKey: id)
	}
}
```

This preserves the same app model while still testing realistic backend constraints on Linux.

## Suggested File Layout

Reshape `src/swift/Sources/HybridAI` toward the following:

```text
src/swift/Sources/HybridAI/
  Core/
	ChatMessage.swift
	ChatRole.swift
	ConversationID.swift
	ConversationHandle.swift
	InferenceRuntime.swift
	RuntimeFactory.swift
  App/
	ChatAppModel.swift
	ConversationSummary.swift
  AppleLiteRT/
	AppleLiteRTRuntime.swift
	AppleLiteRTConversation.swift
	AppleEngineProvider.swift
	BundleModelLocator.swift
  Backend/
	PythonBackendRuntime.swift
	PythonBackendConversation.swift
	BackendClient.swift
	BackendModels.swift
```

Ownership rules:
- `Core/` must remain platform-neutral
- `App/` must depend only on `Core/`
- `AppleLiteRT/` is the only place that should import LiteRT-LM Swift
- `Backend/` is the only place that should know the Linux backend transport details

## Runtime Selection

Runtime selection should happen only at composition time.

Use a small factory:

```swift
public enum RuntimeMode: Sendable {
	case appleLiteRT
	case pythonBackend(baseURL: URL)
}

public protocol RuntimeFactory {
	func makeRuntime(for mode: RuntimeMode) -> InferenceRuntime
}
```

Recommended defaults:
- macOS/iOS: `.appleLiteRT`
- Linux: `.pythonBackend(...)`
- optional debug path on macOS: `.pythonBackend(...)`

## Minimal Linux Backend Contract

The Linux backend should stay conversation-oriented.

Minimal surface:
- `POST /runtime/prepare`
- `POST /conversations`
- `POST /conversations/{id}/messages`
- `DELETE /conversations/{id}`
- `GET /health`

This maps directly to the `InferenceRuntime` and `ConversationHandle` abstractions.

## Linux Build Strategy

Yes, this design can build on Linux if the code is structured correctly.

The requirement is that LiteRT-LM Swift imports stay isolated to Apple-only source files or Apple-only target membership. The shared core must not import LiteRT-LM Swift.

Concretely:
- `Core/` and `App/` should compile on Linux unchanged
- `Backend/` should compile on Linux unchanged
- `AppleLiteRT/` should be excluded from Linux target membership or guarded with conditional compilation

Practical rule:
- Linux build should compile the shared core and Python backend adapter
- macOS/iOS build should compile the shared core and Apple LiteRT adapter

If the package or app target is arranged so Linux tries to compile files that import LiteRT-LM Swift, the Linux build will fail. If the Apple adapter is isolated correctly, the shared abstraction layer will build on Linux.

## Minimal First Implementation Path

For Apple platforms:
1. Add LiteRT-LM Swift dependency to the Apple app target.
2. Bundle one tested `.litertlm` model.
3. Implement `BundleModelLocator`.
4. Implement `AppleLiteRTRuntime` and `AppleLiteRTConversation`.
5. Implement `ChatAppModel`.
6. Bind the Apple UI to the shared model.

For Linux:
1. Implement the Python backend process with the minimal conversation contract.
2. Implement `BackendClient` plus `PythonBackendRuntime`.
3. Bind the Linux UI to the same `ChatAppModel`.

This yields a single Swift-first integration design that works across Apple and Linux without forcing the Linux build to depend on Apple-only LiteRT-LM Swift packaging.