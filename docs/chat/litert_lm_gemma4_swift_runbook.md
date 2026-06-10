## LiteRT-LM Gemma 4 E4B Endpoint And Swift Integration Runbook

Date: 2026-06-05
Status: Review and implementation roadmap
Scope: Introduce an LLM endpoint using Google LiteRT-LM, serve Gemma 4 E4B through it, expose Swift bindings, and call it from the Swift UI app.

## Current State Update

This runbook began as a roadmap before the current Python backend and Linux GPU
workflow existed. The following pieces are now implemented in the repository:

- the Python backend exposes live readiness, health, conversation create/delete,
	and message-send endpoints
- the Linux GPU path is promoted for the current supported host class:
	- Linux
	- NVIDIA driver stack
	- Vulkan ICD discovery
	- repo-managed Python runtime in `env/python`
- the repo-level smoke entrypoint is now:
	- `scripts/env/run_inference_local_gpu_smoke.sh`
- the promoted Linux GPU path returns normalized plain assistant text rather
	than stringified structured LiteRT payloads
- Swift live backend integration tests now assert that assistant text is
	normalized at the client boundary

This means the sections below should be read as architectural background and
future direction, not as a statement that the repository still lacks an LLM
serving surface.

## Target Deployment Model

Related domain docs:
- [[01-br-sandboxed-on-device-inference-target]]
- [[03-br-apple-deployment-authority]]
- [[04-br-linux-sandbox-approximation-requirements]]
- [[05-apple-validation-ladder]]

The primary product target is a real iOS application where:
- the app runs inside the iOS application sandbox
- the inference engine runs under the same app sandbox constraints
- the bundled or provisioned LLM assets must obey iOS storage, memory, and runtime restrictions
- the final user experience is constrained by actual iPhone or iPad hardware characteristics

This means the architecture should be designed first for the constraints of on-device Apple deployment, not for unconstrained desktop Linux development.

### Apple-Side Approximation Strategy

There are two Apple-side deployment modes to reason about:

1. iOS on real iPhone or iPad hardware
	- this is the canonical target
	- sandbox, memory pressure, thermal behavior, and accelerator availability are authoritative here

2. macOS via Mac Catalyst
	- this is an approximation of iOS deployment, not the final truth
	- it is useful for validating app structure, entitlement shape, sandbox assumptions, bundle/resource handling, and native Swift/LiteRT integration patterns
	- it is not a substitute for final validation on iPhone hardware because memory ceilings, thermal limits, GPU architecture, and runtime scheduling differ materially

The correct interpretation is:
- iOS hardware is the real target
- Mac Catalyst is the closest Apple-hosted approximation for development and deployment rehearsal

### Linux Approximation Strategy

Linux is the current development focus, but it must be treated as an approximation environment with explicit compensating constraints.

When building and deploying on Linux, the project should preserve awareness that:
- Linux is not the final deployment sandbox model
- the current machine GPU is not the same architecture as Apple mobile GPU or Apple Silicon neural/graphics execution paths
- Linux may provide more filesystem freedom, process freedom, and observability than the eventual iOS deployment

Therefore Linux work should deliberately approximate two things:

1. the target hardware envelope
2. the target sandbox and runtime isolation model

### GPU Approximation Principles On Linux

The Linux GPU should not be treated as a direct stand-in for iPhone hardware. It is only useful as an approximation if work is evaluated through constraints that resemble the target device.

Reason about the Linux GPU using these questions:
- does the model fit within a memory budget that is plausibly portable to the intended iPhone-class hardware?
- what is the end-to-end startup latency relative to a user-acceptable mobile launch path?
- what is the steady-state token generation speed under mobile-like concurrency expectations?
- what happens under constrained cache locations and limited writable space?
- what happens when initialization or inference is retried, cancelled, or restarted under resource pressure?

Practical guidance:
- prioritize bounded memory behavior over peak desktop throughput
- prefer one-runtime-many-conversations designs that can be reasoned about under mobile limits
- avoid designing around assumptions that depend on abundant desktop VRAM, unconstrained swap, or unrestricted background processing
- capture startup cost, model load cost, and cache footprint as first-class metrics because those often matter more than raw desktop benchmark speed

The Linux GPU is useful for proving viability and relative performance shape, but not for claiming equivalence with Apple mobile hardware.

### Sandbox Approximation Principles On Linux

