#include "HybridAIMobileChat.h"

#include <adwaita.h>
#include <gtk/gtk.h>

typedef struct {
    char *title;
    char *assistant_intro;
    char *user_message;
    char *assistant_reply;
} HybridAIConversationSnapshotOwned;

typedef struct {
    char *title;
    char *subtitle_prefix;
    HybridAIConversationSnapshotOwned *conversations;
    int conversation_count;
    int selected_index;
    GtkWidget *subtitle_label;
    GtkWidget *messages_box;
    GtkWidget **conversation_buttons;
    GtkWidget *composer_entry;
} HybridAIChatContent;

static void add_css(void) {
    GtkCssProvider *provider = gtk_css_provider_new();
    const char *css =
        "window { background: #0f172a; }"
        ".app-shell { background: #0f172a; }"
        ".title { color: #f8fafc; font-weight: 800; font-size: 22px; }"
        ".subtitle { color: #94a3b8; font-size: 12px; }"
        ".conversation-strip { background: #111827; border-radius: 18px; padding: 10px 12px; }"
        ".conversation-caption { color: #94a3b8; font-size: 11px; font-weight: 700; letter-spacing: 0.08em; }"
        ".conversation-list { color: #e2e8f0; font-size: 13px; }"
        ".conversation-chip { background: #1f2937; color: #cbd5e1; border-radius: 999px; padding: 8px 12px; border: 0; }"
        ".conversation-chip-active { background: #2563eb; color: #ffffff; }"
        ".chat-list { background: #0f172a; }"
        ".bubble { border-radius: 22px; padding: 12px 14px; font-size: 15px; line-height: 1.35; }"
        ".assistant-bubble { background: #1e293b; color: #f8fafc; }"
        ".user-bubble { background: #2563eb; color: #ffffff; }"
        ".composer { background: #111827; border-radius: 28px; padding: 8px; }"
        ".composer entry { background: transparent; color: #f8fafc; border: 0; box-shadow: none; }"
        ".send-button { border-radius: 22px; font-weight: 700; padding: 10px 16px; }";

    gtk_css_provider_load_from_string(provider, css);

    GdkDisplay *display = gdk_display_get_default();
    if (display != NULL) {
        gtk_style_context_add_provider_for_display(
            display,
            GTK_STYLE_PROVIDER(provider),
            GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    g_object_unref(provider);
}

static GtkWidget *label_with_class(const char *text, const char *css_class) {
    GtkWidget *label = gtk_label_new(text);
    gtk_label_set_wrap(GTK_LABEL(label), TRUE);
    gtk_label_set_wrap_mode(GTK_LABEL(label), PANGO_WRAP_WORD_CHAR);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    gtk_widget_add_css_class(label, css_class);
    return label;
}

static GtkWidget *chat_bubble(const char *text, gboolean from_user) {
    GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkWidget *bubble = label_with_class(text, from_user ? "user-bubble" : "assistant-bubble");

    gtk_widget_add_css_class(bubble, "bubble");
    gtk_widget_set_hexpand(bubble, FALSE);
    gtk_widget_set_size_request(bubble, 260, -1);

    if (from_user) {
        GtkWidget *spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
        gtk_widget_set_hexpand(spacer, TRUE);
        gtk_box_append(GTK_BOX(row), spacer);
        gtk_box_append(GTK_BOX(row), bubble);
    } else {
        gtk_box_append(GTK_BOX(row), bubble);
        GtkWidget *spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
        gtk_widget_set_hexpand(spacer, TRUE);
        gtk_box_append(GTK_BOX(row), spacer);
    }

    return row;
}

static void render_selected_conversation(HybridAIChatContent *content) {
    while (TRUE) {
        GtkWidget *child = gtk_widget_get_first_child(content->messages_box);
        if (child == NULL) {
            break;
        }
        gtk_box_remove(GTK_BOX(content->messages_box), child);
    }

    HybridAIConversationSnapshotOwned *selected = &content->conversations[content->selected_index];
    gtk_box_append(GTK_BOX(content->messages_box), chat_bubble(selected->assistant_intro, FALSE));
    gtk_box_append(GTK_BOX(content->messages_box), chat_bubble(selected->user_message, TRUE));
    gtk_box_append(GTK_BOX(content->messages_box), chat_bubble(selected->assistant_reply, FALSE));

    for (int index = 0; index < content->conversation_count; ++index) {
        GtkWidget *button = content->conversation_buttons[index];
        if (index == content->selected_index) {
            gtk_widget_add_css_class(button, "conversation-chip-active");
        } else {
            gtk_widget_remove_css_class(button, "conversation-chip-active");
        }
    }

    char *subtitle = g_strdup_printf("%s: %s", content->subtitle_prefix, selected->title);
    gtk_label_set_text(GTK_LABEL(content->subtitle_label), subtitle);
    g_free(subtitle);
}

static char *make_preview_reply(const HybridAIConversationSnapshotOwned *selected, const char *prompt) {
    return g_strdup_printf(
        "Preview runtime reply in %s: %s. This GTK shell is updating the selected conversation in memory.",
        selected->title,
        prompt
    );
}

static void send_composer_message(HybridAIChatContent *content) {
    const char *raw_text = gtk_editable_get_text(GTK_EDITABLE(content->composer_entry));
    if (raw_text == NULL) {
        return;
    }

    char *normalized = g_strdup(raw_text);
    g_strstrip(normalized);
    if (normalized[0] == '\0') {
        g_free(normalized);
        return;
    }

    HybridAIConversationSnapshotOwned *selected = &content->conversations[content->selected_index];
    char *reply = make_preview_reply(selected, normalized);

    g_free(selected->user_message);
    g_free(selected->assistant_reply);
    selected->user_message = normalized;
    selected->assistant_reply = reply;

    gtk_editable_set_text(GTK_EDITABLE(content->composer_entry), "");
    render_selected_conversation(content);
}

static void on_send_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    HybridAIChatContent *content = (HybridAIChatContent *)user_data;
    send_composer_message(content);
}

static void on_entry_activated(GtkEntry *entry, gpointer user_data) {
    (void)entry;
    HybridAIChatContent *content = (HybridAIChatContent *)user_data;
    send_composer_message(content);
}

static void on_conversation_clicked(GtkButton *button, gpointer user_data) {
    HybridAIChatContent *content = (HybridAIChatContent *)user_data;
    int index = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button), "conversation-index"));

    if (index < 0 || index >= content->conversation_count) {
        return;
    }

    content->selected_index = index;
    render_selected_conversation(content);
}

