#include "aqloss.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include <libgen.h>
#include <cstdlib>
#include <cstring>
#include <gio/gio.h>

struct _Aqloss
{
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
  FlMethodChannel *file_open_channel;
  FlMethodChannel *chrome_channel;
  gboolean chrome_flush;
  gboolean chrome_flush_known;
};

G_DEFINE_TYPE(Aqloss, aqloss, GTK_TYPE_APPLICATION)

static gboolean window_is_flush(GtkWindow *win)
{
  GdkWindow *gdk_win = gtk_widget_get_window(GTK_WIDGET(win));
  if (!gdk_win)
    return FALSE;

  GdkWindowState st = gdk_window_get_state(gdk_win);
  if (st & (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN |
            GDK_WINDOW_STATE_TILED))
    return TRUE;
#if GTK_CHECK_VERSION(3, 22, 0)
  if (st & (GDK_WINDOW_STATE_TOP_TILED | GDK_WINDOW_STATE_BOTTOM_TILED |
            GDK_WINDOW_STATE_LEFT_TILED | GDK_WINDOW_STATE_RIGHT_TILED))
    return TRUE;
#endif

  GdkDisplay *display = gdk_window_get_display(gdk_win);
  GdkMonitor *mon = gdk_display_get_monitor_at_window(display, gdk_win);
  if (!mon)
    return FALSE;

  GdkRectangle wa;
  gdk_monitor_get_workarea(mon, &wa);

  gint w = 0, h = 0, x = 0, y = 0;
  gtk_window_get_size(win, &w, &h);
  gtk_window_get_position(win, &x, &y);

  const int edge = 32;
  const gboolean fills_h = h >= wa.height - edge;
  const gboolean fills_w = w >= wa.width - edge;
  if (fills_w && fills_h)
    return TRUE;

  const gboolean left = x <= wa.x + edge;
  const gboolean right = x + w >= wa.x + wa.width - edge;
  const gboolean top = y <= wa.y + edge;
  const gboolean bottom = y + h >= wa.y + wa.height - edge;

  if (fills_h && (left || right || w <= (gint)(wa.width * 0.72)))
    return TRUE;
  if (fills_w && (top || bottom || h <= (gint)(wa.height * 0.72)))
    return TRUE;
  return FALSE;
}

static void emit_window_chrome(Aqloss *self, GtkWindow *win)
{
  if (!self || !self->chrome_channel || !win)
    return;
  const gboolean flush = window_is_flush(win);
  if (self->chrome_flush_known && self->chrome_flush == flush)
    return;
  self->chrome_flush = flush;
  self->chrome_flush_known = TRUE;
  g_autoptr(FlValue) args = fl_value_new_bool(flush);
  fl_method_channel_invoke_method(
      self->chrome_channel, "setFlush", args, nullptr, nullptr, nullptr);
}

static gboolean on_window_configure(GtkWidget *widget, GdkEventConfigure *,
                                    gpointer ud)
{
  emit_window_chrome(AQLOSS_APP(ud), GTK_WINDOW(widget));
  return FALSE;
}

static gboolean on_window_state(GtkWidget *widget, GdkEventWindowState *,
                                gpointer ud)
{
  emit_window_chrome(AQLOSS_APP(ud), GTK_WINDOW(widget));
  return FALSE;
}

static void chrome_method_call(FlMethodChannel *, FlMethodCall *call,
                               gpointer ud)
{
  Aqloss *self = AQLOSS_APP(ud);
  g_autoptr(FlMethodResponse) resp = nullptr;
  if (strcmp(fl_method_call_get_name(call), "getFlush") == 0)
  {
    resp = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(self->chrome_flush)));
  }
  else
  {
    resp = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, resp, nullptr);
}

static void first_frame_cb(Aqloss *self, FlView *view)
{
  GtkWidget *top = gtk_widget_get_toplevel(GTK_WIDGET(view));
  gtk_widget_show(top);
  if (GTK_IS_WINDOW(top))
    emit_window_chrome(self, GTK_WINDOW(top));
}

