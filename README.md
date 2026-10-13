# VPS Infrastructure Agent Kit

This kit contains two files for preparing the `vps-infrastructure` repository with Antigravity:

- `ANTIGRAVITY_PROMPT.md` — paste its contents into Antigravity as the implementation task.
- `PROJECT_BRIEF.md` — the durable project specification. Copy it into the repository as `docs/PROJECT_BRIEF.md`.

Recommended use:

1. Open the intended repository in Antigravity.
2. Add `PROJECT_BRIEF.md` to `docs/PROJECT_BRIEF.md` (create `docs/` if needed).
3. Paste `ANTIGRAVITY_PROMPT.md` into Antigravity.
4. Let the agent inspect, implement, and validate repository files only.
5. Review its final report and repository diff before any manual VPS setup.

Do not provide real secrets to the agent or authorize live VPS changes during this phase.
