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

if [ ! -f "$SKILL_FILE" ]; then
  echo "using-harness skill not found at $SKILL_FILE" >&2
  exit 1
fi

cat <<EOF
<EXTREMELY_IMPORTANT>
You have harness.

This harness is mounted at: $HARNESS_ROOT

Below is the full content of the 'using-harness' skill — your introduction to operating the harness. Each harness skill declares its own next skill in a 'Required next skill' section; follow those markers in order. Whenever the skill says \`\${CLAUDE_PLUGIN_ROOT}\`, substitute the absolute path above; never read skill files relative to the user's project CWD.

---
EOF

cat "$SKILL_FILE"

cat <<'EOF'
---
</EXTREMELY_IMPORTANT>
EOF
