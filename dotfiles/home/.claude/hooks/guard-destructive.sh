#!/bin/bash
# Hook PreToolUse (Bash): demande confirmation avant une commande destructive ou irréversible.
# Actif même avec --dangerously-skip-permissions (Mod+Y). Entrée: JSON sur stdin.
cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

words='rm|shred|unlink|mkfs[.a-z0-9]*|wipefs|parted|fdisk|sfdisk|dd|xbps-remove|truncate'
git='git[[:space:]]+(clean|reset[[:space:]]+--hard|checkout[[:space:]]+--|restore|branch[[:space:]]+-D|stash[[:space:]]+(drop|clear)|push[[:space:]].*(--force|[[:space:]]-f)|filter-branch)'
if printf '%s' "$cmd" | grep -Eq "(^|[;&|(\`]|&&|\|\||[[:space:]]sudo|[[:space:]]xargs|[[:space:]]-exec)[[:space:]]*(sudo[[:space:]]+)?($words)([[:space:]]|\$)" \
   || printf '%s' "$cmd" | grep -Eq "$git" \
   || printf '%s' "$cmd" | grep -Eq 'find[[:space:]].*-delete|>[[:space:]]*/dev/(sd|nvme|mmcblk)'; then
    jq -n --arg c "$cmd" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:("Commande destructive ou irréversible: " + $c)}}'
fi
exit 0
