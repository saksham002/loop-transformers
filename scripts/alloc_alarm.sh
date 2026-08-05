#!/bin/bash
# Ping Slack if the remaining grid jobs are not all allocated within DEADLINE.
# Send to Slack via the script at $SLACK_NOTIFY_SCRIPT if set, otherwise print.
notify() {
    if [ -n "$SLACK_NOTIFY_SCRIPT" ]; then
        python "$SLACK_NOTIFY_SCRIPT" "$1" >/dev/null 2>&1
    else
        echo "$1"
    fi
}

DEADLINE=600
START=$(date +%s)
while true; do
    pend=$(squeue -u saksham3 -h -t PENDING -o "%j" | grep -c "^p_")
    run=$(squeue -u saksham3 -h -t RUNNING -o "%j" | grep -c "^p_")
    [ "$pend" -eq 0 ] && { echo "ALL_ALLOCATED running=${run}"; exit 0; }
    if [ $(( $(date +%s) - START )) -ge "$DEADLINE" ]; then
        echo "STILL_PENDING after ${DEADLINE}s: pending=${pend} running=${run}"
        notify "loop_transformers: jobs still not allocated
• pending: ${pend}
• running: ${run}
• waited: $((DEADLINE/60)) min after the L40S case fix
• reasons: $(squeue -u saksham3 -h -t PENDING -o '%R' | grep -v '^$' | sort -u | tr '\n' ' ')"
        exit 1
    fi
    sleep 30
done
