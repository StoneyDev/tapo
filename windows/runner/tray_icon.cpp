#include "tray_icon.h"

#include "resource.h"

namespace {

constexpr UINT kIconId = 1;

// Menu labels treat '&' as a mnemonic marker: "Salon & Bureau" must stay
// literal.
std::wstring EscapeMnemonics(const std::wstring& label) {
  std::wstring escaped;
  escaped.reserve(label.size());
  for (wchar_t c : label) {
    if (c == L'&') {
      escaped += L'&';
    }
    escaped += c;
  }
  return escaped;
}

DWORD WindowsBuildNumber() {
  using RtlGetVersionFn = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
  if (!ntdll) {
    return 0;
  }
  auto rtl_get_version = reinterpret_cast<RtlGetVersionFn>(
      GetProcAddress(ntdll, "RtlGetVersion"));
  RTL_OSVERSIONINFOW info{};
  info.dwOSVersionInfoSize = sizeof(info);
  if (!rtl_get_version || rtl_get_version(&info) != 0) {
    return 0;
  }
  return info.dwBuildNumber;
}

}  // namespace

TrayIcon::TrayIcon(HWND owner, UINT callback_message)
    : owner_(owner), callback_message_(callback_message) {
  // Small icon size at the system DPI, as the notification area expects.
  icon_ = static_cast<HICON>(LoadImageW(
      GetModuleHandle(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
      LR_DEFAULTCOLOR));
  menu_owner_ = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", L"", WS_POPUP, 0,
                                0, 0, 0, nullptr, nullptr,
                                GetModuleHandle(nullptr), nullptr);
}

TrayIcon::~TrayIcon() {
  if (added_) {
    NOTIFYICONDATAW data = BaseData();
    Shell_NotifyIconW(NIM_DELETE, &data);
  }
  if (icon_) {
    DestroyIcon(icon_);
  }
  if (menu_owner_) {
    DestroyWindow(menu_owner_);
  }
}

NOTIFYICONDATAW TrayIcon::BaseData() const {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = owner_;
  data.uID = kIconId;
  return data;
}

bool TrayIcon::Show() {
  NOTIFYICONDATAW data = BaseData();
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  data.uCallbackMessage = callback_message_;
  data.hIcon = icon_;
  wcsncpy_s(data.szTip, tooltip_.c_str(), _TRUNCATE);

  // After an Explorer restart the old icon is gone; a stale entry would make
  // NIM_ADD fail, so clear it first.
  Shell_NotifyIconW(NIM_DELETE, &data);
  added_ = Shell_NotifyIconW(NIM_ADD, &data) == TRUE;
  if (!added_) {
    return false;
  }

  data.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &data);
  return true;
}

void TrayIcon::SetTooltip(const std::wstring& tooltip) {
  tooltip_ = tooltip;
  if (!added_) {
    return;
  }
  NOTIFYICONDATAW data = BaseData();
  data.uFlags = NIF_TIP | NIF_SHOWTIP;
  wcsncpy_s(data.szTip, tooltip_.c_str(), _TRUNCATE);
  Shell_NotifyIconW(NIM_MODIFY, &data);
}

void TrayIcon::ShowNotification(const std::wstring& title,
                                const std::wstring& message) {
  if (!added_) {
    return;
  }
  NOTIFYICONDATAW data = BaseData();
  data.uFlags = NIF_INFO;
  data.dwInfoFlags = NIIF_WARNING | NIIF_RESPECT_QUIET_TIME;
  wcsncpy_s(data.szInfoTitle, title.c_str(), _TRUNCATE);
  wcsncpy_s(data.szInfo, message.c_str(), _TRUNCATE);
  Shell_NotifyIconW(NIM_MODIFY, &data);
}

void TrayIcon::TakeForeground() {
  SetForegroundWindow(menu_owner_ ? menu_owner_ : owner_);
}

int TrayIcon::ShowMenu(const std::vector<MenuEntry>& entries, POINT anchor) {
  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return 0;
  }
  for (const MenuEntry& entry : entries) {
    if (entry.separator) {
      AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
      continue;
    }
    const UINT flags = MF_STRING | (entry.checked ? MF_CHECKED : MF_UNCHECKED) |
                       (entry.enabled ? MF_ENABLED : MF_GRAYED);
    AppendMenuW(menu, flags, static_cast<UINT_PTR>(entry.id),
                EscapeMnemonics(entry.label).c_str());
  }

  HWND menu_owner = menu_owner_ ? menu_owner_ : owner_;
  // Without this the menu would not close when clicking elsewhere.
  SetForegroundWindow(menu_owner);
  const UINT alignment = GetSystemMetrics(SM_MENUDROPALIGNMENT)
                             ? TPM_RIGHTALIGN
                             : TPM_LEFTALIGN;
  const int chosen = TrackPopupMenuEx(
      menu, alignment | TPM_BOTTOMALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD |
                TPM_NONOTIFY,
      anchor.x, anchor.y, menu_owner, nullptr);
  // Lets the menu close properly when it is dismissed (KB135788).
  PostMessage(menu_owner, WM_NULL, 0, 0);
  DestroyMenu(menu);
  return chosen;
}

void TrayIcon::UseSystemMenuTheme() {
  // Windows has no public API for dark Win32 menus. These uxtheme ordinals
  // (135 SetPreferredAppMode, 136 FlushMenuThemes) are the ones Explorer and
  // Notepad++ rely on; they exist from Windows 10 1903 (build 18362) on and
  // older builds simply keep light menus.
  if (WindowsBuildNumber() < 18362) {
    return;
  }
  HMODULE uxtheme =
      LoadLibraryExW(L"uxtheme.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (!uxtheme) {
    return;
  }
  using SetPreferredAppModeFn = int(WINAPI*)(int);
  using FlushMenuThemesFn = void(WINAPI*)();
  auto set_preferred_app_mode = reinterpret_cast<SetPreferredAppModeFn>(
      GetProcAddress(uxtheme, MAKEINTRESOURCEA(135)));
  auto flush_menu_themes = reinterpret_cast<FlushMenuThemesFn>(
      GetProcAddress(uxtheme, MAKEINTRESOURCEA(136)));
  constexpr int kAllowDark = 1;  // Follow the system app theme.
  if (set_preferred_app_mode) {
    set_preferred_app_mode(kAllowDark);
  }
  if (flush_menu_themes) {
    flush_menu_themes();
  }
  // uxtheme stays loaded on purpose: unloading it would drop the app mode.
}
