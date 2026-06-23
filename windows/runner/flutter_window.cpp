#include "flutter_window.h"

#include <optional>
#include <shellapi.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Set up drag-drop MethodChannel (C++ -> Dart)
  drag_drop_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(),
      "com.lanchat.lanchat/dragdrop",
      &flutter::StandardMethodCodec::GetInstance());

  // Enable drag-drop file acceptance for this window
  DragAcceptFiles(GetHandle(), TRUE);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  DragAcceptFiles(GetHandle(), FALSE);

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_DROPFILES: {
      HDROP hDrop = reinterpret_cast<HDROP>(wparam);
      UINT fileCount = DragQueryFileW(hDrop, 0xFFFFFFFF, nullptr, 0);

      flutter::EncodableList files;
      for (UINT i = 0; i < fileCount; i++) {
        UINT pathLen = DragQueryFileW(hDrop, i, nullptr, 0);
        if (pathLen == 0) continue;
        std::wstring pathBuf(pathLen + 1, L'\0');
        DragQueryFileW(hDrop, i, pathBuf.data(), pathLen + 1);
        // Convert wstring (UTF-16) to UTF-8
        int utf8Len = WideCharToMultiByte(CP_UTF8, 0, pathBuf.c_str(), pathLen,
                                          nullptr, 0, nullptr, nullptr);
        if (utf8Len > 0) {
          std::string utf8Path(utf8Len, '\0');
          WideCharToMultiByte(CP_UTF8, 0, pathBuf.c_str(), pathLen,
                              utf8Path.data(), utf8Len, nullptr, nullptr);
          files.push_back(flutter::EncodableValue(utf8Path));
        }
      }

      DragFinish(hDrop);

      if (drag_drop_channel_ && !files.empty()) {
        drag_drop_channel_->InvokeMethod(
            "onFilesDropped",
            std::make_unique<flutter::EncodableValue>(files));
      }
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
