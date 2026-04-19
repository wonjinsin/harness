---
name: skill-file-language-split
description: harness 프로젝트 규칙 — SKILL.md 는 영어 전용, SKILL.ko.md 는 한국어 전용. 본문·예시·렌더 샘플까지 해당 언어로 일관되어야 한다.
type: feedback
---

harness 프로젝트의 스킬 파일은 언어별로 완전히 분리한다:

- `SKILL.md` — 영어 전용. 산문뿐 아니라 예시 블록, 렌더링 샘플, "if they said X" 같은 인용 예시까지 모두 영어.
- `SKILL.ko.md` — 한국어 전용. 같은 원칙으로 예시까지 한국어.

**Why:** 한 파일 안에 두 언어가 섞이면 독자가 해당 파일을 읽을 때 언어 점프가 일어나 흐름이 끊긴다. 2026-04-19 prd-writer 리뷰에서 유저가 SKILL.md 에 한국어 예시(로그인 페이지 2FA) 가 박혀 있던 걸 지적 — "스킬은 영어로, SKILL.ko.md가 한국어여야 되는데 스킬에 영어(말 취지상 이질 언어)가 있어".

**How to apply:**
- 새 스킬 작성·기존 스킬 편집 시 언어 혼입 체크. `Grep` 으로 SKILL.md 에서 `[가-힣]` 을, SKILL.ko.md 에서 긴 영어 문장을 찾아 점검.
- 예시의 내용 자체를 양쪽 언어로 동일 주제를 쓰되 각자 언어로 표기 (예: 영어 버전은 `"Add 2FA to login page"`, 한국어 버전은 `"로그인 페이지에 2FA 추가"`).
- **예외**: PRD/TRD/TASKS 템플릿의 섹션 헤더 (`## 1. Problem`, `Session:`, `Created:`), JSON 키, 코드 식별자, 표준 기술 용어 (`payload`, `outcome`, `dispatch` 등) 는 양쪽 파일 모두 영어 유지 — 이건 언어 선택이 아니라 기계 판독성을 위한 포맷 규약.
- SKILL.ko.md 에서 전문 용어는 한글로 억지 번역하지 않고 영어 원어 사용 (Korean 기술 글의 일반 관행).