When building on Linux, the project should deliberately approximate iOS-style confinement by design and tooling discipline.

The goal is not perfect emulation of iOS sandbox internals. The goal is to preserve the important architectural consequences of sandboxing:
- constrained writable locations
- explicit ownership of models, caches, and logs
- no reliance on host-global mutable state
- no assumption that arbitrary sibling processes or user-global resources are available
- clear process boundaries between app and backend where those boundaries matter for the target design

For this repository, Linux sandbox approximation should mean:
- keep writable runtime state under repository-controlled roots such as `build/`, `volumes/`, `.flox/`, and other approved project-local paths
- avoid host-global cache and config leakage
- keep model bootstrap, cache population, and logs explicit and inspectable
- prefer backend process boundaries over in-process interpreter shortcuts when validating the Linux path meant to approximate a sandboxed deployment architecture
- treat transport, startup, and runtime lifecycle as part of the product design, not just local development convenience

### Design Consequence

The project should be evaluated against this deployment ladder:

1. iOS on device is the true target
2. Mac Catalyst is the closest Apple-side approximation
3. Linux is a deliberate approximation environment for rapid development, backend validation, and sandbox rehearsal

That means Linux implementation choices should be judged partly by how well they preserve a path to:
- sandbox-compatible resource ownership
- mobile-realistic runtime limits
- eventual direct LiteRT-LM integration on Apple platforms

This also reinforces the current architectural preference:
- shared Swift abstractions across platforms
- Apple-native inference integration where supported
- Linux backend/service integration designed in a way that still respects the eventual sandboxed deployment goals

## Findings

The items below began as a baseline review before the current backend and GPU
workflow were implemented. Where the repository has moved forward, the finding
now preserves the earlier gap plus the current state.

1. The current Swift UI target and the upstream LiteRT-LM Swift bindings do not line up on platform support.
The app in this repo is a Linux GTK/libadwaita target gated behind `src/swift/Package.swift`, and the current UI executable is only a proof shell in `src/swift/Sources/HybridAIMobileChat/main.swift`. Upstream LiteRT-LM Swift support is currently early-preview and aimed at iOS/macOS, not Linux. If the goal is "call LiteRT directly from the current Linux Swift UI app", that is the main architectural blocker. The practical Linux path is a service boundary, with Swift consuming an API client rather than the native LiteRT engine.

2. Historical gap: there was no LLM-serving layer in the repo yet.
At the time of the original review, the Python server was only a health-oriented endpoint and "introduce an LLM endpoint" was net-new application work. Current state is different: the Python backend now exposes readiness, health, conversation create/delete, and blocking message-send endpoints, and the live Linux GPU path is verified through the promoted smoke workflow in `scripts/env/run_inference_local_gpu_smoke.sh`.

3. Historical gap: the LiteRT-LM integration was bootstrap-only and not production-shaped.
The original concern was that local inference still looked like exploration, with weak pinning and no stable server contract. Current state is stronger: the repo now has pinned runtime metadata, pinned model bootstrap workflow, a promoted Linux GPU serve path for the supported host class, and a repo-level smoke command that verifies end-to-end serving semantics.

4. The inference environment does not yet declare a complete runtime contract.
The inference manifest currently only installs curl, jq, and git and activates directory path exports in `env/inference/manifest.toml`. That means model runtime dependencies are being pulled dynamically rather than represented as a first-class repo contract. For a service you will want explicit package ownership, pinned LiteRT-LM versioning, and a defined model bootstrap/import step.

5. The Swift shared layer is not ready to host chat state or transport abstractions.
The shared Swift library only exposes a static status string in `src/swift/Sources/HybridAI/HybridAI.swift`. The existing roadmap already points toward shared app state and platform-specific shells in [[swift_ui_cross_platform_roadmap]], but that architecture has not been implemented yet. Without that layer, wiring the UI straight to HTTP or inference details will create avoidable churn.

6. Historical gap: test coverage was only baseline smoke coverage.
At the time of the original review, the repo did not yet have endpoint contract tests or live backend integration checks. Current state now includes Python backend tests, Swift backend transport tests, and live Swift integration tests that verify normalized assistant text across the backend client boundary.

## Questions / Assumptions

1. I’m assuming the current Linux GTK app remains the near-term UI target.
2. I’m assuming "expose swift bindings" means "provide a clean Swift client API for the app", not necessarily "embed the LiteRT native engine directly in the Linux app".
3. I’m assuming the endpoint should be OpenAI-compatible unless you want a smaller project-specific API.

