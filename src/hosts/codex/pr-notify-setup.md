**Notification setup**: pln-pr pulls the user back before every user-input wait and at completion over one channel on this host. This includes readiness, trust/recovery, fix decisions, and a CI watch that is truly stumped:

- **Local desktop notification**, via `"$_PLN_DIR/bin/pln-notify-desktop" "<message>"`. Self-gates on `notify_desktop` and no-ops on an unsupported platform, so call it unconditionally before every wait and at completion whenever `_PLN_DIR` is set.

There is no phone-push channel here and nothing to load for one; `notify_push` is ignored. Before every turn that waits for user input, fire the desktop notification **before** writing the user-facing text, never after — a trailing notify call gets dropped mid-turn.
