// SPDX-License-Identifier: BSD-3-Clause
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <cstring>
#include <initializer_list>
#include <unistd.h>

static bool first_frame = false;
static bool busy = false;
int main(int argc, char** argv) {
  if (geteuid() == 0) { g_printerr("Run 5BSD Imager as your desktop user.\n"); return 1; }
  bool smoke = false;
  for (int i = 1; i < argc; ++i) smoke |= !strcmp(argv[i], "--smoke-test");
  g_set_prgname("org.fivebsd.Imager");
  g_set_application_name("5BSD Imager");
  gtk_init(&argc, &argv);
  g_autoptr(GtkApplication) application = gtk_application_new("org.fivebsd.Imager", G_APPLICATION_NON_UNIQUE);
  g_autoptr(GError) registration_error = nullptr;
  if (!g_application_register(G_APPLICATION(application), nullptr, &registration_error)) {
    g_printerr("Application registration failed: %s\n", registration_error->message); return 1;
  }
  GtkWidget* window = gtk_application_window_new(application);
  // GTK 3's Wayland backend ignores set_decorated(FALSE) when negotiating
  // with KWin unless the window also advertises client-side decorations.
  // Register a hidden titlebar before realization; Flutter draws the header.
  GtkWidget* titlebar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
  gtk_widget_set_no_show_all(titlebar, TRUE);
  gtk_window_set_titlebar(GTK_WINDOW(window), titlebar);
  gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
  gtk_window_set_title(GTK_WINDOW(window), "5BSD Imager");
  gtk_window_set_icon_name(GTK_WINDOW(window), "org.fivebsd.Imager");
  gtk_window_set_default_size(GTK_WINDOW(window), 980, 760);
  GdkGeometry geometry{}; geometry.min_width = 840; geometry.min_height = 700;
  gtk_window_set_geometry_hints(GTK_WINDOW(window), nullptr, &geometry, GDK_HINT_MIN_SIZE);
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, argv + 1);
  FlView* view = fl_view_new(project);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
    fl_engine_get_binary_messenger(fl_view_get_engine(view)), "5bsd/imager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel,
    +[](FlMethodChannel*, FlMethodCall* call, gpointer data) {
      const char* method = fl_method_call_get_name(call);
      if (!strcmp(method, "busy")) {
        auto* args = fl_method_call_get_args(call);
        busy = fl_value_get_type(args) == FL_VALUE_TYPE_BOOL && fl_value_get_bool(args);
        fl_method_call_respond_success(call, nullptr, nullptr);
      } else if (!strcmp(method, "minimize")) {
        gtk_window_iconify(GTK_WINDOW(data));
        fl_method_call_respond_success(call, nullptr, nullptr);
      } else if (!strcmp(method, "maximize")) {
        if (gtk_window_is_maximized(GTK_WINDOW(data))) gtk_window_unmaximize(GTK_WINDOW(data));
        else gtk_window_maximize(GTK_WINDOW(data));
        fl_method_call_respond_success(call, nullptr, nullptr);
      } else if (!strcmp(method, "close")) {
        fl_method_call_respond_success(call, nullptr, nullptr);
        if (!busy) gtk_window_close(GTK_WINDOW(data));
      } else if (!strcmp(method, "pickImage")) {
        GtkWidget* dialog = gtk_file_chooser_dialog_new("Choose a disk image", GTK_WINDOW(data),
          GTK_FILE_CHOOSER_ACTION_OPEN, "Cancel", GTK_RESPONSE_CANCEL, "Choose image", GTK_RESPONSE_ACCEPT, nullptr);
        GtkFileFilter* filter = gtk_file_filter_new();
        gtk_file_filter_set_name(filter, "Disk images (*.img, *.iso, *.raw, *.xz)");
        for (auto* pattern : {"*.img", "*.iso", "*.raw", "*.xz", "*.IMG", "*.ISO", "*.RAW", "*.XZ"})
          gtk_file_filter_add_pattern(filter, pattern);
        gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);
        g_object_ref(call);
        g_signal_connect(dialog, "response", G_CALLBACK(+[](GtkDialog* dialog, gint response, gpointer value) {
          auto* call = FL_METHOD_CALL(value);
          g_autoptr(FlValue) result = nullptr;
          if (response == GTK_RESPONSE_ACCEPT) {
            g_autofree gchar* path = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
            result = fl_value_new_string(path);
          }
          fl_method_call_respond_success(call, result, nullptr);
          gtk_widget_destroy(GTK_WIDGET(dialog)); g_object_unref(call);
        }), call);
        gtk_widget_show(dialog);
      } else fl_method_call_respond_not_implemented(call, nullptr);
    }, window, nullptr);
  g_signal_connect(window, "delete-event", G_CALLBACK(+[](GtkWidget* widget, GdkEvent*, gpointer) -> gboolean {
    // Handle this before FlView's delete-event hook. Flutter quits a
    // GApplication loop, but this runner owns gtk_main; destroy emits our
    // gtk_main_quit hook. Busy writes must still be cancelled through Dart.
    if (!busy) gtk_widget_destroy(widget);
    return TRUE;
  }), nullptr);
  g_signal_connect(window, "destroy", G_CALLBACK(+[](GtkWidget*, gpointer) { gtk_main_quit(); }), nullptr);
  g_signal_connect(view, "first-frame", G_CALLBACK(+[](FlView*, gpointer) {
    first_frame = true; g_print("5BSD_IMAGER_FIRST_FRAME\n");
  }), nullptr);
  // Use the original GDK pointer event/serial so dragging works on Wayland.
  // The leftmost 108px of the custom 48px header contains window controls.
  // FlView's child event box consumes button presses before they bubble to
  // FlView. Its generic event signal runs before Flutter's button handler.
  // Intercept only native chrome, preserving the actual Wayland input serial.
  GList* view_children = gtk_container_get_children(GTK_CONTAINER(view));
  GtkWidget* input = nullptr;
  for (GList* child = view_children; child; child = child->next)
    if (GTK_IS_EVENT_BOX(child->data)) input = GTK_WIDGET(child->data);
  g_list_free(view_children);
  if (!input) { g_printerr("Flutter input widget not found.\n"); return 1; }
  g_signal_connect(input, "event", G_CALLBACK(+[](GtkWidget* widget, GdkEvent* raw, gpointer data) -> gboolean {
    if (raw->type != GDK_BUTTON_PRESS && raw->type != GDK_2BUTTON_PRESS) return FALSE;
    const auto* event = &raw->button;
    if (event->button != 1) return FALSE;
    const int width = gtk_widget_get_allocated_width(widget);
    const int height = gtk_widget_get_allocated_height(widget);
    auto* window = GTK_WINDOW(data);
    const bool left = event->x < 5;
    const bool right = event->x >= width - 5;
    const bool top = event->y < 5;
    const bool bottom = event->y >= height - 5;
    if (!gtk_window_is_maximized(window) && (left || right || top || bottom)) {
      GdkWindowEdge edge = top ? (left ? GDK_WINDOW_EDGE_NORTH_WEST : right ? GDK_WINDOW_EDGE_NORTH_EAST : GDK_WINDOW_EDGE_NORTH)
        : bottom ? (left ? GDK_WINDOW_EDGE_SOUTH_WEST : right ? GDK_WINDOW_EDGE_SOUTH_EAST : GDK_WINDOW_EDGE_SOUTH)
        : left ? GDK_WINDOW_EDGE_WEST : GDK_WINDOW_EDGE_EAST;
      gtk_window_begin_resize_drag(window, edge, 1, event->x_root, event->y_root, event->time);
      return TRUE;
    }
    if (event->y < 48 && event->x >= 108) {
      if (event->type == GDK_2BUTTON_PRESS) {
        if (gtk_window_is_maximized(window)) gtk_window_unmaximize(window); else gtk_window_maximize(window);
      } else gtk_window_begin_move_drag(window, 1, event->x_root, event->y_root, event->time);
      return TRUE;
    }
    return FALSE;
  }), window);
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  gtk_widget_show_all(window);
  gtk_widget_grab_focus(GTK_WIDGET(view));
  if (smoke) g_timeout_add_seconds(10, +[](gpointer) -> gboolean { gtk_main_quit(); return G_SOURCE_REMOVE; }, nullptr);
  gtk_main();
  return smoke && !first_frame ? 1 : 0;
}
