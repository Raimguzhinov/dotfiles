# No standalone runtime code in the repo; two named exceptions

The repo's rule: **no standalone TS/JS runtime files** and no patch chains longer than one line; home-grown agent runtime is only small inline blocks inside the Nix files, and everything else comes from version-pinned community packages. The original motivation was that demo-grade plugins from a blog repo rotted on every agent update.

Two deliberate exceptions, both substantial inline TS with **no community equivalent**:

- **protei-auto** — model routing between corporate models (speed-based pool switching, strict-model escalation on context overflow and plan mode, adaptive thinking level) plus the custom footer: pi's `setExtensionFooter` factory receives only `(ui, theme, footerData)`, while every value the footer renders (routed model, thinking level, context fill, tok/s, active tools, extension modes) already lives in the protei-auto closure, so a separate extension would need a data bridge for no functional gain;
- **gates** — per-edit diagnostics on added lines, an anti-cheat snapshot of test files, and the run-gates tool.

Consequences:

- These two blocks are maintained by hand against agent updates, like the build-time patches; that cost was accepted consciously.
- Any new home-grown runtime block must justify the same way (no maintained equivalent) or be rejected in favor of a community package.
- Small glue blocks that stay under the one-block rule (e.g. `todo-reminder`) are inline code, not exceptions.
