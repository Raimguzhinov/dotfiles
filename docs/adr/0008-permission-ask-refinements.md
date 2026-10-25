# Permission: meta-files and git checkout ask, agent skill store writable

ADR-0006 write-denied repo meta-files (README, Dockerfiles, docker-compose, CI) on all tools. In practice the deny fired in the agent's own working repo during ordinary development (editing a README or a compose file is the task, not an anomaly) and dead-ended the session: the agent handed the command to the human, who then re-ran it by hand and hit a shell pitfall the agent would not have. The same class of pattern, `*.env.*`, denied *reading* `.env.example` — a file that contains no secrets by definition — and blocked read-only `docker compose --env-file .env.example config`. `git checkout` and `git restore` were denied wholesale, but branch switching is routine work and only the `--` overload of `checkout` discards changes. And `~/.pi/*` write-deny blocked the agent from writing its own skill store at `~/.pi/agent/skills/`, while the shared store `~/.agents/skills` stayed writable.

Decision:

- **Meta-files: deny → ask.** Deleting or overwriting a repo meta-file is a human-confirmation operation, not a hard boundary. Under pi's `yoloMode` the ask rewrites to a standing allow and lands in the review log (ADR-0006); under opencode it prompts. Reading was already free and stays free.
- **`.env.example`: allowed to read.** New shared option `secretsExceptions` (default `[ "*.env.example" ]`) renders allow rules after the secret denies; on pi the engine resolves last-match-wins over alphabetically sorted keys, and `*.env.example` sorts after `*.env.*`, so the exception wins.
- **`git checkout` / `git restore`: deny → ask.** Both commands are ordinary work (branch switch, unstage) and only destructive in one overload. `git checkout -- *` stays denied; the shared system prompt steers branch switching to `git switch` (already allowed), so the ask surface sees discards, not routine switches. Residual: `git checkout -f` can also discard and stays covered by the ask, not the deny.
- **`~/.pi/agent/skills/`: write allowed.** New shared option `protectedWriteExceptions` (default `[ "~/.pi/agent/skills/*" ]`) overrides the `~/.pi/*` write-deny: the agent's own skill store is its working space. The shared store `~/.agents/skills` is the opposite: `switch` updates it from upstream, so `~/.agents` and `~/.agents/*` are in `protectedWritePatterns` and the agent only reads it. On pi the exception pattern sorts after the blanket one, so it wins; on opencode it is appended after the blanket deny (last-match-wins in array order).
- **Secrets and protected-write patterns stay deny.** An ask on a real `.env` would train reflexive approval and turn the only hard boundary into a formality; `/etc/*`, lockfiles and build artifacts are never a legitimate write target.

Considered:

- **Scope the patterns to the live core checkout** — fixes the observed case but hardcodes one repo's layout into a global model; the meta-file pain is general.
- **Blanket ask on all three classes** — rejected: ask must stay the "middle" class of the operation classification, not the default.

Consequences:

- The meta-file reason text renders on opencode only: pi's permissions schema has no ask-with-reason (a map value is a plain state string or a `deny` object carrying the reason), so pi renders a bare `ask` whose prompt is generic.
- `pi.nix` and `opencode.nix` render the same shared option, so both harnesses move together; the opencode array keeps its last-match-wins order (specific entries appended after the broad denies).
- Adding a new non-secret file shape (e.g. `.env.sample`) is a one-line edit to `secretsExceptions`, not a pattern surgery on `*.env.*`.
