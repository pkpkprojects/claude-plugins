## Re-Review: Scan, Fix, Rescan

A re-review after the implementer's fix is not "read the new diff and check the finding looks addressed." Re-run the *same* searches/greps used to surface the original findings and confirm each one is actually gone from the codebase, not just absent from the lines that changed:

1. For each prior finding, re-run the pattern or check that found it originally.
2. Mark it **resolved** only if that re-run comes back clean.
3. Mark it **still present** if it comes back positive anywhere — including a spot the diff didn't touch.
4. Flag anything the re-run surfaces that wasn't in the prior report as a **new finding**, not folded into an old one.

A finding is not closed because the implementer says they fixed it. It is closed because the scan that found it no longer finds it.
