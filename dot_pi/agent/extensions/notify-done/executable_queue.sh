#!/bin/sh
# pi attention queue (maintained by notify-done/index.ts).
#
# Queues are tmux global options, space-separated pane ids, oldest first:
#   @pi_waiting  panes blocked on you (bash-guard etc.)  -> listed/jumped first
#   @pi_done     panes whose agent finished
# Per-pane metadata (pane options): @pi_q_since (epoch), @pi_q_task, @pi_q_note
#
# Usage:
#   queue.sh list                 TSV: kind  pane  where  task  age_secs  note   (in order; prunes dead panes)
#   queue.sh jump [pane] [client] pop pane (default: next in order) and focus it
#   queue.sh menu [client]        tmux display-menu of the queue; pick an entry to jump
#
# ~/.tmux.conf:
#   bind N run-shell -b "~/.pi/agent/extensions/notify-done/queue.sh jump '' '#{client_name}'"
#   bind Q run-shell -b "~/.pi/agent/extensions/notify-done/queue.sh menu '#{client_name}'"

SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
QUEUES="@pi_waiting @pi_done"

pop() { # remove pane $1 from both queues
  for o in $QUEUES; do
    rest=$(tmux show -gqv "$o" | tr ' ' '\n' | grep -vxF "$1" | tr '\n' ' ' | sed 's/ *$//')
    tmux set -g "$o" "$rest"
  done
}

alive() { tmux list-panes -a -F '#{pane_id}' | grep -qxF "$1"; }

ago() {
  s=$1
  if [ "$s" -lt 60 ]; then echo "${s}s"
  elif [ "$s" -lt 3600 ]; then echo "$((s / 60))m"
  elif [ "$s" -lt 86400 ]; then echo "$((s / 3600))h"
  else echo "$((s / 86400))d"; fi
}

list() {
  now=$(date +%s)
  for q in $QUEUES; do
    kind="done"; [ "$q" = @pi_waiting ] && kind="waiting"
    for p in $(tmux show -gqv "$q"); do
      if ! alive "$p"; then pop "$p"; continue; fi
      info=$(tmux display -p -t "$p" '#{session_name} › #{window_index}:#{window_name}	#{@pi_q_task}	#{@pi_q_since}	#{@pi_q_note}')
      where=$(printf '%s' "$info" | cut -f1)
      task=$(printf '%s' "$info" | cut -f2)
      since=$(printf '%s' "$info" | cut -f3)
      note=$(printf '%s' "$info" | cut -f4)
      [ -n "$since" ] || since=$now
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$p" "$where" "$task" "$((now - since))" "$note"
    done
  done
}

jump() {
  p=$1 client=$2
  if [ -z "$p" ]; then
    p=$(list | head -1 | cut -f2)
    [ -n "$p" ] || { tmux display-message ${client:+-c "$client"} "pi: nothing waiting"; exit 0; }
  fi
  pop "$p"
  alive "$p" || { tmux display-message ${client:+-c "$client"} "pi: pane $p is gone"; exit 0; }
  tmux switch-client ${client:+-c "$client"} -t "$p" \; select-window -t "$p" \; select-pane -t "$p"
  left=$(list | wc -l | tr -d ' ')
  [ "$left" -gt 0 ] && tmux display-message ${client:+-c "$client"} "pi: $left more pane(s) need you (prefix Q to list)"
  exit 0
}

menu() {
  client=$1
  entries=$(list)
  if [ -z "$entries" ]; then
    tmux display-message ${client:+-c "$client"} "pi: nothing waiting"; exit 0
  fi
  set --
  i=0
  tab=$(printf '\t')
  while IFS="$tab" read -r kind p where task age note; do
    i=$((i + 1))
    icon="✅"; [ "$kind" = waiting ] && icon="⏳"
    label="$icon $where"
    [ -n "$task" ] && label="$label  \"$task\""
    label="$label  · $(ago "$age")"
    label=$(printf '%s' "$label" | sed 's/#/##/g')   # labels are tmux formats
    key=""; [ "$i" -le 9 ] && key=$i
    set -- "$@" "$label" "$key" "run-shell -b \"'$SELF' jump '$p' '#{client_name}'\""
  done <<EOF
$entries
EOF
  tmux display-menu ${client:+-c "$client"} -T "#[align=centre] pi queue ($i) " -x C -y C "$@"
}

case "$1" in
  list) list ;;
  jump) jump "$2" "$3" ;;
  menu) menu "$2" ;;
  *) echo "usage: $0 list | jump [pane] [client] | menu [client]" >&2; exit 2 ;;
esac
