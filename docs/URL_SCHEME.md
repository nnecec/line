# URL scheme

Line registers `line://` for local window automation. It does not register the upstream `loop://` scheme because that could conflict with an installed copy of Loop.

Any local process that can open a URL can request these commands. There is no caller authentication or confirmation prompt. Do not expose the scheme as a network service or use untrusted input to construct a Line URL.

Commands act on the current target window and require Line to have Accessibility permission.

## Direction commands

```text
line://direction/left
line://direction/right
line://direction/top
line://direction/bottom
line://direction/maximize
line://direction/center
```

## Screen commands

```text
line://screen/next
line://screen/previous
line://screen/left
line://screen/right
line://screen/top
line://screen/bottom
```

## Named actions and keybinds

```text
line://action/maximize
line://action/leftHalf
line://keybind/myCustomLayout
```

Names with spaces or non-ASCII characters must be URL encoded.

## Discovery

```text
line://list/actions
line://list/keybinds
line://list/all
```

From Terminal, use `open`:

```bash
open "line://direction/right"
open "line://list/actions"
```

Commands and parameters are case-insensitive. Invalid or missing parameters produce diagnostic output instead of applying a fallback action.