static GtkWidget *conversation_strip(HybridAIChatContent *content) {
    GtkWidget *strip = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_add_css_class(strip, "conversation-strip");

    GtkWidget *caption = label_with_class("CONVERSATIONS", "conversation-caption");
    GtkWidget *chip_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_hexpand(chip_row, TRUE);

    content->conversation_buttons = g_new0(GtkWidget *, content->conversation_count);
    for (int index = 0; index < content->conversation_count; ++index) {
        GtkWidget *button = gtk_button_new_with_label(content->conversations[index].title);
        gtk_widget_add_css_class(button, "conversation-chip");
        g_object_set_data(G_OBJECT(button), "conversation-index", GINT_TO_POINTER(index));
        g_signal_connect(button, "clicked", G_CALLBACK(on_conversation_clicked), content);
        gtk_box_append(GTK_BOX(chip_row), button);
        content->conversation_buttons[index] = button;
    }

    gtk_box_append(GTK_BOX(strip), caption);
    gtk_box_append(GTK_BOX(strip), chip_row);

    return strip;
}

static void activate(GtkApplication *app, gpointer user_data) {
    HybridAIChatContent *content = (HybridAIChatContent *)user_data;
    add_css();

    GtkWidget *window = adw_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Hybrid AI Chat");
    gtk_window_set_default_size(GTK_WINDOW(window), 390, 760);
    gtk_window_set_resizable(GTK_WINDOW(window), TRUE);

    GtkWidget *shell = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
    gtk_widget_add_css_class(shell, "app-shell");
    gtk_widget_set_margin_top(shell, 18);
    gtk_widget_set_margin_bottom(shell, 18);
    gtk_widget_set_margin_start(shell, 16);
    gtk_widget_set_margin_end(shell, 16);
    adw_application_window_set_content(ADW_APPLICATION_WINDOW(window), shell);

    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    GtkWidget *title = label_with_class(content->title, "title");
    GtkWidget *subtitle = label_with_class("", "subtitle");
    content->subtitle_label = subtitle;
    gtk_box_append(GTK_BOX(header), title);
    gtk_box_append(GTK_BOX(header), subtitle);
    gtk_box_append(GTK_BOX(shell), header);

    GtkWidget *conversation_summary = conversation_strip(content);
    gtk_box_append(GTK_BOX(shell), conversation_summary);

    GtkWidget *scroller = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scroller, TRUE);
    gtk_widget_add_css_class(scroller, "chat-list");

    GtkWidget *messages = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    gtk_widget_set_margin_top(messages, 8);
    gtk_widget_set_margin_bottom(messages, 8);
    gtk_widget_set_margin_start(messages, 2);
    gtk_widget_set_margin_end(messages, 2);
    content->messages_box = messages;

    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroller), messages);
    gtk_box_append(GTK_BOX(shell), scroller);

    GtkWidget *composer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_add_css_class(composer, "composer");
    GtkWidget *entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(entry), "Ask Hybrid AI…");
    gtk_widget_set_hexpand(entry, TRUE);
    content->composer_entry = entry;
    GtkWidget *send = gtk_button_new_with_label("Send");
    gtk_widget_add_css_class(send, "suggested-action");
    gtk_widget_add_css_class(send, "send-button");
    g_signal_connect(entry, "activate", G_CALLBACK(on_entry_activated), content);
    g_signal_connect(send, "clicked", G_CALLBACK(on_send_clicked), content);
    gtk_box_append(GTK_BOX(composer), entry);
    gtk_box_append(GTK_BOX(composer), send);
    gtk_box_append(GTK_BOX(shell), composer);

    render_selected_conversation(content);

    gtk_window_present(GTK_WINDOW(window));
}

