---
name: verification
description: Use before claiming work is complete, before committing, pushing, or creating PRs — run verification commands and show evidence before making success claims
---

# Verification

## Core Idea

Run the command, read the output, then state the result. Don't claim something works based on confidence — show evidence.

## Before Claiming Done

- **Tests pass?** Run them fresh. Show the output.
- **Build succeeds?** Run the build. Linter passing doesn't mean it compiles.
- **Bug fixed?** Reproduce the original issue and confirm it's gone.
- **Requirements met?** Re-read what was asked. Check each point.

## Watch For

- Saying "should work now" without running anything.
- Trusting a subagent's success report without checking the actual diff.
- Treating partial verification as full verification (linter passed != tests passed).
- Moving on to the next task without confirming the current one is actually done.
