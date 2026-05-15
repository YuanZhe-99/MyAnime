#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// Purpose: Create a Flutter window wrapper bound to the provided Dart project.
// Inputs: `project`.
// Returns: None.
// Side effects: Stores the project configuration for later window creation.
// Notes: The hosted Flutter controller is created later in `OnCreate`.
FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

// Purpose: Destroy the Flutter window wrapper.
// Inputs: None.
// Returns: None.
// Side effects: None.
// Notes: Cleanup is handled by the owning Win32 window lifecycle.
FlutterWindow::~FlutterWindow() {}

// Purpose: Create the native Flutter view controller and attach it to the window.
// Inputs: None.
// Returns: `true` on success, otherwise `false`.
// Side effects: Registers plugins, hosts the Flutter view, and shows the window after the first frame.
// Notes: Forces a redraw so the window is shown even if the first frame finishes very quickly.
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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

// Purpose: Release the hosted Flutter controller before the base window tears down.
// Inputs: None.
// Returns: None.
// Side effects: Destroys the hosted Flutter view controller.
// Notes: Called from the Win32 window destruction path.
void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// Purpose: Let Flutter process top-level window messages before falling back to Win32 defaults.
// Inputs: `hwnd`, `message`, `wparam`, `lparam`.
// Returns: The handled window message result.
// Side effects: May forward messages into Flutter and reload system fonts on font changes.
// Notes: Only unhandled messages continue to the base `Win32Window` handler.
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
