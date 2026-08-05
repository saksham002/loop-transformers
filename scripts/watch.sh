#!/bin/bash
# Poll the 28-run grid2. Emit a line per milestone (stdout -> Monitor events) and
# a bulleted Slack summary every MILESTONE completions. Exits when all are done.
# State lives in ~/logs, never /tmp (rotated, would break resumes).

# Send to Slack via the script at $SLACK_NOTIFY_SCRIPT if set, otherwise print.
notify() {
    if [ -n "$SLACK_NOTIFY_SCRIPT" ]; then
        python "$SLACK_NOTIFY_SCRIPT" "$1" >/dev/null 2>&1
    else
        echo "$1"
    fi
}

STATE=/home/saksham3/logs/loop/watch3_state.txt
MILESTONE=4
TOTAL=12

mkdir -p /home/saksham3/logs/loop
last_reported=$(cat "$STATE" 2>/dev/null || echo 0)

while true; do
    # Newest entry per job name: a resubmitted job has several sacct rows and
    # taking the first would report a stale FAILED forever.
    stats=$(sacct -X --starttime=now-2days --format=JobName%40,State -n -P 2>/dev/null \
            | grep "currmax" | awk -F'|' '{last[$1]=$2} END {for (n in last) print n"|"last[n]}')

    done_n=$(echo "$stats" | grep -c "COMPLETED")
    run_n=$(echo "$stats"  | grep -cE "RUNNING")
    pend_n=$(echo "$stats" | grep -cE "PENDING|REQUEUED")
    fail_n=$(echo "$stats" | grep -cE "FAILED|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY")
    bl_n=$(wc -w < /home/saksham3/projects/AIRe/loop_transformers/blacklist.txt 2>/dev/null || echo 0)

    if [ "$done_n" -ge $((last_reported + MILESTONE)) ]; then
        last_reported=$(( (done_n / MILESTONE) * MILESTONE ))
        echo "$last_reported" > "$STATE"
        echo "MILESTONE completed=${done_n}/${TOTAL} running=${run_n} pending=${pend_n} failed=${fail_n}"
        notify "loop_transformers grid2 (paper replication + Z60 ablation)
• completed: ${done_n}/${TOTAL}
• running: ${run_n}   pending: ${pend_n}
• failed (auto-relaunched): ${fail_n}
• blacklisted nodes: ${bl_n}"
    fi

    if [ "$done_n" -ge "$TOTAL" ]; then
        echo "ALL_COMPLETE completed=${done_n}/${TOTAL}"
        notify "loop_transformers grid2 FINISHED
• completed: ${done_n}/${TOTAL}
• next: analysis/collect_results.py + analysis/plot_results.py"
        exit 0
    fi
    sleep 600
done
