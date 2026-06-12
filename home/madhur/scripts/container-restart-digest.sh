#!/usr/bin/env bash
set -uo pipefail

WEBHOOK_URL="${WEBHOOK_URL:-https://n8n.desktop.madhur.co.in/webhook/container-restart-digest}"
SINCE="${SINCE:-24h}"

# Convert SINCE (e.g. "24h", "7d") to a cutoff RFC3339 timestamp
case "$SINCE" in
  *h) hours="${SINCE%h}"; cutoff=$(date -u -Iseconds -d "${hours} hours ago") ;;
  *d) days="${SINCE%d}";  cutoff=$(date -u -Iseconds -d "${days} days ago") ;;
  *m) mins="${SINCE%m}";  cutoff=$(date -u -Iseconds -d "${mins} minutes ago") ;;
  *)  cutoff=$(date -u -Iseconds -d '24 hours ago') ;;
esac

# All containers (running and stopped), with key fields
containers=$(docker ps -a --format '{{.ID}}' | while read -r id; do
  docker inspect "$id" --format '{{json .}}'
done | jq -s --arg cutoff "$cutoff" '
  map({
    name: (.Name | sub("^/"; "")),
    image: .Config.Image,
    state: .State.Status,
    restartCount: .RestartCount,
    startedAt: .State.StartedAt,
    finishedAt: .State.FinishedAt,
    exitCode: .State.ExitCode,
    oomKilled: .State.OOMKilled,
    error: .State.Error,
    health: (.State.Health.Status // null)
  })
  | map(select(
      (.startedAt   != null and .startedAt   > $cutoff) or
      (.finishedAt  != null and .finishedAt  > $cutoff) or
      (.restartCount > 0 and .state != "running") or
      (.health == "unhealthy") or
      (.exitCode != 0 and .finishedAt > $cutoff)
    ))
')

payload=$(jq -n \
  --arg date "$(date -Iseconds)" \
  --arg since "$SINCE" \
  --argjson containers "$containers" \
  '{date:$date, since:$since, count:($containers|length), containers:$containers}')

echo "$payload" | curl -fsS -X POST -H 'Content-Type: application/json' -d @- "$WEBHOOK_URL"
