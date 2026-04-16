# gstack Routing — 코드인가, 프로즈인가?

## TL;DR (2줄)

gstack의 라우팅은 **거의 전부 마크다운 프로즈**다 — 루트 `SKILL.md`에 쓰인 영어 문장("User reports a bug → invoke `/investigate`")을 **LLM(Claude Code 호스트)이 읽고 매칭**하여 내장 `Skill tool`을 호출한다. 실제 코드 실행은 라우팅 **이후**에 시작된다 — 선택된 스킬의 Bash 프리앰블, 그리고 빌드 타임의 TypeScript(Bun) 템플릿 렌더링만이 "진짜 코드"다.

---

## Routing Flow (ASCII)

```
                     유저 입력 (Claude Code 채팅창)
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
   "/ship" 같은 명시적                    "배포해줘" 같은 자연어
   슬래시 커맨드                          (또는 "버그다", "이거 깨졌어")
          │                                       │
          ▼                                       ▼
 ┌──────────────────────┐               ┌──────────────────────────┐
 │ Claude Code 호스트의  │               │ 세션 시작 시 Claude Code가 │
 │ 슬래시 디스패처(내장) │               │ 루트 gstack/SKILL.md을    │
 │ = 유저 타이핑한 이름  │               │ 컨텍스트에 자동 주입      │
 │ 그대로 Skill tool 호출│               │ (preamble-tier: 1 때문)  │
 │                      │               │ → 라우팅 룰이 "프롬프트"로 │
 │ 코드 판단 아님 — 문자│               │   LLM 앞에 놓인다         │
 │ 열 매칭 수준          │               └──────────────┬───────────┘
 └──────────┬───────────┘                              │
            │                                          ▼
            │                          ┌─────────────────────────────┐
            │                          │ LLM이 유저 메시지를 읽고     │
            │                          │ SKILL.md:28-49의 25개 룰    │
            │                          │ ("bug→investigate" 등)과    │
            │                          │ 대조 — 순전히 자연어 이해    │
            │                          │                             │
            │                          │ 코드 실행 0. regex 0. 스크립트 0│
            │                          └──────────────┬──────────────┘
            │                                         │
            └───────────────────┬─────────────────────┘
                                │
                                ▼
                ┌──────────────────────────────────┐
                │ Claude Code 내장 Skill tool 호출  │
                │ ex) skill: "ship"                 │
                │ → ~/.claude/skills/gstack/ship/   │
                │   SKILL.md 를 컨텍스트에 로드     │
                │ (Claude Code의 스킬 로더가 담당)  │
                └──────────────┬───────────────────┘
                               │
                               ▼
                ┌──────────────────────────────────┐
                │ 여기서부터 "진짜 코드" 시작:       │
                │ 서브스킬 SKILL.md의 Preamble Bash │
                │ 블록을 Bash tool로 실행           │
                │ (update check, session, learnings)│
                └──────────────────────────────────┘
```

---

## Narration — 프로즈 vs 코드, 단계별로

### 1단계: 세션 시작 — Claude Code 호스트가 루트 SKILL.md를 "미리" 로드

gstack 루트 `SKILL.md`의 frontmatter에는 `preamble-tier: 1`이라는 필드가 있다. 이 값은 **Claude Code(호스트)가 해석하는 메타데이터**다 — gstack이 실행하는 코드가 아니다. Claude Code의 내장 스킬 로더가 "tier 1이면 세션 시작 시 자동 컨텍스트에 주입"하는 규칙을 따른다. 즉 유저가 첫 메시지를 보내기 전에 이미 gstack의 라우팅 규칙 문장들이 LLM의 시스템/컨텍스트 프롬프트 안에 들어가 있다. **이 단계는 호스트의 내부 동작이며 gstack은 메타데이터 한 줄로만 관여한다.**

### 2단계: 유저 입력 — 두 갈래로 나뉜다

유저가 `/ship`을 입력하면 Claude Code의 슬래시 커맨드 디스패처가 그 문자열을 스킬 이름으로 인식하여 `Skill tool`을 `skill: "ship"`으로 호출한다. 이건 LLM 판단이 아니라 **호스트 CLI 레벨의 문자열 라우팅**이다(Claude Code 내장). gstack 코드는 개입하지 않는다.

반면 유저가 "배포해줘", "이거 왜 깨졌어"처럼 자연어를 쓰면 슬래시 매칭은 실패하고, LLM이 메시지 전체를 읽는다. 이때 LLM이 컨텍스트 안에 이미 들어와 있는 루트 `SKILL.md:28-49`의 프로즈 규칙 25개를 참고한다:

```
User reports a bug, error, broken behavior → invoke `/investigate`
User asks to ship, deploy, push, create a PR → invoke `/ship`
```

이 매칭은 **완전히 LLM 추론**이다. regex도, Python도, Bash도, TypeScript도 돌지 않는다. gstack 저자는 "이런 문장을 보면 이 스킬을 불러라"는 지시문을 그냥 마크다운에 써 두었고, LLM이 프롬프트로 이를 따른다. 한국어 "버그다"를 매칭하는 것도 동일한 원리 — 룰에는 영어만 쓰여 있지만 LLM이 다국어 의미 매칭을 해 준다.

### 3단계: Skill tool 호출 — 호스트 내장 메커니즘

