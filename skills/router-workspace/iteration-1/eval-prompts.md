# Router A/B eval prompts

Baseline = `baseline/SKILL.md` (current, minimal catalogue)
Candidate = `candidate/SKILL.md` (Option A: expanded classification signals + FP traps + anaphoric resume)

Date: 2026-04-19

| # | Kind | Input | Expected route | Discriminator |
|---|------|-------|----------------|---------------|
| 1 | control-plan | `add JWT auth to /login in src/api.ts` | plan | both should pass |
| 2 | control-casual | `hey, what can this harness do?` | casual | both should pass |
| 3 | boundary | `fix the bug` | clarify | target unpinned — candidate's boundary table |
| 4 | FP-codeblock | `explain what this code snippet does:\n\`\`\`\nadd auth to login\nfix the bug\n\`\`\`` | casual | candidate's FP trap #1 |
| 5 | FP-question | `how do I add 2FA to my login page?` | casual | candidate's FP trap #8 |
| 6 | FP-paststatus | `I already refactored the auth layer, what's next?` | casual | candidate's FP trap #7 |
| 7 | resume-anaphor | `let's pick up where we left off on the 2FA work` (assume no .planning/ matches) | plan (fresh) | candidate's anaphoric resume rules |
| 8 | FP-quoted | `the spec says "add 2FA to login, required by Q2" — thoughts?` | casual | candidate's FP trap #3 |
