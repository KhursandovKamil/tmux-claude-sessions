#!/usr/bin/env bash
# TPM entry point. Binds the Claude session picker popup.
# Override the key with:  set -g @claude-sessions-key 'u'
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

key="$(tmux show-option -gqv @claude-sessions-key)"
[ -z "$key" ] && key="u"

tmux bind-key "$key" display-popup -E -w 80% -h 60% -T ' Claude Sessions ' \
  "$CURRENT_DIR/scripts/picker.sh"
