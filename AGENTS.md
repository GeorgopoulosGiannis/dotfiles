# Dotfiles workflow

My dotfiles are managed with chezmoi. I prefer editing and testing live files,
then updating chezmoi's source state.

When changing my Pi, Neovim, or other managed configuration:
- Locate the chezmoi repository with `chezmoi source-path`.
- Check existing live and source changes first; preserve unrelated work.
- Edit and verify live configuration, then sync only intended files with
  `chezmoi add --secrets=error FILE`. Do not capture unrelated local edits.
- For chezmoi templates, edit the source template instead; preserve template logic.
- Never recursively add ~/.pi/agent. Never add plaintext credentials, sessions,
  browser profiles, caches, dependencies, or installed binaries.
- `add` copies live → source; `apply` copies source → live. Do not use apply to
  save live edits. Preserve local changes before pulling or applying on another machine.
- This repo is public. Never commit emails, employer/org names, account or role names,
  hostnames, or work skills. Personal values go in chezmoi data (`[data].email`);
  work-only config goes in the private `dotfiles-work` repo cloned to
  `~/.local/share/dotfiles-work` when `work=true` (commit and push there directly).
- Review the resulting source diff, then always commit and push to `origin`.
- One logical change per commit. Split unrelated changes, even within one file
  (stage hunks separately). Never bundle pre-existing unrelated work.
- Use Conventional Commits: `type(scope): summary`, e.g. `feat(tmux): ...`,
  `fix(nvim): ...`, `docs(agents): ...`, `chore(macos): ...`. Scope is the tool or
  area changed. Add a short body explaining why when it is not obvious.
  This applies to every commit, with no exceptions: initial/bootstrap commits,
  squashed or history-rewrite commits (`git commit-tree`, amends), and commits in
  other repos you create or edit (e.g. `dotfiles-work`), e.g. `chore: initial import`.
- Report what changed, what was synced, and the commits pushed.

## Machine-specific Pi defaults

- Reuse chezmoi's existing boolean `work`; do not introduce a second work/personal flag
  or hostname rules. It is separate from the `dev`/`server` installation profile.
- `work=true`: `github-copilot` / `gpt-6.1-sol`.
- `work=false` (or unset): `anthropic` / `claude-opus-5.5`.
- Pi stores provider and model separately; do not put `anthropic/` in `defaultModel`.
- These defaults live in `dot_pi/agent/modify_settings.json`, a chezmoi modify-template that
  sets only the managed keys and keeps keys Pi writes itself. Edit it for Pi settings
  changes; never `chezmoi add` the live settings.json.
- Subagent models (pi-interactive-subagents) live in `dot_pi/agent/agents/*.md.tmpl`
  and use the same `work` switch (`provider/model` form is fine there):
  scout/researcher `github-copilot/gpt-6-luna` vs `anthropic/claude-haiku-5-5`;
  worker `github-copilot/gpt-6.1-sol` vs `anthropic/claude-sonnet-5-5`.
- `.chezmoi.toml.tmpl` preserves/prompts for `data.work`; credentials are never template data.
- Personal Claude access uses Pi's own `/login anthropic` subscription flow, not copied
  Claude Code credentials. Login and model availability must be checked on that machine.

Consult the chezmoi repository README for detailed setup instructions.
