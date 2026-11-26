#!/bin/bash
set -euo pipefail
work=$(mktemp -d)
chmod 755 "$work"
export TRIM_UID=65532 TRIM_GID=65532
export TRIM_DATA_SHARE_PATHS="$work/默认 游戏目录"
export TRIM_APPDEST="$work/app"
mkdir -p "$TRIM_DATA_SHARE_PATHS" "$work/existing games" "$TRIM_APPDEST/docker"
cp app/docker/docker-compose.yaml "$TRIM_APPDEST/docker/"
chmod 755 "$TRIM_DATA_SHARE_PATHS" "$work/existing games"
echo default > "$TRIM_DATA_SHARE_PATHS/default.pkg"
echo existing > "$work/existing games/existing.pkg"
compose(){ docker compose -p ps5upload-fnos -f "$TRIM_APPDEST/docker/docker-compose.yaml" "$@"; }
cleanup(){ compose logs --tail 80 || true; compose down -v || true; rm -rf "$work"; }
trap cleanup EXIT
unset TRIM_DATA_ACCESSIBLE_PATHS
compose config -q
compose pull
compose up -d --wait --wait-timeout 120
bash cmd/install_callback
curl -fsS http://127.0.0.1:19113/api/jobs >/dev/null
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /pkgs/default.pkg)" = default; ! touch /pkgs/should-fail; mkdir -p /data/staging; echo retained >/data/staging/smoke'
export TRIM_DATA_ACCESSIBLE_PATHS="$work/existing games"
bash cmd/config_callback
compose up -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:19113/api/jobs >/dev/null
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /pkgs/existing.pkg)" = existing; test ! -e /pkgs/default.pkg; test "$(cat /data/staging/smoke)" = retained; ! touch /pkgs/should-fail'
id=$(docker inspect -f '{{.Id}}' ps5upload-fnos)
bash cmd/config_callback
test "$id" = "$(docker inspect -f '{{.Id}}' ps5upload-fnos)"
# Simulate the package payload being replaced on upgrade.
cp app/docker/docker-compose.yaml "$TRIM_APPDEST/docker/"
bash cmd/upgrade_callback
test "$id" = "$(docker inspect -f '{{.Id}}' ps5upload-fnos)"
compose stop
unset TRIM_DATA_ACCESSIBLE_PATHS
bash cmd/config_callback
test "$(docker inspect -f '{{.State.Running}}' ps5upload-fnos)" = false
compose up -d --wait --wait-timeout 120
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test ! -e /pkgs/existing.pkg; test -e /pkgs/default.pkg; test "$(cat /data/staging/smoke)" = retained'
if TRIM_DATA_ACCESSIBLE_PATHS="/one:/two" bash cmd/config_init; then exit 1; fi
echo "Real container and lifecycle callback smoke test passed"
