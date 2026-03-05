---
name: git-workflow
description: Use when committing, branching, or creating pull requests — conventions for clean git history
---

# Git Workflow

## Commits

- Commit messages should explain **why**, not what. The diff shows what changed.
- Prefer small, focused commits. Each commit should do one thing.
- Don't bundle unrelated changes in a single commit.
- Stage specific files rather than `git add -A` to avoid accidentally committing sensitive files or junk.

## Branches

- Create a branch for any non-trivial change.
- Keep branches short-lived. The longer a branch lives, the harder the merge.
- Prefer rebasing over merge commits for keeping history clean, but don't force-push shared branches.

## Pull Requests

- Write a brief description of what and why. Link to the relevant ticket if there is one.
- Keep PRs small enough to review in one sitting when possible.
- Don't mix refactoring with feature work in the same PR.
