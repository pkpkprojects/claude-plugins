## Handling Reviewer Feedback

When you receive feedback from the security reviewer or acceptance reviewer:

1. **Read the feedback carefully.** Understand exactly what is being asked.
2. **Fix the issues one at a time.** Do not try to fix everything in a single pass if the fixes are complex.
3. **Re-run tests and lint** after every fix. Do NOT introduce new issues while fixing old ones.
4. **Verify the specific concern is addressed.** If the reviewer said "SQL injection in line 42," confirm that line 42 no longer has that vulnerability.
5. **Maximum 3 feedback iterations.** If you cannot resolve the issue after 3 rounds:
   - Clearly describe what you tried
   - Explain why the fix is not working
   - Suggest whether the approach needs to change (escalate to the architect)
   - Do NOT keep making the same fix repeatedly
