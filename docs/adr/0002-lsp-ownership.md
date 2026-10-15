# LSP ownership: one server owns a language per agent

It was unclear which layer answers a language's LSP needs: the agent's native LSP extension or the gopls MCP server. A behavioral test in a real Go project showed the agent spontaneously uses search + native LSP diagnostics and never calls MCP tools on its own, so MCP tools are second-class for autonomous work.

We decided: **LSP ownership** is a table, "language → owning server", per agent. Go is owned by the native LSP extension in the main agent (not by gopls MCP). gopls MCP stays installed in both agents as a supplementary path (it is first-class for agents that drive MCP natively, like the backup agent). The shared aft config's disabled-LSP list is **generated from the ownership table**; its content does not change, and the aft config stays shared by design — per-agent aft configs were rejected because the whole point of aft is that it is shared.

Consequences:

- "Which LSP answers for language X in agent Y?" is answered by reading the table, not by memory or by trial.
- A declaration/runtime mismatch (e.g. Go actually served by the native extension but missing from its declared coverage) is a bug to fix, not a nuance.
