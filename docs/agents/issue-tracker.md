# Issue tracker: GitHub (+ bd/beads sync)

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

`bd` (beads) is also in use as a local issue tracker and is synced with GitHub. Use `bd remember` for persistent knowledge across sessions.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## bd sync

- Use `bd` locally for task tracking and persistent memory (`bd remember`, `bd memories`)
- When a GitHub remote is configured, `bd dolt push` syncs beads data

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.
