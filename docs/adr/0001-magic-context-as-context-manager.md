# Magic Context as the context manager

Sessions of the main and backup agents used to stop at native compaction, and a home-grown context-hiding extension (context-keeper) masked secrets into compaction summaries. We decided to give **one** context manager per agent: Magic Context (cortexkit, same ecosystem as the already-accepted aft), installed in both the main and the backup agent with a **shared local store**, so memory pools across agents.

Considered options:

- **Keep context-keeper + native compaction** — the status quo; stops working the moment the agent needs long sessions.
- **pi-context-prune** — a second context manager alongside any other; the vendor states that two managers in one agent double-compress the context, so it was rejected as an addition.
- **Magic Context** — owns the context window end to end (native compaction is cancelled by the extension), persists memory in local SQLite, has a documented model split (in-session summarization vs offline consolidation) and zero telemetry.

Consequences:

- Model split is fixed by role, not by speed: **historian = small corporate model** (must keep up with the session), **dreamer = local model** (consolidates overnight; slowness is fine).
- Native compaction of the main agent is kept as a fallback: if the context manager fails closed (store unavailable), the context window is still bounded instead of erroring.
- Exact version pin is mandatory (release cadence of 1-3 days); upgrade is a conscious act.
- Fail-closed is accepted: a broken store makes sessions error loudly rather than silently lose memory.
