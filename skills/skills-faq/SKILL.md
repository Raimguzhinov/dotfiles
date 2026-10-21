---
name: skills-faq
description: FAQ on Matt Pocock's skills from the aihero.dev docs. Use when asking how or why a skill is designed the way it is, or what changed in the skills recently.
disable-model-invocation: true
---

# Skills FAQ

The docs at https://www.aihero.dev/skills are the source of truth for how and why Matt's skills work. The local `~/.agents/skills/<name>/SKILL.md` says what a skill does; the docs add the design, the alternatives considered, and examples.

## Read

Fetch with `curl -fsSL <url>`. Every doc page has a markdown twin: the site links `skills-<name>`, fetch `skills-<name>.md` (append `.md` to any doc link you find on the pages).

- `https://www.aihero.dev/skills.md` — the overview: the skill set by category, install, the changelog.
- `https://www.aihero.dev/skills-<name>.md` — one page per skill.

Each page carries `updatedAt` in its frontmatter; quote it if the answer may already be stale.

## Route

- what does /x do, how to run it → local `~/.agents/skills/x/SKILL.md`
- why is /x designed this way, what was considered → `skills-<name>.md`
- what's new → the changelog on `skills.md`, then the changelog page it links
- which skill fits my situation → `/ask-matt`
