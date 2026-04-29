### Why every skill performs the self-lookup

Every harness skill performs Core loop steps 1–5 **for its own outgoing edges** before emitting its final JSON, and includes the resolved next-node id as `next`:

- One matching candidate → `"next": "<node-id>"`.
- No matching candidate → `"next": null` (this skill is a terminal in the current branch).
- Multiple matching candidates → emit the first one listed in `harness-flow.yaml` (same tiebreak as the Core loop).

Why every skill does this even though main thread re-derives independently:

- **Self-validation.** A skill that cannot find any matching downstream edge for its own outcome is emitting a value the flow doesn't expect — that is almost always a bug in the skill, and surfacing it as `"next": null` makes it visible.
- **Single source of truth.** Hard-coded "next-skill" hints in SKILL.md drift from `harness-flow.yaml` over time. Re-evaluating the YAML each run keeps the two in sync.
- **Cross-check with main thread.** Main thread re-derives `next` independently. Mismatch = bug (in the skill, in the flow file, or in how the payload was threaded). Log and prefer the main-thread result.

Subagents (`context: fresh` skills) cannot directly invoke the next node — they emit `next` as a hint. Main thread is still the dispatcher.
