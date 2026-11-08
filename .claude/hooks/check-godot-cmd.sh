#!/bin/bash
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
if echo "$cmd" | grep -q "godot" && echo "$cmd" | grep -qv "headless"; then
  if ! echo "$cmd" | grep -q "max-fps"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Godot runs must include --max-fps 30 (potato rule). Add it or use headless --quit-after."}}'
    exit 0
  fi
fi
exit 0