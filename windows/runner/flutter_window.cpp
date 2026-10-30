#include "flutter_window.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

#include <algorithm>
#include <cstdint>
#include <cwchar>
#include <optional>
#include <string>
#include <utility>

#include "flutter/generated_plugin_registrant.h"
#include "launch_at_startup.h"
#include "utils.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kShowMenuMessage = WM_APP + 2;
constexpr UINT kQuitMessage = WM_APP + 3;

constexpr UINT_PTR kTrayRetryTimer = 1;
constexpr UINT kTrayRetryIntervalMs = 2000;
// After ~30 s without a tray icon, show the window of a hidden start.
constexpr int kTrayRetriesBeforeShowing = 15;

// Outer window size limits (logical pixels) that keep the client area wide
// enough for the desktop layout (>= 720 px).
constexpr int kMinWidth = 760;
constexpr int kMinHeight = 560;

constexpr int kFallbackOpenId = 1;
constexpr int kFallbackQuitId = 2;

template <typename T>
const T* Lookup(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : std::get_if<T>(&it->second);
}

// Menu entries as sent by DesktopShell.showTrayMenu.
std::vector<TrayIcon::MenuEntry> ParseMenu(const EncodableList& list) {
  std::vector<TrayIcon::MenuEntry> entries;
  for (const EncodableValue& value : list) {
    const auto* map = std::get_if<EncodableMap>(&value);
    if (!map) {
      continue;
    }
    TrayIcon::MenuEntry entry;
    if (Lookup<bool>(*map, "separator")) {
      entry.separator = true;
    } else {
      const auto* id = Lookup<int32_t>(*map, "id");
      const auto* label = Lookup<std::string>(*map, "label");
      const auto* checked = Lookup<bool>(*map, "checked");
      const auto* enabled = Lookup<bool>(*map, "enabled");
      if (!id || !label) {
        continue;
      }
      entry.id = *id;
      entry.label = Utf16FromUtf8(*label);
      entry.checked = checked && *checked;
      entry.enabled = !enabled || *enabled;
    }
    entries.push_back(std::move(entry));
  }
  return entries;
}

// Centers |hwnd| on its monitor's work area, shrinking it on small screens.
void CenterOnWorkArea(HWND hwnd) {
  RECT window{};
  GetWindowRect(hwnd, &window);
  MONITORINFO monitor{};
  monitor.cbSize = sizeof(monitor);
  GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY), &monitor);
  const RECT& work = monitor.rcWork;
  const LONG width =
      std::min(window.right - window.left, work.right - work.left);
  const LONG height =
      std::min(window.bottom - window.top, work.bottom - work.top);
  SetWindowPos(hwnd, nullptr, work.left + (work.right - work.left - width) / 2,
               work.top + (work.bottom - work.top - height) / 2, width, height,
               SWP_NOZORDER | SWP_NOACTIVATE);
}

// NOTIFYICON_VERSION_4 passes the menu anchor point in wParam.
POINT AnchorFrom(WPARAM wparam) {
  POINT anchor{};
  anchor.x = static_cast<short>(LOWORD(wparam));
  anchor.y = static_cast<short>(HIWORD(wparam));
  return anchor;
}

// Broadcast by Explorer when it (re)starts: the tray icon must be re-added.
UINT TaskbarCreatedMessage() {
  static const UINT message = RegisterWindowMessageW(L"TaskbarCreated");
  return message;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             bool start_hidden)
    : project_(project), start_hidden_(start_hidden) {}

FlutterWindow::~FlutterWindow() {}

