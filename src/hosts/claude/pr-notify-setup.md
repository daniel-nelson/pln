**Notification setup**: run this before anything else, every invocation. pln-pr pulls the user back at two moments — a fix decision it can't make alone, and completion — over the same two channels `/pln` uses, each separately toggleable and both default on:

- **Phone push**, via the harness `PushNotification` tool. Gated on `notify_push`. Read `"$_PLN_DIR/bin/pln-config" get notify_push`; unless it prints `false`, push is on — call `ToolSearch` with query `select:PushNotification` **once now**, so the tool is loaded before the Step 4/Step 8 call sites need it (it is commonly a deferred tool). If it prints `false` (or `_PLN_DIR` is unset), don't load it and don't call it anywhere.
- **Local desktop notification**, via `"$_PLN_DIR/bin/pln-notify-desktop" "<message>"`. Self-gates on `notify_desktop` and no-ops on an unsupported platform, so call it unconditionally at the two sites whenever `_PLN_DIR` is set.

When notifications are on, fire them **before** writing the user-facing text at each of the two moments, never after — a trailing notify call gets dropped mid-turn.