void hybrid_ai_mobile_chat_run(void) {
    HybridAIConversationSnapshot conversations[] = {
        {
            .title = "Overview",
            .assistant_intro = "Hybrid AI runtime ready. Inference abstractions are connected.",
            .user_message = "Can you summarize the current preview state?",
            .assistant_reply = "The GTK shell can now switch between prepared conversation snapshots."
        },
        {
            .title = "Selected Chat",
            .assistant_intro = "Hybrid AI runtime ready. Inference abstractions are connected.",
            .user_message = "Can you confirm the Swift UI proof is wired up?",
            .assistant_reply = "Yes. This shell now renders messages prepared through the shared inference app model."
        }
    };

    hybrid_ai_mobile_chat_run_with_conversations(
        "Hybrid AI",
        "Selected",
        conversations,
        2,
        1
    );
}

void hybrid_ai_mobile_chat_run_with_messages(
    const char *title,
    const char *subtitle,
    const char *conversation_list,
    const char *assistant_intro,
    const char *user_message,
    const char *assistant_reply
) {
    HybridAIConversationSnapshot conversations[] = {
        {
            .title = title,
            .assistant_intro = assistant_intro,
            .user_message = user_message,
            .assistant_reply = assistant_reply,
        }
    };

    hybrid_ai_mobile_chat_run_with_conversations(title, subtitle, conversations, 1, 0);
}

void hybrid_ai_mobile_chat_run_with_conversations(
    const char *title,
    const char *subtitle_prefix,
    const HybridAIConversationSnapshot *conversations,
    int conversation_count,
    int selected_index
) {
    HybridAIChatContent content = {
        .title = g_strdup(title),
        .subtitle_prefix = g_strdup(subtitle_prefix),
        .conversation_count = conversation_count,
        .selected_index = selected_index < 0 ? 0 : selected_index,
        .conversations = g_new0(HybridAIConversationSnapshotOwned, conversation_count),
        .subtitle_label = NULL,
        .messages_box = NULL,
        .conversation_buttons = NULL,
        .composer_entry = NULL,
    };

    for (int index = 0; index < conversation_count; ++index) {
        content.conversations[index].title = g_strdup(conversations[index].title);
        content.conversations[index].assistant_intro = g_strdup(conversations[index].assistant_intro);
        content.conversations[index].user_message = g_strdup(conversations[index].user_message);
        content.conversations[index].assistant_reply = g_strdup(conversations[index].assistant_reply);
    }

    if (content.selected_index >= conversation_count) {
        content.selected_index = conversation_count - 1;
    }

    AdwApplication *app = adw_application_new("dev.hybridai.MobileChat", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), &content);
    g_application_run(G_APPLICATION(app), 0, NULL);
    g_object_unref(app);

    g_free(content.title);
    g_free(content.subtitle_prefix);
    for (int index = 0; index < conversation_count; ++index) {
        g_free(content.conversations[index].title);
        g_free(content.conversations[index].assistant_intro);
        g_free(content.conversations[index].user_message);
        g_free(content.conversations[index].assistant_reply);
    }
    g_free(content.conversations);
    g_free(content.conversation_buttons);
}
