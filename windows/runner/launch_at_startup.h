#ifndef RUNNER_LAUNCH_AT_STARTUP_H_
#define RUNNER_LAUNCH_AT_STARTUP_H_

// "Lancer au démarrage": a per-user Run key entry that starts the app hidden
// in the tray (--minimized). No admin rights needed.
namespace launch_at_startup {

// False when the entry is missing or disabled in Task Manager's Startup tab.
bool IsEnabled();

// Returns false when the registry refused the change.
bool SetEnabled(bool enabled);

// Points an existing entry at the current executable when the registered one
// no longer exists (portable app folder moved). Another copy of the app, such
// as a debug build, never takes over a valid entry.
void RefreshPath();

}  // namespace launch_at_startup

#endif  // RUNNER_LAUNCH_AT_STARTUP_H_
