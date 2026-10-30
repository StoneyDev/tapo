#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kWindowTitle[] = L"Jolt";
constexpr wchar_t kSingleInstanceMutex[] = L"Local\\YannDeroues.Tapo";

// Passed by the "Lancer au démarrage" Run entry: start hidden in the tray.
constexpr char kMinimizedFlag[] = "--minimized";

// Asks the running instance to show its window.
void ActivateRunningInstance() {
  HWND running = Win32Window::FindExisting(kWindowTitle);
  if (!running) {
    return;
  }
  DWORD process_id = 0;
  ::GetWindowThreadProcessId(running, &process_id);
  ::AllowSetForegroundWindow(process_id);
  ::PostMessageW(running, FlutterWindow::ActivationMessage(), 0, 0);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One instance only (one tray icon): launching Jolt again just brings the
  // running window forward.
  HANDLE single_instance =
      ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutex);
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateRunningInstance();
    if (single_instance) {
      ::CloseHandle(single_instance);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool start_hidden =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                kMinimizedFlag) != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_hidden);
  // Centered on the work area once created (FlutterWindow::OnCreate).
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1000, 660);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance) {
    ::CloseHandle(single_instance);
  }
  return EXIT_SUCCESS;
}
