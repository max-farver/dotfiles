# Git Worktrees

## When to Use

Use a worktree when you need an isolated workspace — feature branches, experiments, or parallel work that shouldn't affect the current working directory.

## Creating a Worktree

Use the `EnterWorktree` tool with a descriptive name. The `WorktreeCreate` hook handles everything:

- Detects bare-repo layout (`repo.git`) vs standard repos
- Creates the worktree and branch
- Symlinks shared config (`.env.local`, `.envrc`, `.idea`, etc.) from `../shared/`
- Links `.claude/*.local.*` files

Don't manually run `git worktree add` — let the hook do its job.

## After Creation

- Install dependencies if needed (`npm install`, `go mod download`, etc.)
- Run tests to confirm a clean baseline before starting work.

## Cleanup

Use the worktree removal tool when done. The `WorktreeRemove` hook handles cleanup, including branch deletion for bare-repo layouts.

## Guidelines

- Keep worktree names short and descriptive (e.g., `add-auth`, `fix-pagination`).
- One concern per worktree. Don't reuse a worktree for unrelated work.
- Clean up worktrees when the branch is merged. Don't let them accumulate.
