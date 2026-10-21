# Permission model: operation classification, one shared source

Two gate systems ran stacked in pi: `@aliou/pi-guardrails` (a path x tool matrix with `readOnly` / `writeOnly` / `noDelete` policies and bash regex patterns) and `pi-permission-system` 0.8.0 (a per-tool allowlist), plus an activation-time `sed` patch on top of the latter. The model protected *paths from tools*, not *operations*, so it blocked legitimate work (`gh api` reads, `git log` in other repos), missed destructive commands no rule named, and nobody could say which rule would fire.

We decided to consolidate on one maintained package, `@gotgenes/pi-permission-system` (the maintained fork of MasuRii's `pi-permission-system`), and to classify **operations**: read-only passes, destructive is denied with a reason, the middle asks once per session.

The rule source is a single Nix option, `programs.harness.permissions` in `harness.nix`. Each agent module renders it into its native schema:

- pi: `~/.pi/agent/extensions/pi-permission-system/config.json` (surfaces `*`, `bash`, `path`, `path_write`, `external_directory_read`, `external_directory_write`, plus `commandEffects` declarations);
- opencode: the native `permission` map in `opencode.json` (surfaces `read`, `edit`, `bash`, `external_directory`).

The deterministic layer (allow / ask / deny by command and path pattern) is in place first. The model classifier (`@gotgenes/pi-permission-classifier`, wired via `authorizerChain`) is a later stage, to be added when ask-noise from middle commands becomes a problem.

Considered options:

- **Keep the path x tool matrix** (`@aliou/pi-guardrails`) — opacity and false blocks remain; the package is less actively maintained than the fork.
- **Home-grown claude-code-style hooks** (a bash wrapper that classifies commands) — rejected by ADR-0005: a standalone runtime block with a maintained community equivalent.
- **Path surfaces only, no bash surface** — protects files but not operations; a destructive `bash` command naming no protected path would pass.

Consequences:

- `bash` default is **ask** (was allow): middle commands ask once, and the session approval covers repeats. `sudo *` is pinned to ask explicitly.
- Read commands are declared in `commandEffects` (`git log/show/status/diff/blame/ls-files/describe/rev-parse`, `nix`, `jq`), so their path arguments consult the read surface and stay silent outside cwd. `git add` and `git commit` were later declared read as well: the pathspec is read, the write goes to `.git`, and both are routine working-set commands in the shared bash allowlist.
- Secrets (`.env`, `~/.ssh`, `~/.gnupg`, keys, `*.pem`, dumps, ...) are denied in both directions on all tools and in bash.
- `~/.pi`, `~/.config`, lockfiles, build output and repo meta-files (README, `.git`, CI, Dockerfiles) are write-denied with a reason; reading stays free.
- No activation-time `sed` patch on the permission system: the package is taken stock from npm. (The remaining ADR-0003 legacy exceptions were later migrated to build time, 3ca31e8, so none remain.)
- `nixpkgs` `formats.json` emits keys in **alphabetical** order, and the package resolves patterns last-match-wins: patterns are written so the intended winner is also the alphabetically last match (`*` sorts first, so the default never overrides specifics).
- opencode has no directional path surfaces, so its `external_directory` stays bidirectional: reads outside the cwd ask there, while pi's `external_directory_read` is allow. Accepted for the reserve agent.
- pi's rendered config enables `yoloMode`: every `ask` is rewritten to a standing `allow` (origin `yolo`, recorded in the review log) while `deny` rules are untouched; opencode has no such knob, so its asks prompt there.
