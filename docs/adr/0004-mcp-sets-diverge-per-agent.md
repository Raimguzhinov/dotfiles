# MCP server sets diverge per agent on purpose

The three agents carry different MCP server sets, which looks like drift. It is not: the sets follow two axes, the model perimeter and the per-agent project needs.

We decided the MCP sets **diverge intentionally** and rejected a shared MCP catalog with per-agent adapters:

- **Model perimeter.** The corporate endpoints (issue tracker, internal GitLab, knowledge base) live on the agents that run the corporate Protei models: the main agent (pi) and the third agent (opencode, personal projects on corporate models). The backup agent (claude-code) runs Anthropic models outside the corporate perimeter and sees no corporate endpoints at all.
- **Project needs.** pi additionally carries local services bound to the corporate uc project (postgres, chrome-devtools, uc-dev); claude-code carries its own integrations (huggingface, typst). opencode carries the corporate trio plus the shared utilities only.
- **Shared core.** context7, gh_grep, nixos, searxng and codebase_memory are the servers installed on all three agents. codebase_memory and mcp-nixos share one package across agents through `programs.harness` options.

A unified catalog would force corporate endpoints into the Anthropic-backed agent or carve out exceptions that recreate the per-agent sets. The explicit no is the point of this ADR: do not "fix" the divergence.
