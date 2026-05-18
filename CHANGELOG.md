# Changelog

## 1.0.0 — 2026-05-18

### Added

- **`/pln`** — two-phase personal planning workflow. Interview phase resolves all per-item questions into a master plan; implementation phase executes one item at a time. No interleaving, ever.
- **`/plnify gstack`** — one-time installer that appends pln's interaction discipline (one-question-at-a-time rules + exploratory-mode posture) to `~/.claude/CLAUDE.md` for gstack planning skills. Shows a full preview and requires explicit approval before writing.
- **`./setup`** — symlinks the `plnify` sub-skill into the parent `skills/` directory on install.
