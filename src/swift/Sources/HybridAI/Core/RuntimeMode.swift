import Foundation

public enum RuntimeMode: Sendable, Equatable {
    case appleLiteRT
    case pythonBackend(baseURL: URL)
}

public protocol RuntimeFactory: Sendable {
    func makeRuntime(for mode: RuntimeMode) -> any InferenceRuntime
}