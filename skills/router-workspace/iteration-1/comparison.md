# Router A/B comparison — iteration-1

Date: 2026-04-19
Baseline: `baseline/SKILL.md` (minimal catalogue, 148 lines)
Candidate: `candidate/SKILL.md` (Option A: Classification signals + False-positive traps + Anaphoric resume, 235 lines)

## Per-prompt results

| # | Kind | Input (abbrev.) | Expected | Baseline | Candidate | B ✓? | C ✓? |
|---|------|-----------------|----------|----------|-----------|------|------|
| 1 | control-plan       | `add JWT auth to /login in src/api.ts` | plan    | plan    | plan    | ✓ | ✓ |
| 2 | control-casual     | `hey, what can this harness do?`       | casual  | casual  | casual  | ✓ | ✓ |
| 3 | boundary           | `fix the bug`                          | clarify | clarify | clarify | ✓ | ✓ |
| 4 | FP-codeblock       | `explain … \`\`\`add auth…\`\`\``      | casual  | casual  | casual  | ✓ | ✓ |
| 5 | FP-question        | `how do I add 2FA to my login page?`   | casual  | **plan**    | casual  | ✗ | ✓ |
| 6 | FP-paststatus      | `I already refactored … what's next?`  | casual  | **clarify** | casual  | ✗ | ✓ |
| 7 | resume-anaphor     | `let's pick up where we left off on the 2FA work` | plan (fresh) | plan (fresh) | plan (fresh) | ✓ | ✓ |
| 8 | FP-quoted          | `the spec says "add 2FA to login…" — thoughts?` | casual | **clarify** | casual | ✗ | ✓ |

**Score: Baseline 5/8 · Candidate 8/8**

## Where the baseline failed

### #5 FP-question (`how do I add 2FA to my login page?`)

Baseline saw `add 2FA` match the plan verb catalogue and committed to plan despite the obvious question form. Candidate's False-positive trap #8 ("Question forms — 'how do I add …' ask about a verb, they don't invoke it") caught it and routed to casual with a substantive technical explanation.

### #6 FP-paststatus (`I already refactored the auth layer, what's next?`)

Baseline saw `refactored` match the plan verb catalogue and fell through to clarify. The user isn't asking for clarification either — they're reporting progress and asking for guidance. Candidate's trap #7 ("Past or subjunctive tense — 'I already added …' are status reports, not requests") correctly classified casual and replied inline.

### #8 FP-quoted (`the spec says "add 2FA to login, required by Q2" — thoughts?`)

Baseline saw `add 2FA` inside the quoted string match a plan verb and generated a session slug. The user is discussing the spec, not requesting work. Candidate's trap #3 ("Quoted strings — 'add 2FA' inside a larger sentence is a reference, not a command") correctly recognized it as discussion and routed to casual with a substantive response pointing out ambiguities in the spec.

## Where both agree

Both got all three control cases (#1, #2, #3) and two trickier cases (#4 code block, #7 resume anaphor). The expanded false-positive traps were also not over-aggressive — candidate didn't overclassify the real plan case (#1) as casual.

## Cost / length

| Metric | Baseline | Candidate | Δ |
|---|---|---|---|
| SKILL.md lines | 148 | 235 | +87 (+59%) |
| Avg tokens per invocation | 19,426 | 21,091 | +1,665 (+8.6%) |
| Avg duration per invocation | 5.5 s | 7.4 s | +1.9 s |

The +8.6% token cost buys 3 false-positive fixes out of 3 tested. Scaling: if router runs on every user turn and 1 in 10 turns hit an FP trap, candidate saves a full-session misroute worth far more than the 8% overhead.

## Recommendation

Adopt candidate (Option A). The baseline is fragile on exactly the class of inputs the user normally paraphrases (questions, past statements, quoted refs, code blocks). The candidate's explicit traps + boundary table push accuracy from 5/8 to 8/8 on the discriminating cases without regressing controls.

Caveats:
- Test set is small (8 prompts). Broader eval recommended before treating 8/8 as "solved".
- Candidate is English-only by design; non-English users rely on the LLM generalizing from the same definitions. Not tested here.
