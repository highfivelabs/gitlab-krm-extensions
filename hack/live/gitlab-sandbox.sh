#!/usr/bin/env bash
# Copyright 2026 High Five Labs
# SPDX-License-Identifier: Apache-2.0
#
# GitLab CE in Docker: no account, no secret. The live tests point at it
# (task live:gitlab); so can a person applying the samples by hand.
#
#   hack/live/gitlab-sandbox.sh up      # start GitLab, wait until healthy, make a root token; prints URL and token
#   hack/live/gitlab-sandbox.sh creds   # the credentials JSON KRM_LIVE_CREDS takes
#   hack/live/gitlab-sandbox.sh run     # up, then TestEveryKindLive (-tags live)
#   hack/live/gitlab-sandbox.sh down    # remove the container and its token
#
# GitLab CE needs about 4 GB of RAM and 3 to 10 minutes to boot: run it on an
# offload VM, not a laptop, and run the tests on the same machine (the
# harness takes KRM_LIVE_CREDS only for an API on 127.0.0.1):
#
#   offload run --machine e2-standard-4 --idle-minutes 60 -- task live:gitlab
#
# The image is the newest GitLab CE release at or before the pinned spec
# (gitlab-org/gitlab@35ad75ae is 19.6.0-pre, 2026-11-14; 19.6 is not
# released, so 19.5.5). GitLab Premium/Ultimate kinds are listed with skip:
# in live.yaml. The container keeps nothing on disk: down forgets it all.
set -o errexit -o nounset -o pipefail
cd "$(dirname "$0")/../.."

image=${GITLAB_IMAGE:-gitlab/gitlab-ce:19.5.5-ce.0}
port=${GITLAB_PORT:-8929}
name=${GITLAB_SANDBOX_NAME:-hfl-live-gitlab}
state=${GITLAB_SANDBOX_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/hfl-live-gitlab}
addr="http://127.0.0.1:${port}"

running() { [[ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" == true ]]; }

up() {
  mkdir -p "$state" && chmod 700 "$state"
  if ! running; then
    docker rm -f "$name" >/dev/null 2>&1 || true
    rm -f "$state/token"
    local password
    password="hfl-live-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
    # The API listens on 127.0.0.1 only. Prometheus and extra workers are off
    # to keep memory near 4 GB; Pages is on so PagesDomain can run.
    docker run -d --name "$name" --shm-size 256m -p "127.0.0.1:${port}:80" \
      -e GITLAB_ROOT_PASSWORD="$password" \
      -e GITLAB_OMNIBUS_CONFIG="external_url 'http://127.0.0.1'; pages_external_url 'http://pages.hfl-live.example'; prometheus_monitoring['enable'] = false; puma['worker_processes'] = 0; sidekiq['concurrency'] = 5" \
      "$image" >/dev/null
  fi

  echo "== waiting for GitLab ($image) to be healthy" >&2
  local i ready=""
  for i in $(seq 160); do
    # /-/readiness answers only GitLab's monitoring allowlist, which a
    # request through Docker's port mapping is not on: the sign-in page and
    # the container's own health check instead.
    if [[ "$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null)" == healthy ]] &&
      curl -fsS -o /dev/null "${addr}/users/sign_in" 2>/dev/null; then ready=1; break; fi
    running || { docker logs --tail 100 "$name" >&2; echo "GitLab exited" >&2; exit 1; }
    ((i % 4 == 0)) && echo "   still booting ($((i * 15 / 60)) min): $(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo '?')" >&2
    sleep 15
  done
  [[ -n "$ready" ]] || { docker logs --tail 100 "$name" >&2; echo "GitLab did not come up in 40 minutes" >&2; exit 1; }

  if [[ ! -s "$state/token" ]]; then
    echo "== making root's personal access token (api scope)" >&2
    local token
    token=$(docker exec "$name" gitlab-rails runner '
      u = User.find_by_username("root")
      t = u.personal_access_tokens.new(scopes: ["api", "read_api", "sudo"], name: "hfl-live", expires_at: 7.days.from_now)
      if t.respond_to?(:organization_id=) && t.organization_id.nil?
        t.organization_id = (Organizations::Organization.first&.id rescue nil)
      end
      t.save!
      puts "TOKEN=#{t.token}"
    ' 2>/dev/null | sed -n 's/^TOKEN=//p' | tail -1)
    [[ -n "$token" ]] || { echo "could not make a token" >&2; exit 1; }
    (umask 077 && printf '%s' "$token" >"$state/token")
  fi
  local version
  version=$(curl -fsS -H "PRIVATE-TOKEN: $(cat "$state/token")" "${addr}/api/v4/version" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
  echo "gitlab ${version}: ${addr}/api/v4 (container ${name})" >&2
  echo "GITLAB_BASE_URL=${addr}/api/v4"
  echo "GITLAB_TOKEN=$(cat "$state/token")"
}

down() {
  docker rm -f "$name" >/dev/null 2>&1 || true
  rm -rf "$state"
  echo "gitlab sandbox removed" >&2
}

creds() {
  [[ -s "$state/token" ]] || { echo "no sandbox token: run $0 up" >&2; exit 1; }
  printf '{"token":"%s","baseURL":"%s/api/v4"}\n' "$(cat "$state/token")" "$addr"
}

run() {
  up >/dev/null
  local status=0
  KRM_LIVE=1 KRM_LIVE_CREDS="$(creds)" \
    go test -tags live -run '^TestEveryKindLive$' -count=1 -v -timeout 90m . "$@" || status=$?
  if [[ -f hack/live/records.json ]]; then
    mkdir -p offload-artifacts/live
    cp hack/live/records.json offload-artifacts/live/gitlab-records.json
  fi
  return "$status"
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  creds) creds ;;
  run) shift; run "$@" ;;
  *) echo "usage: $0 up|down|creds|run [go test args]" >&2; exit 2 ;;
esac