// static
UINT FlutterWindow::ActivationMessage() {
  static const UINT message =
      RegisterWindowMessageW(L"YannDeroues.Tapo.ShowWindow");
  return message;
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  CenterOnWorkArea(GetHandle());
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

  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      flutter_controller_->engine()->messenger(), "tapo/desktop",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const MethodCall& call, std::unique_ptr<MethodResult> result) {
        HandleMethodCall(call, std::move(result));
      });

  TrayIcon::UseSystemMenuTheme();
  tray_ = std::make_unique<TrayIcon>(GetHandle(), kTrayMessage);
  if (!tray_->Show()) {
    SetTimer(GetHandle(), kTrayRetryTimer, kTrayRetryIntervalMs, nullptr);
  }
  launch_at_startup::RefreshPath();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Launched at startup: stay in the tray until the user opens the window.
    if (!start_hidden_) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  tray_ = nullptr;
  channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Closing (X, Alt+F4) only hides the window to the tray. Handled before
  // Flutter so that its exit request flow never sees it.
  if (message == WM_CLOSE && !quitting_) {
    HideToTray();
    return 0;
  }
  // Registered messages are 0 if registration failed: never match WM_NULL.
  const UINT activation_message = ActivationMessage();
  if (activation_message != 0 && message == activation_message) {
    ShowAndFocus();
    return 0;
  }
  const UINT taskbar_created_message = TaskbarCreatedMessage();
  if (taskbar_created_message != 0 && message == taskbar_created_message) {
    if (tray_ && !tray_->Show()) {
      SetTimer(hwnd, kTrayRetryTimer, kTrayRetryIntervalMs, nullptr);
    }
    return 0;
  }
  switch (message) {
    case kTrayMessage:
      HandleTrayEvent(LOWORD(lparam), wparam);
      return 0;
    case kShowMenuMessage:
      ShowQueuedMenu();
      return 0;
    case kQuitMessage:
      Quit();
      return 0;
    case WM_TIMER:
      if (wparam == kTrayRetryTimer) {
        RetryTrayIcon();
        return 0;
      }
      break;
  }

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
    case WM_GETMINMAXINFO: {
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const int dpi = static_cast<int>(FlutterDesktopGetDpiForMonitor(
          MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)));
      info->ptMinTrackSize.x = MulDiv(kMinWidth, dpi, USER_DEFAULT_SCREEN_DPI);
      info->ptMinTrackSize.y = MulDiv(kMinHeight, dpi, USER_DEFAULT_SCREEN_DPI);
      return 0;
    }
    case WM_SETTINGCHANGE:
      // Light/dark app theme switched in the Windows settings.
      if (lparam && wcscmp(reinterpret_cast<const wchar_t*>(lparam),
                           L"ImmersiveColorSet") == 0) {
        TrayIcon::UseSystemMenuTheme();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::HandleMethodCall(const MethodCall& call,
                                     std::unique_ptr<MethodResult> result) {
  const std::string& method = call.method_name();
  const EncodableValue* arguments = call.arguments();

  if (method == "showTrayMenu") {
    const auto* entries =
        arguments ? std::get_if<EncodableList>(arguments) : nullptr;
    if (!entries) {
      result->Error("bad_arguments", "Expected a list of menu entries");
      return;
    }
    QueueMenu(ParseMenu(*entries), /*from_dart=*/true);
    result->Success();
  } else if (method == "setTrayTooltip") {
    const auto* tooltip =
        arguments ? std::get_if<std::string>(arguments) : nullptr;
    if (tooltip && tray_) {
      tray_->SetTooltip(Utf16FromUtf8(*tooltip));
    }
    result->Success();
  } else if (method == "showNotification") {
    const auto* map = arguments ? std::get_if<EncodableMap>(arguments) : nullptr;
    const auto* title = map ? Lookup<std::string>(*map, "title") : nullptr;
    const auto* text = map ? Lookup<std::string>(*map, "message") : nullptr;
    if (title && text && tray_) {
      tray_->ShowNotification(Utf16FromUtf8(*title), Utf16FromUtf8(*text));
    }
    result->Success();
  } else if (method == "showWindow") {
    ShowAndFocus();
    result->Success();
  } else if (method == "quit") {
    result->Success();
    // Quitting destroys the engine: never do it inside its own callback.
    PostMessage(GetHandle(), kQuitMessage, 0, 0);
  } else if (method == "getLaunchAtStartup") {
    result->Success(EncodableValue(launch_at_startup::IsEnabled()));
  } else if (method == "setLaunchAtStartup") {
    const auto* enabled = arguments ? std::get_if<bool>(arguments) : nullptr;
    if (!enabled) {
      result->Error("bad_arguments", "Expected a bool");
    } else if (launch_at_startup::SetEnabled(*enabled)) {
      result->Success();
    } else {
      result->Error("registry", "Could not update the startup entry");
    }
  } else {
    result->NotImplemented();
  }
}

void FlutterWindow::HandleTrayEvent(UINT event, WPARAM wparam) {
  switch (event) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
      ShowAndFocus();
      break;
    case WM_CONTEXTMENU:
      if (!channel_ || !tray_) {
        break;
      }
      menu_anchor_ = AnchorFrom(wparam);
      tray_->TakeForeground();
      // Dart refreshes the plugs, then answers with "showTrayMenu". If it
      // cannot (still starting), a minimal native menu keeps the app usable.
      channel_->InvokeMethod(
          "trayMenuRequested", nullptr,
          std::make_unique<flutter::MethodResultFunctions<EncodableValue>>(
              nullptr,
              [this](const std::string&, const std::string&,
                     const EncodableValue*) { QueueFallbackMenu(); },
              [this]() { QueueFallbackMenu(); }));
      break;
  }
}