static void set_transparent(GtkWindow *win, FlView *fl_view)
{
  GdkScreen *screen = gtk_window_get_screen(win);
  GdkVisual *visual = gdk_screen_get_rgba_visual(screen);
  if (visual && gdk_screen_is_composited(screen))
    gtk_widget_set_visual(GTK_WIDGET(win), visual);

  GtkCssProvider *p = gtk_css_provider_new();
  gtk_css_provider_load_from_data(
      p, "window,window>*{background-color:transparent;box-shadow:none;border:none;}",
      -1, nullptr);
  gtk_style_context_add_provider(
      gtk_widget_get_style_context(GTK_WIDGET(win)),
      GTK_STYLE_PROVIDER(p), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(p);

  GdkRGBA bg = {0, 0, 0, 0};
  fl_view_set_background_color(fl_view, &bg);
}

struct DragState
{
  GtkWindow *win;
  guint32 last_press_time = GDK_CURRENT_TIME;
  gint last_press_x = 0;
  gint last_press_y = 0;
};

static void register_drag_channel(FlView *fl_view, GtkWindow *win)
{
  DragState *ds = g_new0(DragState, 1);
  ds->win = win;

  gtk_widget_add_events(GTK_WIDGET(win),
                        GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);
  g_signal_connect(GTK_WIDGET(win), "button-press-event",
                   G_CALLBACK(+[](GtkWidget *, GdkEventButton *ev, gpointer ud) -> gboolean
                              {
                                auto *s = static_cast<DragState *>(ud);
                                if (ev->button == 1)
                                {
                                  s->last_press_time = ev->time;
                                  s->last_press_x = (gint)ev->x_root;
                                  s->last_press_y = (gint)ev->y_root;
                                }
                                return FALSE;
                              }),
                   ds);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlPluginRegistrar) reg =
      fl_plugin_registry_get_registrar_for_plugin(
          FL_PLUGIN_REGISTRY(fl_view), "aqloss_drag");
  FlMethodChannel *ch = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(reg),
      "aqloss/drag", FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(
      ch,
      [](FlMethodChannel *, FlMethodCall *call, gpointer ud)
      {
        auto *ds = static_cast<DragState *>(ud);
        g_autoptr(FlMethodResponse) resp = nullptr;
        if (strcmp(fl_method_call_get_name(call), "startDragging") == 0)
        {
          GdkWindow *gdk_win = gtk_widget_get_window(GTK_WIDGET(ds->win));
          if (gdk_win)
          {
            GdkDisplay *display = gdk_window_get_display(gdk_win);
            GdkSeat *seat = gdk_display_get_default_seat(display);
            if (seat)
              gdk_seat_ungrab(seat);
            gdk_window_begin_move_drag(
                gdk_win, 1,
                ds->last_press_x, ds->last_press_y,
                ds->last_press_time);
          }
          resp = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
        }
        else
        {
          resp = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
        }
        fl_method_call_respond(call, resp, nullptr);
      },
      ds,
      [](gpointer p)
      { g_free(p); });

  g_object_unref(ch);
}

static void enforce_above(GtkWidget *w)
{
  GtkWindow *win = GTK_WINDOW(w);
  gtk_window_set_keep_above(win, TRUE);
#ifdef GDK_WINDOWING_X11
  GdkWindow *gdk_win = gtk_widget_get_window(w);
  if (gdk_win && GDK_IS_X11_WINDOW(gdk_win))
  {
    GdkDisplay *dpy = gdk_window_get_display(gdk_win);
    Display *xdpy = gdk_x11_display_get_xdisplay(dpy);
    Window xwin = gdk_x11_window_get_xid(gdk_win);
    Atom net_wm_state = XInternAtom(xdpy, "_NET_WM_STATE", False);
    Atom above = XInternAtom(xdpy, "_NET_WM_STATE_ABOVE", False);
    XEvent xev = {};
    xev.xclient.type = ClientMessage;
    xev.xclient.window = xwin;
    xev.xclient.message_type = net_wm_state;
    xev.xclient.format = 32;
    xev.xclient.data.l[0] = 1;
    xev.xclient.data.l[1] = (long)above;
    XSendEvent(xdpy, DefaultRootWindow(xdpy), False,
               SubstructureRedirectMask | SubstructureNotifyMask, &xev);
    XFlush(xdpy);
  }
#endif
}

static gboolean on_sub_delete(GtkWidget *widget, GdkEvent *, gpointer)
{
  gtk_widget_hide(widget);
  return TRUE;
}

// Send a file path to Dart via the file_open channel
static void send_file_to_flutter(Aqloss *self, const char *path)
{
  if (!self->file_open_channel || !path)
    return;
  g_autoptr(FlValue) arg = fl_value_new_string(path);
  fl_method_channel_invoke_method(
      self->file_open_channel, "openFile", arg, nullptr, nullptr, nullptr);
}

static void aqloss_open(GApplication *application,
                        GFile **files, gint n_files,
                        const gchar * /*hint*/)
{
  Aqloss *self = AQLOSS_APP(application);

  // Ensure the main window is shown
  g_application_activate(application);

  for (gint i = 0; i < n_files; i++)
  {
    char *path = g_file_get_path(files[i]);
    if (path)
    {
      send_file_to_flutter(self, path);
      g_free(path);
    }
  }
}

