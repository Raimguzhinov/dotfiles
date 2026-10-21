# Glossary

NixOS dotfiles as a flake: hosts, desktop, tools, editors, services, and a coding-agent harness.

## Machine

**host**:
A concrete machine with its own hardware; a directory in `modules/hosts/`, named after nixos-hardware (`dell-xps-13-9320`).
_Avoid_: host config, system, machine (as a module name)

**feature module**:
A module that publishes one tool as a home-manager module and, where a standalone build makes sense, also as a package with its config baked in.
_Avoid_: tool module, package module

## Harness

### Agents

**harness**:
The cluster of feature modules that configures the machine's coding agents and the shared infrastructure under them (code search, LSP, model endpoints).
_Avoid_: agent setup, tools cluster, plugins

**main agent**:
The agent for everyday corporate coding (currently pi).
_Avoid_: primary, "the main pi"

**backup agent**:
A corporate agent interchangeable with the main agent for the same tasks (currently opencode).
_Avoid_: secondary, "the second one", alternative

**personal agent**:
The agent for pet projects, public and private, with no access to corporate infrastructure (currently claude).
_Avoid_: pet agent

### Code intelligence

**LSP ownership**:
Binding a language to the single server that owns it in a given agent. LSP priority is read from this table, not from memory.
_Avoid_: LSP priority, LSP coverage

**aft**:
Indexed code search shared by the main and backup agents. Its config is shared; per-agent configs are not introduced.
_Avoid_: code search, index

**semantic search**:
Code search by the meaning of the query, without an exact name.
_Avoid_: meaning search, fuzzy search

**semantic backend**:
The model that builds embeddings for semantic search: a local ONNX model or a corporate model.
_Avoid_: embedding model, embedder

### Context and memory

**native compaction**:
The agent's own built-in management of its context window. It bounds the window and loses accumulated knowledge.
_Avoid_: auto-compact, built-in compaction

**context manager**:
The owner of the agent's context window and of long-term memory that outlives the session. One per agent.
_Avoid_: compaction, summarizer, "context management"

**historian**:
A small model that keeps up with the session and turns it into memory.
_Avoid_: summarizer, background model

**dreamer**:
A model that consolidates memory while the machine is idle.
_Avoid_: consolidator

**corporate model**:
A model reached through the corporate proxy (Protei).
_Avoid_: Protei (as the name of a model class), remote model

**local model**:
A model served on the machine itself.
_Avoid_: llama.cpp (as the name of a model class), local LLM

**handoff skill**:
Matt Pocock's skill (`~/.agents/skills/handoff`) that defines the handoff document: where to save it, what to include, what to reference by path instead of copy. The user invokes it as `/skill:handoff`; the agent never invokes it, but writes the document following it when the work is about to travel.
_Avoid_: handoff command, handoff tool

**handoff document**:
A document written per the handoff skill that carries in-flight work or a question to a session the current context cannot reach. Written for a stated purpose, stored in the temp directory, other artifacts referenced by path and never copied.
_Avoid_: context dump, session export, compaction backup

### System prompt

**shared fragment**:
A part of the system prompt common to all agents; delivered to each.
_Avoid_: common prompt

**per-agent section**:
A part of the system prompt specific to one agent.
_Avoid_: override, add-on section

### pi

**virtual model**:
A model name that is not a physical model but a slot routing to one. The agent's logic picks the concrete model by thinking level and task (e.g. auto → agent_proteya).
_Avoid_: model alias, model selector, "the auto model"

**routed model**:
The physical model a virtual model currently resolves to and that actually runs inference. In pi it lives in session.routedModel.
_Avoid_: target model, resolved model, "the real model"

**footer**:
pi's status line at the bottom of the screen. A custom setExtensionFooter fully replaces the native footer (which would show the git branch and extension statuses), so extension statuses have to be drawn by hand.
_Avoid_: statusline, status bar
