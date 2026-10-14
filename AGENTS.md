# AGENTS.md — agent instructions for this repo

## Never commit

- **Never run `git commit`, `git push`, or create PRs.** The owner reviews the working
  tree and commits/pushes themselves.
- Leave all changes in the working tree (unstaged/staged is fine as long as you don't
  commit). Do not `git add` + commit in one chain.
- Feature branches may be created/checked out (`git checkout -b <name>`) — just don't
  commit to them.
- If a task seems to require a commit (e.g. "make a PR"), stop after the code/docs
  changes and tell the owner the changes are ready.

## Project shape

- Godot project lives in `godot/` (open that folder in the editor).
- Milestone plan and checklists: `docs/plan.md` (one branch → one PR per milestone,
  version bump per milestone).
- Design decisions: `docs/decisions.md`; spell vocabulary: `docs/spells.md`;
  controls: `docs/controls.md`.
- Tests: gdUnit4 in `godot/tests/` — run with:
  `godot --headless --import . && godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests -c --ignoreHeadlessMode -rd tests/reports`
  (from `godot/`; CI pins Godot 4.6.3).
