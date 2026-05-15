#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
// Purpose: Scale a logical coordinate into a physical pixel value.
// Inputs: `source`, `scale_factor`.
// Returns: The scaled integer coordinate.
// Side effects: None.
// Notes: Used when creating DPI-aware Win32 windows.
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Purpose: Enable non-client DPI scaling when the current Windows version supports it.
// Inputs: `hwnd`.
// Returns: None.
// Side effects: Dynamically loads `User32.dll` and updates the target window when available.
// Notes: This is only needed for PerMonitor V1 DPI awareness.
// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  // Purpose: Return the singleton registrar used for the shared window class.
  // Inputs: None.
  // Returns: The shared `WindowClassRegistrar*`.
  // Side effects: Lazily allocates the registrar instance.
  // Notes: The runner keeps a single registrar for all top-level windows.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

// Purpose: Return the registered window-class name, registering it on first use.
// Inputs: None.
// Returns: The Win32 window class name.
// Side effects: Registers the shared Win32 window class the first time it is requested.
// Notes: Safe to call repeatedly after registration.
const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

// Purpose: Unregister the shared Win32 window class when no windows remain.
// Inputs: None.
// Returns: None.
// Side effects: Removes the registered window class from the process.
// Notes: Only call when all runner windows have already been destroyed.
void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

// Purpose: Construct a DPI-aware Win32 window wrapper and track active windows.
// Inputs: None.
// Returns: None.
// Side effects: Increments the active window count.
// Notes: The actual native window handle is created later by `Create`.
Win32Window::Win32Window() {
  ++g_active_window_count;
}

// Purpose: Destroy the wrapper and release its native window if it still exists.
// Inputs: None.
// Returns: None.
// Side effects: Decrements the active window count and tears down the native window.
// Notes: Calls `Destroy()` to keep shutdown behavior consistent.
Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

// Purpose: Create the native Win32 window with DPI-aware sizing and theme initialization.
// Inputs: `title`, `origin`, `size`.
// Returns: `true` on success, otherwise `false`.
// Side effects: Creates the native window handle and updates its frame theme.
// Notes: The window remains hidden until `Show()` is called.
bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

// Purpose: Show the native window.
// Inputs: None.
// Returns: Whether `ShowWindow` succeeded.
// Side effects: Makes the native window visible to the user.
// Notes: Uses `SW_SHOWNORMAL` for the initial presentation.
bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
// Purpose: Route Win32 messages to the owning `Win32Window` instance.
// Inputs: `window`, `message`, `wparam`, `lparam`.
// Returns: The Win32 message result.
// Side effects: Stores the `Win32Window` pointer on create and enables DPI support when available.
// Notes: Falls back to `DefWindowProc` until the instance pointer is available.
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

// Purpose: Handle common Win32 window lifecycle and resize messages.
// Inputs: `hwnd`, `message`, `wparam`, `lparam`.
// Returns: The Win32 message result.
// Side effects: May resize child content, post quit messages, or refresh window theming.
// Notes: Subclasses can override this method to intercept additional messages.
LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

// Purpose: Destroy the native window and unregister the shared class when appropriate.
// Inputs: None.
// Returns: None.
// Side effects: Calls `OnDestroy`, destroys the HWND, and may unregister the shared window class.
// Notes: Safe to call multiple times because it clears the stored window handle.
void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

// Purpose: Recover the `Win32Window` instance pointer stored on an HWND.
// Inputs: `window`.
// Returns: The associated `Win32Window*`.
// Side effects: None.
// Notes: Returns `nullptr` when the window has not been initialized with a runner instance.
Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

// Purpose: Attach a child HWND to the runner window and size it to the client area.
// Inputs: `content`.
// Returns: None.
// Side effects: Reparents the child window, resizes it, and moves keyboard focus.
// Notes: Used to host the Flutter view inside the top-level runner window.
void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

// Purpose: Return the current client-area rectangle for the native window.
// Inputs: None.
// Returns: The current client `RECT`.
// Side effects: None.
// Notes: Assumes the native window handle has already been created.
RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

// Purpose: Return the native window handle for the runner window.
// Inputs: None.
// Returns: The current `HWND`.
// Side effects: None.
// Notes: May be `nullptr` after destruction.
HWND Win32Window::GetHandle() {
  return window_handle_;
}

// Purpose: Configure whether closing this window should quit the whole application.
// Inputs: `quit_on_close`.
// Returns: None.
// Side effects: Updates the local close-handling flag.
// Notes: The Flutter runner enables this for its primary top-level window.
void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

// Purpose: Provide a default successful create hook for subclasses.
// Inputs: None.
// Returns: `true`.
// Side effects: None.
// Notes: Subclasses override this to perform additional setup after window creation.
bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

// Purpose: Provide a default destroy hook for subclasses.
// Inputs: None.
// Returns: None.
// Side effects: None.
// Notes: Subclasses override this to release resources before the HWND is destroyed.
void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

// Purpose: Update the window frame theme to match the current Windows app theme setting.
// Inputs: `window`.
// Returns: None.
// Side effects: Calls `DwmSetWindowAttribute` when the preference lookup succeeds.
// Notes: Uses the Windows personalize registry key to choose dark or light decorations.
void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
