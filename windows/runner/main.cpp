#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>
#include <cstdio>
#include <string>

#include "flutter_window.h"
#include "utils.h"

static void ApplyHwAccelPref() {
  wchar_t appdata[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appdata))) {
    return;
  }
  std::wstring path = std::wstring(appdata) + L"\\aqloss\\hw_accel";
  FILE *f = _wfopen(path.c_str(), L"rb");
  if (!f) return;
  char c = 0;
  if (fread(&c, 1, 1, f) == 1 && c == '0') {
    _putenv_s("FLUTTER_ENGINE_SWITCHES", "2");
    _putenv_s("FLUTTER_ENGINE_SWITCH_1", "enable-software-rendering");
    _putenv_s("FLUTTER_ENGINE_SWITCH_2", "disable-impeller");
  }
  fclose(f);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  ApplyHwAccelPref();
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"aqloss", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  int argc;
  LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv && argc > 1)
  {
    int n = WideCharToMultiByte(CP_UTF8, 0, argv[1], -1,
                                nullptr, 0, nullptr, nullptr);
    std::string path(n, '\0');
    WideCharToMultiByte(CP_UTF8, 0, argv[1], -1,
                        path.data(), n, nullptr, nullptr);
    if (!path.empty() && path.back() == '\0')
      path.pop_back();
    window.SendFileToFlutter(path);
  }
  LocalFree(argv);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
