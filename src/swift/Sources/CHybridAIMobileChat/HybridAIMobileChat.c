#include "HybridAIMobileChat.h"

#include <adwaita.h>
#include <gtk/gtk.h>

typedef struct {
    char *title;
    char *subtitle;
    char *assistant_intro;
    char *user_message;
    char *assistant_reply;
} HybridAIChatContent;

static void add_css(void) {
    GtkCssProvider *provider = gtk_css_provider_new();
    const char *css =
        "window { background: #0f172a; }"
        ".app-shell { background: #0f172a; }"
        ".title { color: #f8fafc; font-weight: 800; font-size: 22px; }"
        ".subtitle { color: #94a3b8; font-size: 12px; }"
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
    GtkWidget *subtitle = label_with_class(content->subtitle, "subtitle");
    gtk_box_append(GTK_BOX(header), title);
    gtk_box_append(GTK_BOX(header), subtitle);
    gtk_box_append(GTK_BOX(shell), header);

    GtkWidget *scroller = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scroller, TRUE);
    gtk_widget_add_css_class(scroller, "chat-list");

    GtkWidget *messages = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    gtk_widget_set_margin_top(messages, 8);
    gtk_widget_set_margin_bottom(messages, 8);
    gtk_widget_set_margin_start(messages, 2);
    gtk_widget_set_margin_end(messages, 2);

    gtk_box_append(GTK_BOX(messages), chat_bubble(content->assistant_intro, FALSE));
    gtk_box_append(GTK_BOX(messages), chat_bubble(content->user_message, TRUE));
    gtk_box_append(GTK_BOX(messages), chat_bubble(content->assistant_reply, FALSE));

    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroller), messages);
    gtk_box_append(GTK_BOX(shell), scroller);

    GtkWidget *composer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_add_css_class(composer, "composer");
    GtkWidget *entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(entry), "Ask Hybrid AI…");
    gtk_widget_set_hexpand(entry, TRUE);
    GtkWidget *send = gtk_button_new_with_label("Send");
    gtk_widget_add_css_class(send, "suggested-action");
    gtk_widget_add_css_class(send, "send-button");
    gtk_box_append(GTK_BOX(composer), entry);
    gtk_box_append(GTK_BOX(composer), send);
    gtk_box_append(GTK_BOX(shell), composer);

    gtk_window_present(GTK_WINDOW(window));
}

void hybrid_ai_mobile_chat_run(void) {
    hybrid_ai_mobile_chat_run_with_messages(
        "Hybrid AI",
        "Mobile chat prototype · Swift + GTK/libadwaita",
        "Hybrid AI runtime ready. Inference abstractions are connected.",
        "Can you confirm the Swift UI proof is wired up?",
        "Yes. This shell now renders messages prepared through the shared inference app model."
    );
}

void hybrid_ai_mobile_chat_run_with_messages(
    const char *title,
    const char *subtitle,
    const char *assistant_intro,
    const char *user_message,
    const char *assistant_reply
) {
    HybridAIChatContent content = {
        .title = g_strdup(title),
        .subtitle = g_strdup(subtitle),
        .assistant_intro = g_strdup(assistant_intro),
        .user_message = g_strdup(user_message),
        .assistant_reply = g_strdup(assistant_reply),
    };

    AdwApplication *app = adw_application_new("dev.hybridai.MobileChat", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), &content);
    g_application_run(G_APPLICATION(app), 0, NULL);
    g_object_unref(app);

    g_free(content.title);
    g_free(content.subtitle);
    g_free(content.assistant_intro);
    g_free(content.user_message);
    g_free(content.assistant_reply);
}