## Recommended Direction

Related domain docs:
- [[03-dd-runtime-adapter-pattern]]
- [[04-dd-backend-transport-and-error-boundary]]
- [[06-br-shared-swift-core-portability-requirements]]

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
Do this in the repository setup direction captured in [[09-dd-model-bootstrap-and-runtime-pinning]]:
- Pin a specific LiteRT-LM release in repo metadata instead of always using latest.
- Define the exact Gemma 4 E4B model artifact and import/bootstrap workflow.
- Add a smoke check that proves model presence and engine startup before the app runs.

3. Continue evolving the Python inference service.
The repository already has a real backend surface in `src/inference_srv_py/inference_srv_py/server.py`; the remaining work is to evolve it further with:
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

This matches the existing cross-platform UI roadmap in [[swift_ui_cross_platform_roadmap]].

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

Related domain docs:
- [[03-dd-runtime-adapter-pattern]]
- [[05-dd-runtime-lifecycle-and-conversation-ownership]]
- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

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

Related domain docs:
- [[05-br-conversation-oriented-inference-experience]]
- [[06-br-shared-swift-core-portability-requirements]]
- [[03-dd-runtime-adapter-pattern]]

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

Related domain docs:
- [[07-dd-backend-conversation-contract]]
- [[04-dd-backend-transport-and-error-boundary]]

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

## Python Backend Roadmap

