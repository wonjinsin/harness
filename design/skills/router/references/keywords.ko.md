# 키워드 카탈로그 (참조)

아래 패턴은 힌트 — 명백한 케이스를 빠르게 처리하기 위한 것이다. 여기서 안 잡히는 케이스 (그리고 false-positive 트랩 문맥에 들어간 케이스) 는 모두 `SKILL.md` 의 휴리스틱으로 넘어간다. 패턴은 **영어 전용** 이며, 비영어 입력은 같은 정의를 기준으로 LLM 레이어가 처리한다.

**재개 동사** ("재개 지시어 신호" 에 따라 anaphor 와 동시 출현 필요):

- `\b(resume|continue|pick\s+up\s+where|keep\s+going\s+on|go\s+back\s+to)\b`

**casual:**

- `^(hi|hello|hey|yo|sup)\b`
- `\b(what\s+can\s+you\s+(do|build)|how\s+does\s+this\s+work|who\s+are\s+you)\b`

**plan (동사):**

- `\b(add|fix|implement|refactor|migrate|build|create|remove|replace)\b`

**clarify (모호):**

- `\b(make\s+it\s+(better|good|nice)|clean\s+it\s+up|improve\s+the\s+code)\b`

`harness-flow.yaml` 과 동기화 유지.
