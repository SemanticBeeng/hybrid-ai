#ifndef HYBRID_AI_MOBILE_CHAT_H
#define HYBRID_AI_MOBILE_CHAT_H

typedef struct {
	const char *title;
	const char *assistant_intro;
	const char *user_message;
	const char *assistant_reply;
} HybridAIConversationSnapshot;

void hybrid_ai_mobile_chat_run(void);
void hybrid_ai_mobile_chat_run_with_messages(
	const char *title,
	const char *subtitle,
	const char *conversation_list,
	const char *assistant_intro,
	const char *user_message,
	const char *assistant_reply
);
void hybrid_ai_mobile_chat_run_with_conversations(
	const char *title,
	const char *subtitle_prefix,
	const HybridAIConversationSnapshot *conversations,
	int conversation_count,
	int selected_index
);

#endif
