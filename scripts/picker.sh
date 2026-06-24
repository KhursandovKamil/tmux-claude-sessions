#!/usr/bin/env bash
# Claude session picker for tmux.
# Lists every tmux pane that has a `claude` process in its subtree, lets you pick
# one with fzf, and jumps the calling client to it. Run from `<prefix>+u`.
#
# Detection is done in awk (kept bash-3.2 safe, since macOS ships bash 3.2):
#   pass 1 reads the `ps` table, pass 2 keeps panes whose shell pid IS `claude`
#   or has `claude` as a DIRECT child. We deliberately don't walk the whole
#   subtree: that would also match claude buried inside e.g. an nvim terminal,
#   where the pane's actual program is nvim, not claude.

set -eo pipefail

STATE_DIR="${HOME}/.cache/claude-tmux-sessions"

glyph_for() {
  # ANSI-colored status glyph + padded label
  case "$1" in
    working) printf '\033[33m●\033[0m working' ;;  # yellow
    waiting) printf '\033[31m◍\033[0m waiting' ;;  # red
    *)       printf '\033[90m○\033[0m idle   ' ;;  # grey
  esac
}

# Emit "pane_id<TAB>session<TAB>window_index<TAB>window_name<TAB>path" for every
# pane that is running claude.
claude_panes() {
  awk '
    FNR==NR {                         # pass 1: ps table  (pid ppid comm)
      comm=$3; sub(/.*\//,"",comm)
      child[$2] = child[$2] " " $1
      if (comm=="claude") isclaude[$1]=1
      next
    }
    has_claude($2) { print }          # pass 2: pane records, field 2 = pane_pid

    # claude is the pane program if it is the pane shell itself or a direct child.
    function has_claude(root,   arr,m,i) {
      if (isclaude[root]) return 1
      m=split(child[root], arr, " ")
      for (i=1;i<=m;i++) if (arr[i]!="" && isclaude[arr[i]]) return 1
      return 0
    }
  ' \
    <(ps -axo pid=,ppid=,comm=) \
    <(tmux list-panes -a -F '#{pane_id}	#{pane_pid}	#{session_name}	#{window_index}	#{window_name}	#{pane_current_path}')
}

# Build display lines, prefixed with sort keys (session, window) we strip later.
lines=()
while IFS=$'\t' read -r pane_id _pane_pid session win win_name path; do
  status="idle"
  [[ -f "$STATE_DIR/$pane_id" ]] && status="$(<"$STATE_DIR/$pane_id")"
  disp_path="${path/#$HOME/~}"
  printf -v line '%s\t%b  \033[36m%s\033[0m  %s:%s  %s' \
    "$pane_id" "$(glyph_for "$status")" "$session" "$win" "$win_name" "$disp_path"
  lines+=("$session	$win	$line")
done < <(claude_panes)

if [[ ${#lines[@]} -eq 0 ]]; then
  tmux display-message "No Claude sessions running"
  exit 0
fi

selected="$(
  printf '%s\n' "${lines[@]}" \
    | sort -t$'\t' -k1,1 -k2,2n \
    | cut -f3- \
    | fzf --ansi --no-sort --reverse \
        --delimiter $'\t' --with-nth=2.. \
        --bind 'ctrl-n:down,ctrl-p:up' \
        --header 'ctrl-n/p move · enter jump · esc close' \
        --prompt 'claude ❯ ' \
    || true
)"

[[ -z "$selected" ]] && exit 0

pane_id="${selected%%$'\t'*}"

# Jump the calling client to the chosen pane. The popup runs in the context of
# the client that opened it, so we read that client name here rather than rely on
# display-popup expanding #{client_name} in the bound command.
client="$(tmux display-message -p '#{client_name}')"
target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}')"
tmux select-pane -t "$pane_id"
tmux select-window -t "$pane_id"
tmux switch-client -c "$client" -t "$target"
