# Line Context

Line is a menu bar first macOS window management tool. This context defines product and settings-window language used by the app's native macOS experience work.

## Language

**Settings Window Host**:
The app-level surface responsible for presenting, focusing, closing, and restoring the settings window.
It routes every app entry point to the single controller-backed settings presenter while reusing the app-owned settings state.
_Avoid_: Settings state, preferences model

**Settings Window Provider**:
A narrow dependency that lets settings pages access the current settings `NSWindow` for native sheets and panels.
_Avoid_: Settings window manager, global window singleton

**Settings State**:
The user-interface state shared by settings pages, such as the selected settings tab and previewed window action.
_Avoid_: Window manager, settings window controller

**Permissions**:
The settings area that represents system capabilities Line needs before it can manage windows, such as Accessibility access.
_Avoid_: Advanced settings, onboarding

**Onboarding**:
The first-run guidance that explains required permissions and helps the user make Line operational.
_Avoid_: Settings window, permissions state

**Application Presentation**:
The app-level policy that controls whether Line behaves as a regular Dock app or an accessory/menu bar app.
_Avoid_: Settings window host, window state

**Window Action Session**:
The active interaction after Line opens in which the user selects, cycles, previews, and commits a window action.
_Avoid_: Action coordinator, resize session, trigger session

**Window Resize Execution**:
The window-management operation that turns a selected window action, target window, display, and current window state into the frame and state needed to apply the resize.
_Avoid_: ResizeContext, frame calculation, resize request
