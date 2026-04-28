#!/bin/bash
# SessionStart hook — inject using-harness meta-skill into session context.
#
# Two modes supported:
#   1. Plugin mode      — Claude Code injects $CLAUDE_PLUGIN_ROOT.
#   2. Copy-paste mode  — repo lives anywhere (e.g. ~/.claude/harness-flow/);
#                          we derive the root from this script's own location.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$SCRIPT_DIR")}"

SKILL_FILE="$HARNESS_ROOT/skills/using-harness/SKILL.md"
FLOW_FILE="$HARNESS_ROOT/docs/harness/harness-flow.yaml"

if [ ! -f "$SKILL_FILE" ]; then
  echo "using-harness skill not found at $SKILL_FILE" >&2
  exit 1
fi

if [ ! -f "$FLOW_FILE" ]; then
  echo "harness DAG file not found at $FLOW_FILE" >&2
  exit 1
fi

cat <<EOF
<EXTREMELY_IMPORTANT>
You have harness.

This harness is mounted at: $HARNESS_ROOT
Harness DAG file (absolute path): $FLOW_FILE

Below is the full content of the 'using-harness' skill — your introduction to operating the harness. It teaches you to interpret the DAG file above and dispatch nodes yourself. Read it now, and follow its rules for every user message in this session. Whenever the skill says \`\${CLAUDE_PLUGIN_ROOT}\`, substitute the absolute path above; never read the YAML or skill files relative to the user's project CWD.

---
EOF

cat "$SKILL_FILE"

cat <<'EOF'
---
</EXTREMELY_IMPORTANT>
EOF
