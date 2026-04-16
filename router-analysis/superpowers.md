# Superpowers 라우팅 분석 — 유저 메시지 수신 경로

## TL;DR (2줄)

Superpowers의 라우팅은 **99% 마크다운으로만 이뤄진다**. Bash 훅은 세션 시작 때
딱 한 번만 돌아 `using-superpowers/SKILL.md`를 컨텍스트에 주입하고, 이후 모든
메시지마다 LLM이 그 마스터 규칙서를 재해석하여 어떤 스킬을 호출할지 스스로 결정한다.

---

## Routing Flow (ASCII)

```
======================================================================
[세션 시작 시 1회] — Bash runtime
======================================================================

   하네스(Claude Code/Cursor/Copilot/OpenCode) 세션 시작
                         |
                         v
   +--------------------------------------------------------------+
   | hooks/hooks.json                                             |
   |   SessionStart matcher = "startup|clear|compact"             |
   |   command: run-hook.cmd session-start                        |
   +-----------------------------+--------------------------------+
                                 |
                                 v
   +--------------------------------------------------------------+
   | hooks/session-start  (bash)                                  |
   |   1) 플러그인 루트 계산 (SCRIPT_DIR/..)                      |
   |   2) skills/using-superpowers/SKILL.md 파일을 cat으로 읽음   |
   |   3) 문자열을 JSON 이스케이프                                |
   |   4) 플랫폼 환경변수 검사:                                   |
   |        CURSOR_PLUGIN_ROOT  -> additional_context (snake)     |
   |        CLAUDE_PLUGIN_ROOT  -> hookSpecificOutput.additional- |
   |                                Context (nested)              |
   |        COPILOT_CLI / 기타  -> additionalContext (flat, SDK)  |
   |   5) JSON을 stdout으로 printf                                |
   +-----------------------------+--------------------------------+
                                 |
                                 v
   +--------------------------------------------------------------+
   | 하네스가 stdout JSON을 읽어 LLM 시스템 컨텍스트에 병합        |
   | <EXTREMELY_IMPORTANT> ... using-superpowers 전문 ...          |
   +--------------------------------------------------------------+

   ========== 여기서 Bash의 일은 끝. 다시는 실행되지 않음 ==========

======================================================================
[매 유저 메시지마다] — LLM runtime (순수 마크다운 해석)
======================================================================

   유저: "X를 만들어줘" / "버그 수정" / "간단한 질문"
                         |
                         v
   +--------------------------------------------------------------+
   | LLM: using-superpowers의 "The Rule" 재확인                   |
   |   - "1% 가능성이라도 스킬이 적용되면 반드시 호출"             |
   |   - Red Flags 표로 자기합리화 차단                           |
   |   skills/using-superpowers/SKILL.md (전문, 이미 주입됨)      |
   +-----------------------------+--------------------------------+
                                 |
            +--------------------+---------------------+
            | 스킬 적용 가능?                          |
            v                                          v
   +--------------------+                  +--------------------+
   | 예 (거의 모든 경우)|                  | 아니오 (매우 드뭄) |
   +---------+----------+                  +---------+----------+
             |                                       |
             v                                       v
   +--------------------------------------+   +-------------------+
   | `Skill` tool 호출                    |   | 스킬 없이 직접 응답|
   |   - Claude Code/Copilot/OpenCode에   |   +-------------------+
   |     내장된 도구. superpowers가 만든  |
   |     것이 아님.                        |
   |   - 해당 SKILL.md를 하네스가 로드     |
   +-----------------+--------------------+
                     |
                     v
   +--------------------------------------------------------------+
   | 스킬 마크다운 본문이 컨텍스트에 추가됨                        |
   |   LLM이 그 안의 체크리스트/디시전 그래프/HARD-GATE를           |
   |   "실행"함. 스킬이 다른 스킬을 호출하라고 지시하면              |
   |   다시 Skill tool 호출 -> 재귀적으로 체인 형성                 |
   |   (brainstorming -> writing-plans -> executing-plans ...)    |
   +--------------------------------------------------------------+
```

---

## Narration

### 1. 세션 시작 — Bash가 한 번만 실행된다 (orchestration layer)

