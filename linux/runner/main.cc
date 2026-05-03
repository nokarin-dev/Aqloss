#include "aqloss.h"

int main(int argc, char** argv) {
  g_autoptr(Aqloss) app = aqloss_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
