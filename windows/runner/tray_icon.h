#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <windows.h>
#include <shellapi.h>

#include <string>
#include <vector>

// Notification area ("system tray") icon with a native context menu.
class TrayIcon {
 public:
  struct MenuEntry {
    int id = 0;
    std::wstring label;
    bool checked = false;
    bool enabled = true;
    bool separator = false;
  };

  // Mouse and keyboard events on the icon are sent to |owner| as
  // |callback_message|, with the event in LOWORD(lparam)
  // (NOTIFYICON_VERSION_4: NIN_SELECT, NIN_KEYSELECT, WM_CONTEXTMENU).
  TrayIcon(HWND owner, UINT callback_message);
  ~TrayIcon();

  TrayIcon(const TrayIcon&) = delete;
  TrayIcon& operator=(const TrayIcon&) = delete;

  // Adds the icon. Call again after Explorer restarts ("TaskbarCreated").
  bool Show();

  void SetTooltip(const std::wstring& tooltip);

  // Shown as a toast on Windows 10 and 11.
  void ShowNotification(const std::wstring& title, const std::wstring& message);

  // Gives the foreground to the menu's owner. Call it right when Explorer
  // reports the click: that is when Windows allows taking the foreground.
  void TakeForeground();

  // Shows |entries| at |anchor| (screen coordinates) and returns the chosen
  // id, or 0 if dismissed.
  int ShowMenu(const std::vector<MenuEntry>& entries, POINT anchor);

  // Makes context menus follow the Windows light/dark app theme.
  static void UseSystemMenuTheme();

 private:
  NOTIFYICONDATAW BaseData() const;

  HWND owner_;
  // Hidden window owning the context menu: activating it (required for the
  // menu to close on outside clicks) must not raise the main window.
  HWND menu_owner_ = nullptr;
  UINT callback_message_;
  HICON icon_ = nullptr;
  std::wstring tooltip_ = L"Tapo";
  bool added_ = false;
};

#endif  // RUNNER_TRAY_ICON_H_
