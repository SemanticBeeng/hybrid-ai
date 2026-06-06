#ifndef HYBRID_AI_MOBILE_CHAT_H
#define HYBRID_AI_MOBILE_CHAT_H

void hybrid_ai_mobile_chat_run(void);
void hybrid_ai_mobile_chat_run_with_messages(
	const char *title,
	const char *subtitle,
	const char *assistant_intro,
	const char *user_message,
	const char *assistant_reply
);

#endif
