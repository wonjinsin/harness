# Archon Router Analysis

## TL;DR

라우팅의 **결정 분기 자체는 순수 TypeScript 함수**(`handleMessage`)로 실행된다.
프리폼 메시지의 "워크플로우로 넘길지" 판단은 **별도 라우터 LLM 호출이 아니라**, 메인 LLM이 출력 스트림에 `/invoke-workflow` 토큰을 뱉으면 TS가 정규식으로 가로채는 하이브리드다.

---

## Routing Flow (ASCII Diagram)

```
┌─────────────────────────────────────────────────────────────────────┐
│ Platform Adapter (TS) — SDK 이벤트 리스너 또는 HTTP 핸들러           │
│ @slack/bolt Socket Mode / grammy(Telegram) / Hono(Web·GitHub webhook)│
│ adapters/src/chat/slack/adapter.ts:237 (onMessage)                  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ 플랫폼별로 인증/화이트리스트 통과 후
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ConversationLockManager.acquireLock() — fire-and-forget 직렬화       │
│ 같은 conversationId는 FIFO, 전역 동시 10개 제한, 나머지는 큐         │
│ core/src/utils/conversation-lock.ts:59                              │
│ server/src/index.ts:419 (slack) :595 (telegram) :365 (discord)      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ 락 확보 후 handleMessage 호출
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ handleMessage() — 결정 분기의 진입점 (TS 함수, LLM 아님)             │
│ core/src/orchestrator/orchestrator-agent.ts:498                     │
│ 대화 조회/생성, thread context 상속, 제목 생성 fire-and-forget       │
└───────┬───────────────────────┬───────────────────────┬─────────────┘
        │                       │                       │
        ▼ (1) approval 우선      ▼ (2) 슬래시 우선        ▼ (3) 그 외
┌────────────────────┐ ┌────────────────────┐ ┌──────────────────────┐
│ 승인 대기 워크플로우 │ │ 화이트리스트 슬래시 │ │ 프리폼 → LLM 위임     │
│ "/"로 시작 안 하고  │ │ help status reset  │ │ (아래 전체 경로 계속) │
│ pausedRun 존재 시  │ │ workflow init …    │ └─────────┬────────────┘
│ orchestrator-      │ │ orchestrator-      │           │
│ agent.ts:535       │ │ agent.ts:649-702   │           │
│ 재개 dispatch 실행  │ │ commandHandler     │           │
└────────────────────┘ │ .handleCommand()   │           │
                       │ AI 호출 없이 즉시   │           │
                       └────────────────────┘           │
                                                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Context 조립 — codebases, workflows 목록, config, env, session      │
│ orchestrator-agent.ts:704-790                                       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ buildFullPrompt() — 시스템 프롬프트(Markdown 템플릿, TS string 조립) │
│ 워크플로우 목록 + "Routing Rules" 프로즈 + /invoke-workflow 스펙     │
│ core/src/orchestrator/prompt-builder.ts:114 (buildOrchestratorPrompt)│
│ core/src/orchestrator/prompt-builder.ts:51  (buildRoutingRules)     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ aiClient.sendQuery() — 메인 LLM(Claude/Codex) 스트리밍 호출          │
│ 이 LLM이 "직접 답변" vs "워크플로우 호출"을 프로즈 읽고 결정          │
│ orchestrator-agent.ts:865 (stream) / 984 (batch)                    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ 스트림 청크마다 TS가 감시
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 토큰 가로채기 — 정규식 /^\/invoke-workflow\s/m 로 감지                │
│ 감지 시 이후 청크 억제, 완료 후 parseOrchestratorCommands 파싱       │
│ 일반 응답이면 그대로 사용자에게 흘려보냄 (stream) 또는 모아서 전송    │
│ orchestrator-agent.ts:879 / 919 / 1001 / 1053                       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
           ┌───────────────────┴───────────────────┐
           ▼ /invoke-workflow 감지됨               ▼ 일반 응답
┌──────────────────────────┐          ┌──────────────────────────────┐
│ emitRetract() 후 워크플로우│          │ 이미 스트리밍한 답변으로 종료 │
│ executor로 dispatch       │          │ (batch는 최종 텍스트 1회 전송)│
│ orchestrator-agent.ts:921 │          └──────────────────────────────┘
└──────────────────────────┘
```

