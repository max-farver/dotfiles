# Debugging

## Process

1. **Read the error** — Stack traces, error messages, and logs often point directly at the problem. Read them fully before doing anything else.
2. **Reproduce it** — Can you trigger it reliably? If not, gather more data before guessing.
3. **Check what changed** — Git diff, recent commits, new dependencies, environment changes. Most bugs come from recent changes.
4. **Trace the data** — Follow the bad value upstream. Where does it originate? What called this with the wrong input? Fix at the source, not the symptom.
5. **One hypothesis at a time** — State what you think is wrong and why. Make the smallest change to test that theory. If it doesn't work, form a new hypothesis — don't pile fixes on top of each other.
6. **Verify the fix** — Write a test if possible. Confirm the original issue is resolved and nothing else broke.

## Multi-Component Systems

When a system has multiple layers (API -> service -> database, CI -> build -> deploy), add logging at each boundary to find which layer breaks before trying to fix anything.

## When to Step Back

If you've tried 3+ fixes and none worked, stop fixing symptoms. The problem is likely architectural. Reassess the approach rather than attempting fix #4.