`hooks/hooks.json`은 Claude Code의 `SessionStart` 이벤트에 `startup|clear|compact`
matcher를 걸어 `run-hook.cmd session-start`를 호출한다
(`hooks/hooks.json:3-14`). `run-hook.cmd`는 Windows/Unix 양쪽에서 동작하는
폴리글랏 래퍼이고 실제 로직은 `hooks/session-start` bash 스크립트에 있다.
이 스크립트가 하는 일은 놀라울 만큼 단순하다 — `skills/using-superpowers/SKILL.md`
파일을 `cat`으로 읽어서(`session-start:18`) JSON 이스케이프하고
(`session-start:23-31`), 세 환경변수 중 무엇이 셋되어 있는지 보고 플랫폼별
JSON 포맷으로 출력한다(`session-start:46-55`). `CURSOR_PLUGIN_ROOT`가 있으면
`additional_context` (snake_case), `CLAUDE_PLUGIN_ROOT`만 있으면
`hookSpecificOutput.additionalContext` (중첩), `COPILOT_CLI`나 그 외엔
`additionalContext` (flat, SDK 표준). 이게 Bash가 하는 일의 전부다.

### 2. 주입된 마스터 규칙서 — 세션 전체의 정신적 부트로더

주입되는 내용은 `<EXTREMELY_IMPORTANT>` 태그로 감싸인 `using-superpowers` 스킬
전문이다. 이 문서가 규정하는 "The Rule"은 "**1% 가능성이라도 스킬이 적용될
것 같으면 반드시 `Skill` tool을 호출하라**"이다
(`skills/using-superpowers/SKILL.md:10-16, 44-46`). 그 밑에는 DOT 형식의
디시전 플로우차트가 있고(`SKILL.md:48-76`), 에이전트가 "이 질문은 단순하니까",
"먼저 파일 좀 볼게" 같은 회피를 못 하도록 12가지 Red Flags 표로 합리화를
사전에 차단한다(`SKILL.md:82-95`). 중요한 점은 **이 규칙서는 코드가 아니라
순수 마크다운**이며, "실행"한다는 것은 LLM이 읽고 지시를 따르는 행위 그 자체다.

### 3. 매 메시지 — LLM이 마크다운을 재해석해 라우팅한다

유저 메시지가 오면 Bash는 더 이상 개입하지 않는다. LLM은 이미 주입된
`using-superpowers` 본문을 바탕으로 "지금 요청에 맞는 스킬이 있는가?"를
판단해, 있으면 하네스 내장 `Skill` 도구(superpowers가 만든 것이 아닌 Claude
Code/Copilot CLI/OpenCode의 기본 도구)로 해당 스킬을 로드한다. 로드된 스킬
역시 또 다른 마크다운 파일이다 — `brainstorming/SKILL.md`는 9단계 체크리스트와
HARD-GATE를 담고(`brainstorming/SKILL.md:12-33`), `test-driven-development`는
"Iron Law: NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"를 선언하며
(`test-driven-development/SKILL.md:33-35`), `systematic-debugging`도 동일한
구조다. **어느 스킬 디렉터리에도 실행 가능한 라우터 코드는 없다** — 유일한
예외는 brainstorming의 선택적 시각화 서버(`scripts/server.cjs`)와 스킬 렌더링
유틸(`writing-skills/render-graphs.js`) 같은 부가 도구뿐이다.

### 4. OpenCode 어댑터 — 같은 원리를 다른 훅 포인트로

