import Foundation
import Testing
@testable import HybridAI
@testable import HybridAIBackend

@Test func backendFactoryCanCreatePythonBackendRuntime() {
    let baseURL = URL(string: "http://127.0.0.1:8080")!
    let backend = HybridAIBackend()

    let runtime = backend.makeRuntime(for: .pythonBackend(baseURL: baseURL))

    #expect(type(of: runtime) == BackendInferenceRuntime.self)
}