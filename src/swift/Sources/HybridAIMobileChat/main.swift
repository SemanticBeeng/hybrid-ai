import CHybridAIMobileChat
import Foundation
import Glibc
import HybridAI

@main
struct HybridAIMobileChatApp {
	static func main() async {
		let client = HybridAI()
		let appModel = client.makePreviewAppModel()

		do {
			let overview = try await appModel.createConversation(title: "Overview")
			let selected = try await appModel.createConversation(title: "Selected Chat")

			_ = try await appModel.send(
				"Give me a one-line overview of the app model state.",
				to: overview.id
			)

			let userPrompt = "Can you confirm the Swift app now renders the selected conversation?"
			_ = try await appModel.send(userPrompt, to: selected.id)
			await appModel.selectConversation(selected.id)

			let selectedConversation = await appModel.selectedConversation()
			let summaries = await appModel.conversationSummaries()

			var snapshots: [HybridAIConversationSnapshot] = []
			snapshots.reserveCapacity(summaries.count)
			for summary in summaries {
				let summaryTranscript = try await appModel.transcript(for: summary.id)
				let assistantIntro = summaryTranscript.first?.text ?? "Hybrid AI runtime ready."
				let userMessage = summaryTranscript.dropFirst().first(where: { $0.role == .user })?.text ?? "No user message yet."
				let assistantReply = summaryTranscript.last?.text ?? client.status()

				guard
					let titleCString = strdup(summary.title),
					let assistantIntroCString = strdup(assistantIntro),
					let userMessageCString = strdup(userMessage),
					let assistantReplyCString = strdup(assistantReply)
				else {
					throw NSError(domain: "HybridAI", code: 1)
				}

				snapshots.append(HybridAIConversationSnapshot(
					title: UnsafePointer(titleCString),
					assistant_intro: UnsafePointer(assistantIntroCString),
					user_message: UnsafePointer(userMessageCString),
					assistant_reply: UnsafePointer(assistantReplyCString)
				))
			}
			defer {
				for snapshot in snapshots {
					free(UnsafeMutableRawPointer(mutating: snapshot.title))
					free(UnsafeMutableRawPointer(mutating: snapshot.assistant_intro))
					free(UnsafeMutableRawPointer(mutating: snapshot.user_message))
					free(UnsafeMutableRawPointer(mutating: snapshot.assistant_reply))
				}
			}

			let selectedIndex = summaries.firstIndex { $0.id == selectedConversation?.id } ?? 0

			print("Launching Hybrid AI mobile chat proof: \(client.status())")
			"Hybrid AI".withCString { titleCString in
				"Selected".withCString { subtitleCString in
					snapshots.withUnsafeBufferPointer { snapshotBuffer in
						hybrid_ai_mobile_chat_run_with_conversations(
							titleCString,
							subtitleCString,
							snapshotBuffer.baseAddress,
							Int32(snapshotBuffer.count),
							Int32(selectedIndex)
						)
					}
				}
			}
		} catch {
			FileHandle.standardError.write(Data("error: \(error)\n".utf8))
		}
	}
}