LLM이 `Skill tool`을 호출하면 Claude Code가 해당 스킬 디렉터리의 `SKILL.md`를 읽어 컨텍스트에 주입한다. 이 "스킬 파일 읽어 컨텍스트에 넣기"는 Claude Code의 내장 기능이지 gstack 코드가 아니다.

### 4단계: 드디어 진짜 "코드 실행" — 서브스킬 Preamble Bash

여기서 처음으로 실제 코드가 돈다. 서브스킬 `SKILL.md` 상단에는 `## Preamble (run first)` 아래 긴 Bash 블록이 있고, LLM은 이걸 `Bash tool`로 실행하라는 지시를 받는다. 이 블록이 업데이트 체크, 세션 파일 터치(`~/.gstack/sessions/$PPID`), `gstack-config` 읽기, repo 모드 감지, 학습 데이터 로드, 텔레메트리 JSONL 기록을 수행한다. 중요한 점: **이 Bash는 라우팅을 하지 않는다** — 라우팅은 이미 끝난 뒤의 컨텍스트 세팅용이다. 출력된 환경 변수들(`PROACTIVE`, `REPO_MODE`, `LEARNINGS` 등)은 다시 LLM이 읽어서 "프로즈 조건문"에 따라 행동을 결정한다(`If PROACTIVE is false, …` 같은 if-문이 마크다운 본문에 쓰여 있다).

### 5단계: TypeScript/Bun은 어디에 있나 — 빌드 타임 전용

`scripts/resolvers/preamble.ts`의 `generatePreambleBash()`는 **유저 런타임에서 실행되지 않는다**. Bun으로 돌리는 `gen-skill-docs.ts` 파이프라인이 개발 시점에 한 번 실행되어 `SKILL.md.tmpl` 안의 `{{PREAMBLE}}` 플레이스홀더를 실제 Bash 문자열로 치환해 최종 `SKILL.md`를 생성한다(8개 호스트별로 경로만 다르게). 그 결과물만 유저 디스크에 깔리고, 런타임에는 LLM이 그 마크다운을 읽을 뿐이다. **TypeScript는 "라우팅을 결정"하는 것이 아니라 "라우팅 프로즈가 들어 있는 마크다운을 만드는" 역할이다.**

---

## 언어·런타임 분해표

| 단계 | 런타임/언어 | 실질적 동작 |
|------|-------------|-------------|
| 루트 SKILL.md 자동 주입 | Claude Code 호스트 (내장, 언어 내부) | `preamble-tier: 1` 메타데이터 해석 → 세션 시작 시 파일 내용을 LLM 컨텍스트에 삽입 |
| `/ship` 슬래시 매칭 | Claude Code 호스트 (내장 CLI) | 문자열 → 스킬 이름 1:1 매핑, LLM 추론 없음 |
| 자연어 → 스킬 매칭 | **LLM (Claude)** — 프롬프트 해석 | 컨텍스트에 있는 마크다운 룰 25개를 의미 기반으로 매칭. 코드 0줄 |
| `Skill tool` 디스패치 | Claude Code 호스트 (내장 툴) | 타겟 스킬 경로의 `SKILL.md`를 읽어 새 컨텍스트로 주입 |
| 서브스킬 Preamble 실행 | Bash (`Bash tool`로 LLM이 실행) | update check, session, config 읽기, learnings 검색, telemetry JSONL |
| 프리앰블 출력에 따른 분기 | **LLM** — 마크다운 `If X is Y:` 프로즈 | 예: `If PROACTIVE is "false"`, `If SPAWNED_SESSION is "true"` — 모두 LLM이 읽고 행동 |
| `SKILL.md.tmpl` → `SKILL.md` | TypeScript/Bun (빌드 타임만) | `scripts/gen-skill-docs.ts` + `resolvers/preamble.ts` — 유저 런타임 아님 |
| `gstack-config`, `gstack-learnings-log` 등 바이너리 | TypeScript 컴파일된 바이너리 (`bin/`) | 상태 I/O만 담당, 라우팅 결정과 무관 |

---

## 핵심 인사이트 (3)

- **라우팅은 "프롬프트 엔지니어링"이지 "코드"가 아니다.** gstack의 자연어 라우팅 경로 전체는 `SKILL.md:28-49`의 25개 불릿으로 구현되어 있다. 파서도, 스코어러도, 임베딩도 없다 — LLM이 읽는 마크다운 문장이 곧 라우터다. 그래서 한국어 "배포해줘"도 영어 룰로 잡히고, 새 룰 추가는 마크다운 한 줄이면 끝난다.

- **Claude Code 호스트의 내장 메커니즘이 "무거운 일"을 거의 다 한다.** `preamble-tier`로 자동 주입, 슬래시 커맨드로 직결 디스패치, `Skill tool`로 서브스킬 SKILL.md 로딩 — 이 세 가지는 gstack이 만든 것이 아니라 Claude Code가 제공하는 것이다. gstack은 이 인프라 위에 얹힌 "마크다운 라이브러리"에 가깝다.

- **TypeScript/Bun과 Bash는 라우팅이 아니라 주변 생태계다.** Bun은 빌드 타임에 템플릿을 렌더링해 8개 호스트용 SKILL.md를 만들고, Bash 프리앰블은 스킬이 선택된 **이후** 환경을 세팅한다. 라우팅 결정 자체가 일어나는 순간에는 어떤 코드도 돌지 않는다 — LLM이 문서를 읽고 `Skill tool`을 호출하는 단일 추론 스텝뿐이다.