---

## Narration

메시지의 첫 착지점은 **플랫폼 어댑터 TS 클래스**다. Slack은 `@slack/bolt` Socket Mode 리스너, Telegram은 `grammy` 폴링, Web·GitHub은 Hono HTTP 핸들러가 역할을 맡고, 각자 자기 SDK/프로토콜에 맞게 인증과 화이트리스트를 통과시킨다(`adapters/src/chat/slack/adapter.ts:237`에서 `onMessage` 콜백 등록). 어댑터는 플랫폼 고유 식별자를 `conversationId`로 정규화만 해두고, 실제 처리는 서버 엔트리에서 건네받은 공유 `ConversationLockManager`에 즉시 위임한다(`server/src/index.ts:419` 슬랙 분기). 이 전 과정은 Bun 런타임의 TS 코드이고, LLM은 아직 관여하지 않는다.

다음 관문인 `acquireLock`은 단순한 **직렬화 큐**다(`core/src/utils/conversation-lock.ts:59`). 같은 대화면 FIFO로 줄 세우고, 전역 활성 10개를 넘으면 캐파시티 큐에 넣고, 그 외에는 `handler()` Promise를 Map에 저장한 뒤 즉시 반환한다. webhook 응답을 3초 안에 돌려줘야 하는 Slack·GitHub 같은 플랫폼이 자연스럽게 성립하는 이유는 이 "fire-and-forget"에 있다 — 락을 잡자마자 함수가 리턴하므로 HTTP는 바로 200을 줄 수 있다.

본격적인 **라우팅 분기**는 `handleMessage`(`orchestrator-agent.ts:498`)가 연다. 분기는 세 갈래지만 순서가 의도적이다. **첫째**, 메시지가 `/`로 시작하지 *않고* DB에 해당 대화의 `pausedRun`이 있으면(`:535`), Archon은 이 메시지를 자연어 승인 응답으로 해석해 워크플로우를 재개한다 — 승인 대기는 슬래시 커맨드보다 우선한다. **둘째**, 그렇지 않고 `/`로 시작하면 하드코딩된 화이트리스트(`help`, `status`, `reset`, `workflow`, `register-project`, `update-project`, `remove-project`, `commands`, `init`, `worktree`)에 있는지 검사해(`:649-702`), 있으면 `commandHandler.handleCommand()`로 직행한다. 이 경로는 DB 업데이트·쉘 실행만 있고 LLM 호출이 0건이다. **셋째**, 위 둘에 모두 해당 안 되면(예: 프리폼 문장, 혹은 화이트리스트에 없는 `/xyz`) 컨텍스트 조립을 거쳐 메인 LLM에게 전체 판단을 위임한다.

프리폼 경로의 핵심은 **"AI 라우터"라 부를 별도 호출이 존재하지 않는다**는 점이다. `buildFullPrompt`(`:735`)가 만들어내는 시스템 프롬프트는 `prompt-builder.ts`에서 TS template literal로 빌드되는 Markdown 문자열인데, 그 안에 `## Routing Rules` 섹션(`prompt-builder.ts:51`)과 `/invoke-workflow {name} --project {project} --prompt "..."`라는 출력 컨벤션이 프로즈로 들어간다. 즉 **"라우팅 시스템 프롬프트"는 별도 .md 파일이 아니라 TS 안에서 조립되는 문자열**이며, 메인 LLM은 이 프롬프트 + 사용 가능한 워크플로우 목록을 보고 "직접 답할지, `/invoke-workflow`를 뱉을지" 스스로 결정한다. 결정 주체는 라우팅 전용 모델이 아니라 본 작업을 할 같은 Claude/Codex 호출이다.

