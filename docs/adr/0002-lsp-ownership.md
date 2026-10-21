# LSP ownership: one server owns a language per agent

It was unclear which layer answers a language's LSP needs: the agent's native LSP extension or the gopls MCP server. A behavioral test in a real Go project showed the agent spontaneously uses search + native LSP diagnostics and never calls MCP tools on its own, so MCP tools are second-class for autonomous work.

We decided: **LSP ownership** is a table, "language → owning server", covering the two agents that run aft (pi, opencode). The shared aft config's disabled-LSP list is **generated from the table's keys**: every language in the table is served by the agent's native LSP layer, not by aft, and the aft config stays shared by design — per-agent aft configs were rejected because the whole point of aft is that it is shared. claude-code does not run aft; its LSP servers are declared in `programs.claude-code.lspServers` and sit outside the table by design. The gopls MCP server was removed (f493b54) once the native extension served the same language; no agent has an LSP-via-MCP installed. Languages owned by nobody appear as empty rows (e.g. java: no jdtls binary is installed anywhere).

Consequences:

- "Which LSP answers for language X in agent Y?" is answered by reading the table, not by memory or by trial.
- A declaration/runtime mismatch (e.g. Go actually served by the native extension but missing from its declared coverage) is a bug to fix, not a nuance.
