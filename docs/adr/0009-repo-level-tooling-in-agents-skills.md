# Repo-level tooling lives in `.agents/skills`, outside the Nix tree

The repo's rules keep every source inline in the Nix module that ships it (no non-`.nix` files under `nixos/`, ADR-0005). Those rules govern the system the flake builds. Some tooling works on the repository itself instead: cutting a release (issue #12) reads git history and evaluates every host, and hardware debug scripts run against the live machine. None of it is part of any host's configuration, so inlining it into a module would ship repo maintenance into the system closure.

Decision:

- **Repo-level skills live in `.agents/skills/<name>/`, tracked in git**, with their own non-Nix files (SKILL.md, scripts, typst templates). pi reads `.agents/skills` natively.
- **`.claude/skills` is a tracked symlink to `../.agents/skills`.** `.gitignore` ignores `.claude/*` and re-includes `.claude/skills`. No link for `.pi`.
- **Toolchains the skills call come from the flake** (a devshell), so renders stay deterministic across releases. The skill files hold templates and data shapes, not pinned binaries.
- The first two residents are `xps-touchpad-debug` (moved from the untracked `.claude/skills`, now public) and the release skill.

Considered:

- **Inline the skill in `harness.nix` and deploy through `home.file`** (the skills-faq pattern): rejected, the skill belongs to this repository, not to the user's agent setup on every machine.
- **Keep project skills untracked in `.claude/skills`**: rejected, they vanish with the checkout and cannot be reviewed or versioned with the code they describe.

Consequences:

- ADR-0005 and the "no non-`.nix` files under `nixos/`" rule stay in force for the Nix tree. `.agents/skills` is the one place where repo-level scripts and templates are allowed.
- A new file under `.claude/` other than `skills` stays ignored. Anything that must be shared goes into `.agents/skills`.
