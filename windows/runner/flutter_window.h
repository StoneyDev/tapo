#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <vector>

#include "tray_icon.h"
#include "win32_window.h"

// A window hosting the Flutter view that lives on in the tray: closing it
// only hides it, "Quitter" in the tray menu exits the app. Talks to Dart
// through the "jolt/desktop" channel (lib/services/desktop_shell.dart).
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // With |start_hidden| the window stays in the tray until it is opened.
  FlutterWindow(const flutter::DartProject& project, bool start_hidden);
  virtual ~FlutterWindow();

  // Posted by a second launch to bring this instance's window forward.
  static UINT ActivationMessage();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  using MethodCall = flutter::MethodCall<flutter::EncodableValue>;
  using MethodResult = flutter::MethodResult<flutter::EncodableValue>;

  void HandleMethodCall(const MethodCall& call,
                        std::unique_ptr<MethodResult> result);
  void HandleTrayEvent(UINT event, WPARAM wparam);

  // Menus open from a posted message, never from inside a channel callback.
  // Choices from a |from_dart| menu go back to Dart; the fallback menu (used
  // while Dart cannot answer) is handled here.
  void QueueMenu(std::vector<TrayIcon::MenuEntry> entries, bool from_dart);
  void QueueFallbackMenu();
  void ShowQueuedMenu();

  // Explorer can be busy at login and refuse the icon: retry on a timer.
  void RetryTrayIcon();

  void HideToTray();
  void ShowAndFocus();
  void Quit();

  // The project to run.
  flutter::DartProject project_;

  bool start_hidden_;
  bool quitting_ = false;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<TrayIcon> tray_;
  int tray_retries_ = 0;
  std::vector<TrayIcon::MenuEntry> queued_menu_;
  bool queued_menu_from_dart_ = false;
  // Where the tray was clicked; menus open there (keyboard included).
  POINT menu_anchor_{};
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
