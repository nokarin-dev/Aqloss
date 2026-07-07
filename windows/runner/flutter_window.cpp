#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "file_assoc.h"
#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* c = reinterpret_cast<flutter::FlutterViewController*>(controller);
    RegisterPlugins(c->engine());
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });
  flutter_controller_->ForceRedraw();

  DragAcceptFiles(GetHandle(), TRUE);

  RegisterFileAssociations();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

void FlutterWindow::SendFileToFlutter(const std::string& utf8_path) {
  if (!flutter_controller_) return;
  flutter::MethodChannel<flutter::EncodableValue> channel(
    flutter_controller_->engine()->messenger(),
    "xyz.nokarin.aqloss/file_open",
    &flutter::StandardMethodCodec::GetInstance()
  );
  channel.InvokeMethod(
    "openFile",
    std::make_unique<flutter::EncodableValue>(utf8_path)
  );
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_DROPFILES: {
      HDROP drop = reinterpret_cast<HDROP>(wparam);
      UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
      for (UINT i = 0; i < count; ++i) {
        UINT len = DragQueryFileW(drop, i, nullptr, 0) + 1;
        std::wstring buf(len, L'\0');
        DragQueryFileW(drop, i, buf.data(), len);

        int n = WideCharToMultiByte(CP_UTF8, 0, buf.c_str(), -1,
                                    nullptr, 0, nullptr, nullptr);
        std::string path(n, '\0');
        WideCharToMultiByte(CP_UTF8, 0, buf.c_str(), -1,
                            path.data(), n, nullptr, nullptr);
        if (!path.empty() && path.back() == '\0') path.pop_back();

        SendFileToFlutter(path);
      }
      DragFinish(drop);
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
