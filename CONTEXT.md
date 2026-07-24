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
The session holds the current prepared resize as its layout truth for the interaction.
_Avoid_: Action coordinator, resize session, trigger session, ResizeContext

**Window Resize Execution**:
The operation that turns a selected window action, target window, display, and window state into the frame and state needed to apply the resize.
It owns session bootstrap (including a session-scoped layout frame snapshot when the window is stashed), mid-session transitions that reuse that snapshot without re-reading live window state, and commit (apply the current preparation, or re-prepare for immediate apply while inheriting the session layout snapshot).
_Avoid_: ResizeContext, frame calculation alone, resize request alone

**Prepared Resize**:
The immutable result of Window Resize Execution for one action on one window and display: the inputs and target frame ready to preview or apply.
During a Window Action Session (and grid mode), this is the layout truth; changing action or screen produces a new Prepared Resize rather than mutating the previous one.
_Avoid_: ResizeContext, mutable resize state, live window frame (when a session layout snapshot applies)
