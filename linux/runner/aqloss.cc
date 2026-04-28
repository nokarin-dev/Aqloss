#include "aqloss.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _Aqloss
{
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
};

G_DEFINE_TYPE(Aqloss, aqloss, GTK_TYPE_APPLICATION)

static void first_frame_cb(Aqloss *self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void aqloss_activate(GApplication *application)
{
  Aqloss *self = AQLOSS_APP(application);
  GtkWindow *window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  GdkScreen *screen = gtk_window_get_screen(window);

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_SCREEN(screen))
  {
    const gchar *wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0)
    {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar)
  {
    GtkHeaderBar *header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Aqloss");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  }
  else
  {
    gtk_window_set_title(window, "Aqloss");
  }

  gtk_window_set_default_size(window, 1280, 720);

  GdkVisual *visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr && gdk_screen_is_composited(screen))
  {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
  }
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView *view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean aqloss_local_command_line(GApplication *application,
                                          gchar ***arguments,
                                          int *exit_status)
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

static void aqloss_startup(GApplication *application)
{
  G_APPLICATION_CLASS(aqloss_parent_class)->startup(application);
}

static void aqloss_shutdown(GApplication *application)
{
  G_APPLICATION_CLASS(aqloss_parent_class)->shutdown(application);
}

static void aqloss_dispose(GObject *object)
{
  Aqloss *self = AQLOSS_APP(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(aqloss_parent_class)->dispose(object);
}

static void aqloss_class_init(AqlossClass *klass)
{
  G_APPLICATION_CLASS(klass)->activate = aqloss_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      aqloss_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = aqloss_startup;
  G_APPLICATION_CLASS(klass)->shutdown = aqloss_shutdown;
  G_OBJECT_CLASS(klass)->dispose = aqloss_dispose;
}

static void aqloss_init(Aqloss *self) {}

Aqloss *aqloss_new()
{
  g_set_prgname(APPLICATION_ID);

  return AQLOSS_APP(g_object_new(aqloss_get_type(),
                                 "application-id", APPLICATION_ID, "flags",
                                 G_APPLICATION_NON_UNIQUE, nullptr));
}