static void aqloss_activate(GApplication *application)
{
  Aqloss *self = AQLOSS_APP(application);
  GtkWindow *window = GTK_WINDOW(
      gtk_application_window_new(GTK_APPLICATION(application)));

  gtk_window_set_decorated(window, FALSE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

#ifdef FLATPAK
  char exe_path[PATH_MAX];
  ssize_t n = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
  if (n > 0)
  {
    exe_path[n] = '\0';
    char aot[PATH_MAX];
    snprintf(aot, sizeof(aot), "%s/../../lib/%s/libapp.so",
             dirname(exe_path), APPLICATION_ID);
    fl_dart_project_set_aot_library_path(project, aot);
  }
#endif

  FlView *view = fl_view_new(project);
  gtk_window_set_default_size(window, 1280, 720);
  set_transparent(window, view);

  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    g_autoptr(FlPluginRegistrar) reg =
        fl_plugin_registry_get_registrar_for_plugin(
            FL_PLUGIN_REGISTRY(view), "aqloss_file_open");
    self->file_open_channel = fl_method_channel_new(
        fl_plugin_registrar_get_messenger(reg),
        "xyz.nokarin.aqloss/file_open",
        FL_METHOD_CODEC(codec));
  }

  {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    g_autoptr(FlPluginRegistrar) reg =
        fl_plugin_registry_get_registrar_for_plugin(
            FL_PLUGIN_REGISTRY(view), "aqloss_window_chrome");
    self->chrome_channel = fl_method_channel_new(
        fl_plugin_registrar_get_messenger(reg),
        "xyz.nokarin.aqloss/window_chrome",
        FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(
        self->chrome_channel, chrome_method_call, self, nullptr);
  }

  g_signal_connect(window, "configure-event", G_CALLBACK(on_window_configure),
                   self);
  g_signal_connect(window, "window-state-event", G_CALLBACK(on_window_state),
                   self);

  desktop_multi_window_plugin_set_window_created_callback(
      [](FlPluginRegistry *registry)
      {
        fl_register_plugins(registry);

        if (!FL_IS_VIEW(registry))
          return;
        FlView *fl_view = FL_VIEW(registry);

        GtkWidget *top = gtk_widget_get_toplevel(GTK_WIDGET(fl_view));
        if (!GTK_IS_WINDOW(top))
          return;
        GtkWindow *sub = GTK_WINDOW(top);

        gtk_window_set_decorated(sub, FALSE);
        gtk_window_set_default_size(sub, 340, 104);
        gtk_window_resize(sub, 340, 104);
        gtk_window_set_resizable(sub, FALSE);
        gtk_window_set_skip_taskbar_hint(sub, TRUE);
        gtk_window_set_skip_pager_hint(sub, TRUE);
        gtk_window_set_type_hint(sub, GDK_WINDOW_TYPE_HINT_UTILITY);
        gtk_window_set_keep_above(sub, TRUE);

        GdkScreen *screen = gtk_window_get_screen(sub);
        GdkDisplay *display = gdk_screen_get_display(screen);
        GdkMonitor *mon = gdk_display_get_primary_monitor(display);
        if (mon)
        {
          GdkRectangle wa;
          gdk_monitor_get_workarea(mon, &wa);
          gtk_window_move(sub, wa.x + wa.width - 340 - 16,
                          wa.y + wa.height - 104 - 16);
        }

        set_transparent(sub, fl_view);
        register_drag_channel(fl_view, sub);

        g_signal_connect(top, "map",
                         G_CALLBACK(+[](GtkWidget *w, gpointer)
                                    { enforce_above(w); }),
                         nullptr);
        g_signal_connect(top, "show",
                         G_CALLBACK(+[](GtkWidget *w, gpointer)
                                    { enforce_above(w); }),
                         nullptr);
        g_signal_connect(top, "delete-event",
                         G_CALLBACK(on_sub_delete), nullptr);
      });

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean aqloss_local_command_line(GApplication *application,
                                          gchar ***arguments, int *exit_status)
{
  Aqloss *self = AQLOSS_APP(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error))
  {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }
  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}

static void aqloss_startup(GApplication *app) { G_APPLICATION_CLASS(aqloss_parent_class)->startup(app); }
static void aqloss_shutdown(GApplication *app) { G_APPLICATION_CLASS(aqloss_parent_class)->shutdown(app); }
static void aqloss_dispose(GObject *obj)
{
  Aqloss *self = AQLOSS_APP(obj);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->file_open_channel);
  g_clear_object(&self->chrome_channel);
  G_OBJECT_CLASS(aqloss_parent_class)->dispose(obj);
}

static void aqloss_class_init(AqlossClass *klass)
{
  G_APPLICATION_CLASS(klass)->activate = aqloss_activate;
  G_APPLICATION_CLASS(klass)->open = aqloss_open;
  G_APPLICATION_CLASS(klass)->local_command_line = aqloss_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = aqloss_startup;
  G_APPLICATION_CLASS(klass)->shutdown = aqloss_shutdown;
  G_OBJECT_CLASS(klass)->dispose = aqloss_dispose;
}

static void aqloss_init(Aqloss *) {}

Aqloss *aqloss_new()
{
  g_set_prgname(APPLICATION_ID);
  return AQLOSS_APP(g_object_new(aqloss_get_type(),
                                 "application-id", APPLICATION_ID,
                                 "flags", G_APPLICATION_HANDLES_OPEN,
                                 nullptr));
}
