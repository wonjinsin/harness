# Keyword catalogue (reference)

The patterns below are hints — they mark unambiguous cases for fast classification. Anything they miss (and anything that appears in a false-positive-trap context) falls to the heuristics in `SKILL.md`. Patterns are English-only by design; non-English inputs rely on the LLM layer applying the same definitions.

**Resume verb** (must co-occur with anaphor per "Anaphoric resume signals"):

- `\b(resume|continue|pick\s+up\s+where|keep\s+going\s+on|go\s+back\s+to)\b`

**casual:**

- `^(hi|hello|hey|yo|sup)\b`
- `\b(what\s+can\s+you\s+(do|build)|how\s+does\s+this\s+work|who\s+are\s+you)\b`

**plan (verbs):**

- `\b(add|fix|implement|refactor|migrate|build|create|remove|replace)\b`

**clarify (vague):**

- `\b(make\s+it\s+(better|good|nice)|clean\s+it\s+up|improve\s+the\s+code)\b`

Keep these in sync with `harness-flow.yaml`.
