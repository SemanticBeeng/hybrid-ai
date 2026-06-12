public struct HybridAI {
    public init() {}

    public func status() -> String {
        "hybrid-ai swift module ready"
    }

    public func makePreviewAppModel() -> ChatAppModel {
        ChatAppModel(runtime: PreviewInferenceRuntime())
    }
}
