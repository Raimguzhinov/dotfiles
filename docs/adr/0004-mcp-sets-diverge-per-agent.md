# MCP server sets diverge per agent on purpose

The three agents carry different MCP server sets, which looks like drift. It is not: the agents have different roles, and their toolsets were shaped to match.

We decided the MCP sets **diverge intentionally** and rejected a shared MCP catalog with per-agent adapters:

- the main agent is the corporate-workhorse: corporate services (issue tracker, knowledge base, internal git);
- the backup agent mirrors the main agent's role as a fallback, so it keeps the same corporate set plus its own integrations;
- the third agent serves public personal projects and should not see corporate services at all.

A unified catalog would force corporate endpoints into the personal-project agent or carve out exceptions that recreate the per-agent sets. The explicit no is the point of this ADR: do not "fix" the divergence.
