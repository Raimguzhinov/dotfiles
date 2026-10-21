# Bounded context over unbounded (reject the context manager)

Long sessions compact constantly. After a home-grown context-keeper extension (masking secrets out of compaction summaries), we trialed Magic Context (cortexkit) as the full context manager: it keeps every chunk of session knowledge without compaction. In practice the un-compacted window accumulated mostly low-value material, and whenever the model hallucinated or latched onto a side task the context manager preserved that too. The dilution pushed the essential signal to a negligible share and the model degraded.

Decision: **no context manager.** The agent's window stays owned by **native compaction** — bounded, discards knowledge, keeps the signal concentrated. We accept losing some knowledge in exchange for a focused window.

Considered:
- **Magic Context** — unbounded, retains everything. Rejected: unfiltered memory dilutes the signal in long sessions. The failure mode is signal dilution, not memory shortage.
- **Native compaction** — bounded, loses knowledge, keeps signal. Chosen.

Consequences:
- The real open requirement is *selective* context (keep the essence, drop the noise). Neither native compaction (drops everything) nor a context manager (keeps everything) provides it. Tracked as a separate open requirement, not folded into this decision.
- Do not re-propose a context manager on "we need more memory" grounds. More unfiltered memory makes the dilution worse.