void FlutterWindow::QueueMenu(std::vector<TrayIcon::MenuEntry> entries,
                              bool from_dart) {
  queued_menu_ = std::move(entries);
  queued_menu_from_dart_ = from_dart;
  PostMessage(GetHandle(), kShowMenuMessage, 0, 0);
}

void FlutterWindow::QueueFallbackMenu() {
  std::vector<TrayIcon::MenuEntry> entries(2);
  entries[0].id = kFallbackOpenId;
  entries[0].label = L"Ouvrir Jolt";
  entries[1].id = kFallbackQuitId;
  entries[1].label = L"Quitter";
  QueueMenu(std::move(entries), /*from_dart=*/false);
}

void FlutterWindow::ShowQueuedMenu() {
  if (!tray_ || queued_menu_.empty()) {
    return;
  }
  const std::vector<TrayIcon::MenuEntry> entries = std::move(queued_menu_);
  queued_menu_.clear();
  const bool from_dart = queued_menu_from_dart_;

  const int chosen = tray_->ShowMenu(entries, menu_anchor_);
  if (chosen == 0) {
    return;
  }
  if (from_dart) {
    if (channel_) {
      channel_->InvokeMethod("trayMenuItemSelected",
                             std::make_unique<EncodableValue>(chosen));
    }
  } else if (chosen == kFallbackOpenId) {
    ShowAndFocus();
  } else if (chosen == kFallbackQuitId) {
    Quit();
  }
}

void FlutterWindow::RetryTrayIcon() {
  HWND hwnd = GetHandle();
  if (tray_ && tray_->Show()) {
    KillTimer(hwnd, kTrayRetryTimer);
    return;
  }
  // Never leave a hidden start without any way back in.
  if (++tray_retries_ == kTrayRetriesBeforeShowing && !IsWindowVisible(hwnd)) {
    ShowAndFocus();
  }
}

void FlutterWindow::HideToTray() {
  // Hiding the top-level window alone leaves the engine "inactive", still
  // drawing frames. A 0x0 view is what reports the app as hidden (like a
  // minimized window), so nothing renders while it sits in the tray.
  if (flutter_controller_) {
    MoveWindow(flutter_controller_->view()->GetNativeWindow(), 0, 0, 0, 0,
               FALSE);
  }
  ShowWindow(GetHandle(), SW_HIDE);
}

void FlutterWindow::ShowAndFocus() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  if (IsIconic(hwnd)) {
    // WM_SIZE lays the view out again.
    ShowWindow(hwnd, SW_RESTORE);
  } else {
    if (flutter_controller_) {
      // Undo HideToTray's 0x0 view before showing the window.
      const RECT frame = GetClientArea();
      MoveWindow(flutter_controller_->view()->GetNativeWindow(), frame.left,
                 frame.top, frame.right - frame.left, frame.bottom - frame.top,
                 TRUE);
    }
    ShowWindow(hwnd, SW_SHOW);
  }
  SetForegroundWindow(hwnd);
}

void FlutterWindow::Quit() {
  quitting_ = true;
  // WM_DESTROY tears down Flutter and the tray icon, then ends the message
  // loop (SetQuitOnClose).
  DestroyWindow(GetHandle());
}
