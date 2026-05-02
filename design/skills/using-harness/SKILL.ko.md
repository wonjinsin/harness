---
name: using-harness
description: 세션 시작 시 메타 스킬로 로드. 모든 유저 턴은 `harness-flow:router` invoke 로 시작 필수 — casual / clarify / plan / resume 분류는 router 자체가 함. 메타 스킬이 사전 분류로 단축경로를 만들지 않음. 'Required next skill' 체인 (각 스킬이 다음을 지정) 을 정의하고 공유 execution-modes / payload / file-ownership 계약은 `harness-contracts/` 를 가리킴.
model: haiku
---

# Using Harness

harness 는 feature/bug 요청을 PRD/TRD/TASKS 로 만들고, 실행하고, 검증하고, 문서를 갱신하는 체인 흐름. 각 스킬의 SKILL.md 는 자기 다음 스킬을 "Required next skill" 섹션에 선언함 — 그 마커를 순서대로 따르면 됨.

<SUBAGENT-STOP>
서브에이전트로 dispatch 되어 특정 태스크를 실행 중이라면 이 스킬을 스킵. harness 체인은 main context 에서만 동작하고, 서브에이전트는 자기에게 주어진 dispatch prompt 만 따름.
</SUBAGENT-STOP>

## Entry rule (진입 규칙)

<EXTREMELY-IMPORTANT>
**모든 유저 턴 — 첫 액션은 반드시 `Skill("harness-flow:router")`.**

메시지를 직접 사전 분류하지 마. casual / clarify / plan / resume 분류는 router 가 하라고 만들어진 일이고, 메타 스킬에서 단축경로를 만드는 것이 harness 가 조용히 disengage 되는 단일 실패 모드. 인사말, 단순 질문, "간단한 수정," 메타 질문 모두 router 로 들어감 — router 가 `casual` 로 판정하면 인라인 응답하고 끝, 그 외에는 `## Status` 를 emit 해 체인이 이어짐.

유일한 합법 스킵: 다른 harness 스킬이 이미 흐름 중이고 그 `## Required next skill` 섹션이 다른 다음 dispatch 를 지정한 경우.
</EXTREMELY-IMPORTANT>

## Red flags — 다음 생각이 떠오르면 STOP

| 생각 | 실제 |
|---------|---------|
| "이건 간단한 질문이니 인라인 답변하자." | casual 여부는 router 가 판단함. invoke 하라. |
| "이건 간단한 수정이니 파일 직접 편집하자." | 간단한 수정도 harness 체인을 거침. router invoke. |
| "요청 이해를 위해 파일 몇 개 먼저 읽자." | orientation 은 routing 다음. router 먼저 invoke. |
| "유저랑 대화 중이니 재라우팅 불필요." | 다른 harness 스킬이 다음 스킬을 지정해 두지 않은 한, 모든 유저 턴은 router 로 재진입. |
| "여기 답을 이미 안다." | 답을 아는 것 ≠ 체인 스킵. router invoke. |

## 스킬 우선순위

harness 스킬의 "Required next skill" 섹션이 후속 스킬을 지정하면, 대화에서 매칭될 다른 스킬보다 먼저 실행. 체인은 load-bearing — 중간 단계 스킵(예: brainstorming 에서 바로 executor) 은 엣지별 핸드오프 계약을 깸. 전체 그래프는 `harness-contracts/payload-contract.ko.md` 참조.

## 실행 모드

각 SKILL.md 는 자체 `## Execution mode` 섹션을 가짐 — "Main context" (인라인 실행) 또는 "Subagent (격리 컨텍스트)" (절차를 prompt 로 Task 툴 dispatch). invoke 할 때 그 선언을 따름. 전체 계약: `harness-contracts/execution-modes.ko.md`.

## 세션 산출물

`.planning/{session_id}/` (사용자 CWD 기준 상대): `ROADMAP.md`, `STATE.md`, `brainstorming.md`, `PRD.md`, `TRD.md`, `TASKS.md`, `findings.md`.
