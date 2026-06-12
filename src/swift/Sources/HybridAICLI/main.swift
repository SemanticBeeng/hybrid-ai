import Foundation
import HybridAI

@main
struct HybridAICLIApp {
	static func main() async {
		let client = HybridAI()
		let appModel = client.makePreviewAppModel()

		do {
			let conversationID = try await appModel.bootstrapConversation(title: "CLI Preview")
			let reply = try await appModel.send(
				"Can you confirm the inference abstractions are wired into the CLI?",
				to: conversationID
			)

			print(client.status())
			print("assistant: \(reply.text)")
		} catch {
			FileHandle.standardError.write(Data("error: \(error)\n".utf8))
		}
	}
}