LLM이 응답을 스트리밍하는 동안 TS 측은 **정규식 감시자**(`/^\/invoke-workflow\s/m`와 `/^\/register-project\s/m`)를 두고 각 청크를 검사한다(`:879`, `:1001`). 토큰이 감지되는 순간부터 이후 청크는 `commandDetected = true`로 억제되고, 루프가 끝나면 `parseOrchestratorCommands`(`:919` / `:1053`)가 전체 응답에서 워크플로우 이름·프로젝트·프롬프트를 뽑아낸다. 이미 사용자에게 흘러간 텍스트는 `platform.emitRetract()`로 취소되고, 워크플로우 executor로 제어가 넘어간다. 즉 "프리폼 → 워크플로우" 라우팅의 **판단은 LLM이 자연어 프롬프트로 수행**하고, **검출·디스패치는 TS 정규식+함수가 담당**하는 결정론적 하이브리드다.

---

## Language/Runtime Breakdown

| 단계 | 런타임/언어 | 실질적 동작 |
| --- | --- | --- |
| Platform 이벤트 수신 | TS / Bun (+ 벤더 SDK) | `@slack/bolt` Socket Mode, grammy 폴링, Hono HTTP 핸들러 |
| `ConversationLockManager.acquireLock` | TS 클래스 (순수) | Map 기반 FIFO + 전역 캐파시티 10, fire-and-forget |
| `handleMessage` 엔트리 | TS 함수 | 대화 조회·생성, thread context 상속, 제목 생성 비동기 킥 |
| (1) Approval 분기 | TS 조건문 + SQLite 조회 | `workflowDb.getPausedWorkflowRun` 결과로 자연어 승인 재개 |
| (2) 슬래시 화이트리스트 | TS `Array.includes` | 하드코딩된 10개 command, `commandHandler.handleCommand` 직접 호출 |
| (3) 프리폼 — 프롬프트 조립 | TS template literal | `prompt-builder.ts`가 워크플로우 목록 + Routing Rules 프로즈를 문자열로 이어붙임 |
| 라우팅 판단 (AI) | LLM (Claude/Codex) | **별도 classifier 없음** — 메인 호출이 시스템 프롬프트 읽고 스스로 결정 |
| 시스템 프롬프트 소스 | TS 내 인라인 Markdown | `.md` 파일이 아니라 `buildRoutingRulesWithProject()`가 리턴하는 문자열 |
| 토큰 검출 | TS 정규식 (`/^\/invoke-workflow\s/m`) | 스트림 청크마다 검사, 히트 시 이후 청크 suppression |
| 워크플로우 dispatch | TS `executeWorkflow` | `@archon/workflows` DAG executor, 노드별 개별 LLM 호출 |
| 스트림 rollback | TS `platform.emitRetract` | 이미 보낸 텍스트 취소 후 워크플로우 응답으로 대체 |

---

## 핵심 인사이트

- **라우팅 분기 자체는 코드, 프리폼 판단만 LLM** — `handleMessage`의 3-way 분기는 TS `if/else`로 결정론적이고, LLM은 "프리폼이면 워크플로우로 넘길지 답할지"만 담당한다. 이 비대칭이 슬래시 커맨드의 제로-레이턴시와 프리폼의 유연성을 동시에 보장한다.

- **"AI 라우터"는 별도 모델 호출이 아니라 메인 호출의 출력 토큰 감지** — Archon은 classifier LLM을 따로 두지 않는다. 본 작업을 수행할 Claude/Codex가 시스템 프롬프트에서 `/invoke-workflow` 출력 컨벤션을 학습하고, TS는 정규식으로 그 토큰을 가로챈다. 덕분에 라우팅 1회·작업 1회가 아니라 **라우팅+작업이 1회 호출 안에 포개진다** (대신 이미 스트리밍된 텍스트 retract라는 UX 복잡도를 감수).

- **시스템 프롬프트는 `.md` 파일이 아니라 TS에서 조립되는 Markdown 문자열** — `prompt-builder.ts`가 코드베이스 목록·워크플로우 목록·Routing Rules·예시를 런타임에 template literal로 이어붙인다. 워크플로우를 추가해도 프롬프트 파일을 수정할 필요가 없고, 프로젝트 스코프가 있으면 `buildRoutingRulesWithProject(scopedCodebase.name)`로 기본 프로젝트까지 자동으로 박아 넣는 식으로 프로즈가 동적으로 바뀐다.
