### Threading upstream outcomes through payloads

downstream `when:` 표현식이 upstream 노드의 출력을 참조할 수 있다 (예: `task-writer` 의 `when:` 은 `$brainstorming.output.outcome` 을 읽는다). dispatch 된 스킬이 자기 outgoing edge 를 평가하려면 해당 upstream 값들이 페이로드에 들어 있어야 한다.

규약: 노드를 dispatch 할 때, `harness-flow.yaml` 에서 그 노드의 downstream edge 가 참조하는 모든 upstream `outcome` 을 페이로드에 포함시킬 것. 현재 기준으로:

- `prd-writer` 페이로드는 `brainstorming_outcome` 포함 (downstream `trd-writer` / `task-writer` 의 `when:` 둘 다 `$brainstorming.output.outcome` 참조).
- `trd-writer` 페이로드는 `brainstorming_outcome` 포함 (downstream `task-writer` 의 `when:` 이 참조).
- 그 외 모든 스킬의 downstream edge 는 `when:` 이 없거나 직속 upstream 의 outcome 만 참조한다 (스킬이 이미 자기 `outcome` 으로 갖고 있음). 추가 페이로드 필드 불필요.

dispatch 된 스킬이 현재 받지 않는 upstream outcome 을 참조하는 새 edge 를 추가한다면, 플로우 파일과 해당 스킬 SKILL.md 의 페이로드 스키마를 함께 갱신할 것.
