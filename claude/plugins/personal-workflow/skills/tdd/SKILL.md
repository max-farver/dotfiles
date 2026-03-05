---
name: tdd
description: Use when implementing features or fixing bugs — red-green-refactor cycle for test-driven development
---

# Test-Driven Development

## Process

1. **Red** — Write one small failing test that describes the behavior you want.
2. **Verify red** — Run it. Confirm it fails for the right reason (missing feature, not a typo).
3. **Green** — Write the simplest code that makes the test pass. Nothing more.
4. **Verify green** — Run it. Confirm all tests pass.
5. **Refactor** — Clean up. Keep tests green. Don't add behavior.
6. **Repeat** — Next behavior, next failing test.

## Good Tests

- Test one behavior each. If the name has "and", split it.
- Use clear names that describe the expected behavior.
- Prefer real code over mocks. Only mock when you have to (external services, etc).
- Write the assertion first — it clarifies what you're actually testing.

## Bug Fixes

Write a failing test that reproduces the bug before fixing it. The test proves the fix works and prevents regression.

## When You're Stuck

- Hard to test usually means hard to use. Simplify the interface.
- Need to mock everything? Code is too coupled. Consider dependency injection.
- Don't know how to test it? Write the API you wish you had, then make it real.

## Spiking

Sometimes you need to explore before you know what to build. That's fine — spike freely, then throw it away and start fresh with tests. Don't retrofit tests onto spike code.
