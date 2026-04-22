#ifndef FLUTTER_AQLOSS_H_
#define FLUTTER_AQLOSS_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(Aqloss,
                     aqloss,
                     AQLOSS,
                     APP,
                     GtkApplication)

Aqloss *aqloss_new();

#endif
