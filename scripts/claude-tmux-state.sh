#!/usr/bin/env bash
# Records the current Claude session's status, keyed by its tmux pane id, for the
# tmux claude-session picker. Invoked from Claude Code hooks:
#   working | waiting | idle | clear
[ -n "$TMUX_PANE" ] || exit 0
dir="$HOME/.cache/claude-tmux-sessions"
mkdir -p "$dir"
f="$dir/$TMUX_PANE"
case "$1" in
  clear) rm -f "$f" ;;
  *)     printf '%s' "$1" > "$f" ;;
esac
exit 0
