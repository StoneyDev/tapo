#include "launch_at_startup.h"

#include <windows.h>

#include <string>

namespace launch_at_startup {
namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
// Task Manager's Startup tab records its enabled/disabled toggle here.
constexpr wchar_t kStartupApprovedKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved"
    L"\\Run";
// Named before the app became Jolt, kept so that existing entries still match
// (RefreshPath then points them at the renamed executable).
constexpr wchar_t kValueName[] = L"Tapo";

std::wstring CurrentCommand() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = 0;
  while (true) {
    length = GetModuleFileNameW(nullptr, path.data(),
                                static_cast<DWORD>(path.size()));
    if (length < path.size()) {
      break;
    }
    path.resize(path.size() * 2);
  }
  path.resize(length);
  return L"\"" + path + L"\" --minimized";
}

bool ReadRunCommand(std::wstring* command) {
  DWORD size = 0;
  if (RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName, RRF_RT_REG_SZ,
                   nullptr, nullptr, &size) != ERROR_SUCCESS) {
    return false;
  }
  std::wstring value(size / sizeof(wchar_t), L'\0');
  if (RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName, RRF_RT_REG_SZ,
                   nullptr, value.data(), &size) != ERROR_SUCCESS) {
    return false;
  }
  // Drop the terminating null character(s) included in |size|.
  value.resize(wcslen(value.c_str()));
  *command = value;
  return true;
}

// The executable in a Run command: "C:\...\jolt.exe" --minimized.
std::wstring ExecutableOf(const std::wstring& command) {
  if (command.empty() || command[0] != L'"') {
    return command;
  }
  const size_t end = command.find(L'"', 1);
  return end == std::wstring::npos ? command.substr(1)
                                   : command.substr(1, end - 1);
}

bool WriteRunCommand() {
  const std::wstring command = CurrentCommand();
  const DWORD size =
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t));
  return RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, kValueName, REG_SZ,
                         command.c_str(), size) == ERROR_SUCCESS;
}

bool DisabledInTaskManager() {
  BYTE data[12] = {};
  DWORD size = sizeof(data);
  if (RegGetValueW(HKEY_CURRENT_USER, kStartupApprovedKey, kValueName,
                   RRF_RT_REG_BINARY, nullptr, data, &size) != ERROR_SUCCESS) {
    return false;
  }
  // 0x02 (or 0x06) means enabled, 0x03 (or 0x07) disabled.
  return size > 0 && (data[0] & 1) != 0;
}

bool DeleteValue(const wchar_t* key) {
  const LSTATUS status =
      RegDeleteKeyValueW(HKEY_CURRENT_USER, key, kValueName);
  return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
}

}  // namespace

bool IsEnabled() {
  std::wstring command;
  return ReadRunCommand(&command) && !DisabledInTaskManager();
}

bool SetEnabled(bool enabled) {
  // Turning it on from the app overrides an earlier Task Manager "disable".
  DeleteValue(kStartupApprovedKey);
  return enabled ? WriteRunCommand() : DeleteValue(kRunKey);
}

void RefreshPath() {
  std::wstring command;
  if (ReadRunCommand(&command) &&
      GetFileAttributesW(ExecutableOf(command).c_str()) ==
          INVALID_FILE_ATTRIBUTES) {
    WriteRunCommand();
  }
}

}  // namespace launch_at_startup