Related domain docs:
- [[01-litert-lm-gemma4-spike-and-delivery-roadmap]]
- [[03-python-backend-layered-delivery-plan]]
- [[07-dd-backend-conversation-contract]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

Build the Python backend in two layers:

1. an internal Python runtime layer that matches the Swift mental model
2. an HTTP API layer that exposes that runtime cleanly to Swift

That keeps the backend implementation honest and makes the transport replaceable later.

The Swift side already gives the contract to target in:
- `src/swift/Sources/HybridAI/Core/InferenceRuntime.swift`
- `src/swift/Sources/HybridAI/Core/ConversationHandle.swift`

The Swift runtime contract tests should become the acceptance target for the Python-backed runtime:
- `src/swift/Tests/HybridAITests/InferenceRuntimeContractTests.swift`

### Phase 1: Freeze the Backend Contract

Define the Python-side semantic model before choosing framework details.

Mirror the Swift model:
- one backend runtime process
- many conversations
- each conversation has an id
- `prepare()` initializes runtime/model state
- `createConversation(systemPrompt:)` creates a new conversation
- `send(text)` returns one assistant message
- `stream(text)` yields incremental text chunks
- `removeConversation(id)` deletes backend state
- `listConversationIDs()` reports current live conversation ids

Suggested internal Python interface shape:

```python
class ConversationHandle(Protocol):
		id: str
		async def send(self, text: str) -> ChatMessage: ...
		async def stream(self, text: str) -> AsyncIterator[str]: ...

class InferenceRuntime(Protocol):
		async def prepare(self) -> None: ...
		async def create_conversation(self, system_prompt: str | None) -> ConversationHandle: ...
		async def list_conversation_ids(self) -> list[str]: ...
		async def remove_conversation(self, conversation_id: str) -> None: ...
```

Do not start with HTTP handlers calling LiteRT directly.

### Phase 2: Add a Python Domain/Runtime Package

Create a backend package under the Python source tree that isolates runtime behavior from web concerns.

Suggested modules:
- `runtime/models.py`
- `runtime/protocols.py`
- `runtime/errors.py`
- `runtime/conversations.py`
- `runtime/litert_runtime.py`
- `runtime/store.py`

Responsibilities:
- `models.py`: request/domain objects like `ChatMessage`, `ConversationState`
- `protocols.py`: Python runtime interfaces
- `errors.py`: typed failures
- `store.py`: in-memory conversation registry
- `litert_runtime.py`: LiteRT-LM-backed implementation
- `conversations.py`: per-conversation logic

This separation is important. Without it, the backend will harden around FastAPI handler shape instead of the runtime contract.

### Phase 3: Build a Fake Runtime First

Before touching LiteRT-LM, build a Python preview or fake runtime that behaves like the Swift `PreviewInferenceRuntime`.

Why:
- proves the backend API shape
- lets the Swift backend client implementation start earlier
- gives stable tests before model/bootstrap complexity enters

This fake runtime should satisfy the same semantic contract:
- create conversation ids
- remember per-conversation state
- support send/stream
- delete conversations cleanly

### Phase 4: Expose HTTP API Matching the Swift Protocol

Related domain docs:
- [[07-dd-backend-conversation-contract]]
- [[08-dd-streaming-chat-semantics]]

Use FastAPI for the transport layer.

Recommended endpoints:
1. `POST /runtime/prepare`
2. `GET /runtime/conversations`
3. `POST /runtime/conversations`
4. `DELETE /runtime/conversations/{id}`
5. `POST /runtime/conversations/{id}/messages`
6. `POST /runtime/conversations/{id}/messages/stream`

Minimal request/response mapping:

- `POST /runtime/conversations`
	- request: `{ "system_prompt": "..." }`
	- response: `{ "id": "..." }`

- `GET /runtime/conversations`
	- response: `{ "ids": ["...", "..."] }`

- `POST /runtime/conversations/{id}/messages`
	- request: `{ "text": "..." }`
	- response: `{ "role": "assistant", "text": "..." }`

- `POST /runtime/conversations/{id}/messages/stream`
	- request: `{ "text": "..." }`
	- response: streamed chunks

This maps cleanly to the Swift protocol without inventing extra app semantics too early.

### Phase 5: Implement the Real LiteRT Runtime

After the fake runtime and HTTP layer are stable, replace the fake implementation with a real LiteRT-backed runtime.

Responsibilities of the real runtime:
- perform `prepare()` once
- resolve model path and backend config
- own one engine/runtime instance for the process
- create conversation/session objects per conversation id
- keep conversation registry in memory
- translate backend responses into a stable backend message model

This is where the existing repo inference work should be incorporated:
- `scripts/env/run_inference_local.sh`
- `scripts/env/setup_litert_lm.sh`
- this runbook

### Phase 6: Build the Swift Backend Adapter

Once HTTP is live, implement the Swift `HybridAIBackend` target as a transport-backed runtime.

That module should contain:
- `BackendClient`
- `PythonBackendRuntime`
- `PythonBackendConversation`
- transport request/response DTOs

Its job is to satisfy:
- `src/swift/Sources/HybridAI/Core/InferenceRuntime.swift`
- `src/swift/Sources/HybridAI/Core/ConversationHandle.swift`

by translating Swift calls into HTTP calls.

### Phase 7: Use the Contract Test as the Driver

The preview runtime already passes the Swift runtime contract. The Python backend runtime should pass the same tests.

Once `PythonBackendRuntime` exists, add the same contract harness against it in:
- `src/swift/Tests/HybridAITests/InferenceRuntimeContractTests.swift`

That turns the contract into the design driver, not just documentation.

## Key Decisions

Related domain docs:
- [[04-dd-backend-transport-and-error-boundary]]
- [[05-dd-runtime-lifecycle-and-conversation-ownership]]
- [[08-dd-streaming-chat-semantics]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]
- [[10-dd-backend-error-semantics]]

### 1. Transport Choice

Choose `HTTP + JSON` first.

Recommendation:
- normal request/response: JSON over HTTP
- streaming: SSE or chunked text stream

Why:
- easiest to inspect and debug
- easiest to run locally
- easiest to exercise from curl and tests
- compatible with future non-Swift clients

Do not start with:
- PythonKit
- gRPC
- Unix sockets only
- custom binary protocol

### 2. Runtime Ownership Model

Choose:
- one backend runtime process
- one prepared model/engine per process
- many in-memory conversations

This matches the Swift design already in the runbook and code.

Do not start with:
- one process per conversation
- one model load per request
- stateless message-only API

### 3. Conversation Identity

Use backend-generated opaque ids, likely UUID strings.

Keep them transport-safe and independent of LiteRT internals.

Do not encode model/backend details into ids.

### 4. State Persistence

Start with in-memory conversation state only.

That is enough to prove:
- one runtime, many conversations
- transcript isolation
- lifecycle semantics

Do not start with database persistence unless the product needs restore/history immediately.

### 5. Streaming Format

Pick one and commit early.

Recommendation:
- SSE for streamed token/text events

Possible event types:
- `chunk`
- `done`
- `error`

Why SSE:
- easy from FastAPI
- easy from Swift URLSession streams
- easy to inspect

### 6. Error Model

Define a stable backend error envelope before LiteRT integration.

Example categories:
- `runtime_not_prepared`
- `conversation_not_found`
- `model_not_found`
- `engine_init_failed`
- `inference_failed`
- `invalid_request`

Keep transport status codes conventional:
- `400` invalid input
- `404` conversation missing
- `409` runtime state conflict
- `500` backend/runtime failure
- `503` model/runtime unavailable

Swift backend adapter should translate these into Swift errors later.

### 7. Prepare Semantics

Decide whether `prepare()` is:
- explicit and required
or
- implicit on first use

Recommendation:
- support explicit `POST /runtime/prepare`
- allow runtime to lazily prepare on first create/send if not prepared

### 8. System Prompt Semantics

Recommendation:
- fix system prompt at conversation creation for now

That maps directly to `createConversation(systemPrompt:)` and keeps state reasoning clean.

### 9. Message Model

Keep the backend message payload minimal initially:

```json
{
	"role": "assistant",
	"text": "..."
}
```

Do not add tool calls, token accounting, multimodal fields, or metadata unless the first real LiteRT integration demands them.

### 10. Testing Strategy

Split tests into three layers.

1. Python runtime unit tests
	 - fake runtime
	 - conversation registry
	 - state deletion
	 - send/stream semantics

2. Python API tests
	 - endpoint behavior
	 - status codes
	 - streaming behavior
	 - error mapping

3. Swift contract tests
	 - backend adapter satisfies `InferenceRuntime`
	 - same contract as preview runtime

Swift should not be the first line of backend debugging.

## Suggested Implementation Order

1. Write Python backend domain models and protocols.
2. Implement fake Python runtime.
3. Expose FastAPI endpoints over the fake runtime.
4. Add Python tests for lifecycle/send/stream.
5. Implement Swift `BackendClient`.
6. Implement Swift `PythonBackendRuntime`.
7. Point Swift contract tests at backend runtime.
8. Replace fake runtime with real LiteRT runtime.
9. Add LiteRT bootstrap/model wiring.
10. Add streaming and richer errors if needed.

This sequence reduces risk because the transport and protocol settle before LiteRT complexity enters.

## Most Important Choices To Settle Now

1. HTTP + JSON + SSE, not PythonKit.
2. One process runtime, many in-memory conversations.
3. Explicit backend-generated conversation ids.
4. Fixed system prompt at conversation creation.
5. Fake runtime first, real LiteRT second.
6. Swift contract test as the adapter acceptance gate.

These six decisions determine most of the architecture.

## Recommended Next Step

The best next implementation step is:

1. create the Python fake runtime and FastAPI surface
2. keep it strictly aligned to the Swift protocol
3. then implement `PythonBackendRuntime` in Swift against that fake service

That will give a stable integration seam before LiteRT model loading is introduced.

## Real-Runtime-First Spike Plan

Related domain docs:
- [[04-litert-runtime-viability-spike-plan]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]

It is also valid to take a narrower shortcut and start from the later roadmap steps:

1. replace the fake runtime with a real LiteRT runtime
2. add LiteRT bootstrap and model wiring

This can produce a basic working version faster, but it must be treated as a spike rather than the canonical implementation sequence.

The correct framing is:
- use the spike to reduce real technical uncertainty
- do not let the spike define the long-term backend architecture by accident

### When This Shortcut Is Justified

Use the real-runtime-first spike if the dominant uncertainties are:
- whether LiteRT can load the chosen model at all in this environment
- whether Gemma 4 E4B starts successfully with acceptable startup cost
- whether the repo environment and isolation rules can host the runtime cleanly
- whether a minimal end-to-end inference path can be proven quickly

This shortcut is less useful if the main uncertainty is protocol shape, Swift adapter semantics, or transport design. In those cases, fake-runtime-first remains the better sequencing.

### What The Spike Should Deliver

The spike goal is deliberately narrow:
- prove the Python LiteRT engine can initialize
- prove one conversation can be created
- prove one prompt can return one assistant response
- expose one thin endpoint to Swift
- call it once from the Swift backend adapter or app path

That is enough to validate the runtime and deployment assumptions without prematurely expanding the surface area.

### Guardrails

Even in the spike, keep these boundaries intact:

1. Define a Python runtime class boundary first.
	- LiteRT code should live behind one runtime class.
	- FastAPI handlers must not own engine lifecycle directly.

2. Keep the HTTP API protocol-shaped.
	- Do not design the API around LiteRT-specific quirks.
	- Keep request and response payloads aligned with the Swift abstraction surface.

3. Keep conversation identity backend-generated and opaque.
	- Use UUID-like ids.
	- Do not encode model or runtime details into ids.

4. Keep the response model minimal.

```json
{
  "role": "assistant",
  "text": "..."
}
```

5. Keep the implementation in-memory.
	- no persistence yet
	- no restore/history layer yet
	- no multi-process runtime design yet

6. Keep the Swift acceptance gate.
	- the backend-backed Swift adapter should ultimately satisfy the same runtime contract tests used by the preview runtime

If these boundaries are not preserved, the shortcut becomes architectural drift rather than a spike.

### Minimal Spike Scope

If speed is the priority, implement only this:

Python side:
1. model/bootstrap wiring
2. real LiteRT runtime class
3. in-memory conversation registry
4. blocking send path only
5. minimal endpoints:
	- `POST /runtime/prepare`
	- `POST /runtime/conversations`
	- `POST /runtime/conversations/{id}/messages`
	- `GET /health`

Swift side:
1. minimal `BackendClient`
2. minimal `PythonBackendRuntime`
3. minimal `PythonBackendConversation`
4. one call path for:
	- `prepare()`
	- `createConversation(systemPrompt:)`
	- `send(_:)`

Skip for the first spike:
- streaming
- SSE
- richer errors beyond basic categories
- persistence
- multimodal payloads
- tool calling
- UI polish

### Benefits Of Starting Here

The main benefits are:
- earlier proof that LiteRT really works under the project constraints
- earlier visibility into model size, startup time, cache location, and runtime failures
- faster confirmation that the selected Gemma variant is viable
- faster identification of repo-specific environment and dependency issues

This is valuable because fake runtimes cannot expose model initialization risk, backend loading latency, or real inference failures.

### Costs And Risks

The costs are architectural rather than functional.

Risks:
- the API shape may bend around LiteRT behavior instead of the Swift abstraction
- handlers may start calling runtime internals directly
- error handling may become ad hoc
- Swift transport code may become coupled to temporary backend quirks
- later refactoring cost may exceed the time saved by the shortcut

That is why the spike needs explicit stop conditions and a planned return to the main roadmap.

### Suggested Spike Order

If using the shortcut, take this order:

1. add LiteRT bootstrap and model wiring
2. implement a real `LiteRTInferenceRuntime` class in Python
3. add one blocking message endpoint
4. add a minimal Swift backend adapter
5. validate the adapter against the Swift runtime contract where practical

After first success:
6. refactor any handler-owned runtime logic back behind the runtime boundary
7. stabilize the request and response models
8. resume the fuller roadmap from the fake/runtime/API discipline if needed
9. add streaming
10. add richer errors and operational hardening

### Stop Conditions For The Spike

End the spike once these are true:
- the runtime can prepare successfully
- one backend conversation can be created
- one prompt can return one assistant reply
- one Swift path can reach that reply through the backend adapter
- the backend state and API shape are still simple enough to refactor cleanly

Do not keep expanding the spike into the final architecture without pausing to realign it with the main runtime/interface plan.

### Re-Entry Into The Main Roadmap

After the spike, the project should deliberately return to the disciplined roadmap.

Recommended re-entry steps:
1. freeze the minimal protocol and payload shapes actually used by the spike
2. move any LiteRT-specific logic out of FastAPI handlers and into the runtime layer
3. add contract-driven Swift tests against the backend adapter
4. add Python unit tests around the runtime and conversation registry
5. only then expand into streaming, richer errors, and more UI integration

### Recommended Interpretation

The real-runtime-first spike is a tactical shortcut, not a replacement for the main roadmap.

Use it when:
- runtime viability is the most important unanswered question

Do not use it as the default if:
- API stability and maintainable transport layering matter more than immediate runtime proof

### Recommended Next Step Under This Context

If choosing the spike path, the best immediate next step is:

1. implement LiteRT bootstrap/model resolution in Python
2. implement a real Python `LiteRTInferenceRuntime`
3. expose the smallest blocking HTTP surface that matches the Swift protocol shape
4. then build a minimal `PythonBackendRuntime` adapter in Swift against it

That yields a real end-to-end proof quickly while still preserving a path back to the proper layered architecture.