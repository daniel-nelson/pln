**Notification setup**: pln-pr pulls the user back at two moments — a fix decision it can't make alone, and completion — over one channel on this host. Step 9's CI watch loop reuses these same two moments for its own resolution (green/undraft is a completion, "truly stumped" is a fix decision) rather than introducing a third:

- **Local desktop notification**, via `"$_PLN_DIR/bin/pln-notify-desktop" "<message>"`. Self-gates on `notify_desktop` and no-ops on an unsupported platform, so call it unconditionally at the two sites whenever `_PLN_DIR` is set.

There is no phone-push channel here and nothing to load for one; `notify_push` is ignored. Fire the desktop notification **before** writing the user-facing text at each of the two moments, never after — a trailing notify call gets dropped mid-turn.
