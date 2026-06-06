import CHybridAIMobileChat
import Foundation
import HybridAI

@main
struct HybridAIMobileChatApp {
	static func main() async {
		let client = HybridAI()
		let appModel = client.makePreviewAppModel()

		do {
			let conversationID = try await appModel.bootstrapConversation(title: "GTK Preview")
			let userPrompt = "Can you confirm the Swift app uses the inference abstractions now?"
			_ = try await appModel.send(userPrompt, to: conversationID)
			let transcript = try await appModel.transcript(for: conversationID)

			let assistantIntro = transcript.first?.text ?? "Hybrid AI runtime ready."
			let assistantReply = transcript.last?.text ?? client.status()

			print("Launching Hybrid AI mobile chat proof: \(client.status())")
			userPrompt.withCString { userPromptCString in
				assistantIntro.withCString { assistantIntroCString in
					assistantReply.withCString { assistantReplyCString in
						"Hybrid AI".withCString { titleCString in
							"Mobile chat prototype · Swift + shared inference abstractions".withCString { subtitleCString in
								hybrid_ai_mobile_chat_run_with_messages(
									titleCString,
									subtitleCString,
									assistantIntroCString,
									userPromptCString,
									assistantReplyCString
								)
							}
						}
					}
				}
			}
		} catch {
			FileHandle.standardError.write(Data("error: \(error)\n".utf8))
		}
	}
}