`.opencode/plugins/superpowers.js`는 OpenCode 플랫폼이 Claude Code 스타일
SessionStart 훅을 지원하지 않아 필요한 얇은 JS 어댑터다(`superpowers.js:1-112`).
bash 훅과 달리 두 가지 추가 작업을 한다 — `config` 훅에서 `config.skills.paths`에
superpowers 스킬 디렉터리를 자동 등록하고(`superpowers.js:89-95`),
`experimental.chat.messages.transform` 훅에서 **첫 유저 메시지의 첫 part 앞에**
부트스트랩 텍스트를 unshift한다(`superpowers.js:101-110`). 흥미로운 선택은
시스템 메시지가 아니라 유저 메시지에 주입한다는 점 — 매 턴 토큰 블로트(#750)와
일부 모델(Qwen 등)에서 시스템 메시지 다중화 문제(#894)를 피하려는 것이다
(`superpowers.js:97-100` 주석). 핵심 동작은 bash 훅과 동일하다: `using-superpowers`
마크다운을 읽어 주입.

### 5. `Skill` 도구의 출처 — superpowers가 만든 게 아니다

LLM이 호출하는 `Skill` tool 자체는 superpowers 소스 어디에도 정의되어 있지
않다. 이것은 Claude Code / Copilot CLI / OpenCode가 제공하는 **호스트 하네스의
내장 기능**이다. `using-superpowers`의 "How to Access Skills" 섹션
(`SKILL.md:28-36`)이 플랫폼별 도구 이름만 안내할 뿐이다 — Claude Code는 `Skill`,
Copilot CLI는 `skill`, Gemini CLI는 `activate_skill`. superpowers는 스킬 파일만
제공하고, 스킬 발견/로딩/주입은 하네스에 위임한다. 이것이 superpowers의
"zero-code orchestration" 디자인의 근간이다.

---

## 단계별 런타임/언어 표

| 단계 | 런타임/언어 | 실질적 동작 |
|---|---|---|
| SessionStart matcher | Claude Code 내부 (C/Rust 네이티브) | `startup\|clear\|compact` 이벤트 발화 시 훅 커맨드 실행 |
| `run-hook.cmd` | Windows batch + Bash 폴리글랏 | OS 감지 후 bash로 `session-start` 실행 |
| `hooks/session-start` | Bash | `using-superpowers/SKILL.md` 읽기, JSON 이스케이프, 플랫폼별 포맷 출력 |
| 컨텍스트 병합 | 하네스 내부 | stdout JSON의 `additionalContext`를 LLM 시스템 컨텍스트에 삽입 |
| `using-superpowers/SKILL.md` | Markdown (LLM이 해석) | "1% 규칙" 및 `Skill` tool 호출 의무 선언 |
| 유저 메시지 라우팅 | **LLM 추론 그 자체** | 규칙서에 따라 어떤 스킬을 호출할지 결정 |
| `Skill` tool | 하네스 내장 도구 (superpowers 아님) | 지정된 SKILL.md를 컨텍스트에 로드 |
| 개별 스킬 (`brainstorming`, `tdd`, `systematic-debugging` 등) | Markdown (LLM이 해석) | 체크리스트·HARD-GATE·다음 스킬 호출 지시 |
| 스킬 체인 재귀 | **LLM 추론** | 스킬이 "다음은 writing-plans 호출"이라 적으면 LLM이 또 `Skill` tool 호출 |
| OpenCode 어댑터 | JavaScript (ESM) | bash 훅 미지원 플랫폼에서 동일한 주입을 JS로 수행 |

---

## 핵심 인사이트

- **Zero-code orchestration**: 라우팅 로직이 코드가 아니라 마크다운 문서 자체다.
  Bash 훅은 "마스터 규칙서를 한 번 주입"만 하고 사라지며, 이후 모든 라우팅
  결정은 LLM이 그 마크다운을 매 턴 재해석하면서 내린다. 라우터 버그를 고치려면
  SKILL.md의 문장을 고치면 된다 — 재컴파일도 재배포도 없다.

- **하네스 의존적이지만 하네스 중립적**: `Skill` tool은 superpowers가 아닌
  호스트 하네스(Claude Code/Copilot/OpenCode/Gemini)의 내장 기능이다.
  superpowers는 스킬 파일과 SessionStart 주입 로직만 제공하고 도구 실행은
  전적으로 위임한다. 덕분에 동일한 스킬 세트가 4개 플랫폼에서 수정 없이
  동작하는 대신, `Skill` tool이 없는 플랫폼에서는 전혀 동작하지 않는다.

- **강제력은 LLM의 지시 준수 능력에 기생한다**: `<HARD-GATE>`, `<EXTREMELY-IMPORTANT>`,
  Red Flags 표, "Iron Law" 같은 장치는 모두 **언어적 강제**다. 코드 게이트가
  아니므로 모델이 합리화하면 뚫리지만, 그 대가로 플랫폼 독립성과 수정 용이성을
  얻는다. 이것은 결함이 아니라 의도된 트레이드오프다 — "LLM 자체를 실행
  엔진으로 삼는다"는 superpowers의 세계관을 그대로 구현한 설계 선택.
