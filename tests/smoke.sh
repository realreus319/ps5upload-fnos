#!/bin/bash
set -euo pipefail
work=$(mktemp -d)
chmod 755 "$work"
export TRIM_UID=65532 TRIM_GID=65532
export TRIM_APPDEST="$work/target"
mkdir -p "$TRIM_APPDEST/bin"
cp app/bin/gateway-rust "$TRIM_APPDEST/bin/"
chmod 755 "$TRIM_APPDEST/bin/gateway-rust"
sudo chown 65532:65532 "$TRIM_APPDEST"
export TRIM_DATA_SHARE_PATHS="$work/默认 游戏目录" TRIM_PKGVAR="$work/appdata"
mkdir -p "$TRIM_DATA_SHARE_PATHS" "$TRIM_PKGVAR" "$work/existing games" "$work/upload cache"
chmod 755 "$TRIM_DATA_SHARE_PATHS" "$work/existing games"
sudo chown 65532:65532 "$TRIM_PKGVAR" "$work/upload cache"
echo default > "$TRIM_DATA_SHARE_PATHS/default.pkg"
echo existing > "$work/existing games/existing.pkg"
compose(){ docker compose -p ps5upload-fnos -f app/docker/docker-compose.yaml "$@"; }
cleanup(){ compose logs --tail 80 || true; compose down -v || true; sudo rm -rf "$work"; }
trap cleanup EXIT
unset wizard_game_path wizard_staging_path wizard_ps5_addr wizard_data_path wizard_puid wizard_pgid
compose config --format json | python3 -c 'import json,os,sys; m=next(x for x in json.load(sys.stdin)["services"]["ps5upload"]["volumes"] if x["target"]=="/data"); assert m["type"]=="bind" and m["source"]==os.environ["TRIM_PKGVAR"]'
compose config -q
compose pull
compose up -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:19113/app/ps5upload/api/jobs >/dev/null
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /pkgs/default.pkg)" = default; ! touch /pkgs/should-fail; mkdir -p /staging-root/ps5upload-staging; echo staged >/staging-root/ps5upload-staging/probe; echo retained >/data/probe'
test -f "$TRIM_PKGVAR/ps5upload-staging/probe"
test "$(cat "$TRIM_PKGVAR/probe")" = retained
export wizard_game_path="$work/existing games" wizard_staging_path="$work/upload cache" wizard_ps5_addr=192.168.1.177
compose up -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:19113/app/ps5upload/api/jobs >/dev/null
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' ps5upload-fnos | grep -Fx PS5_ADDR=192.168.1.177
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /pkgs/existing.pkg)" = existing; test ! -e /pkgs/default.pkg; test "$(cat /data/probe)" = retained; ! touch /pkgs/should-fail; mkdir -p /staging-root/ps5upload-staging; echo custom >/staging-root/ps5upload-staging/probe'
test -f "$wizard_staging_path/ps5upload-staging/probe"
compose stop
compose up -d --wait --wait-timeout 120
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /data/probe)" = retained; test "$(cat /staging-root/ps5upload-staging/probe)" = custom'
unset wizard_game_path wizard_staging_path wizard_ps5_addr wizard_data_path
compose up -d --wait --wait-timeout 120
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test -e /pkgs/default.pkg; test "$(cat /data/probe)" = retained; test "$(cat /staging-root/ps5upload-staging/probe)" = staged'
# Verify a custom application-data path and return to fnOS application storage.
export wizard_data_path="$work/应用 data"
mkdir -p "$wizard_data_path"
sudo chown 1000:1000 "$wizard_data_path"
sudo chmod 700 "$wizard_data_path"
compose config --format json | python3 -c 'import json,os,sys; m=next(x for x in json.load(sys.stdin)["services"]["ps5upload"]["volumes"] if x["target"]=="/data"); assert m["type"]=="bind" and m["source"]==os.environ["wizard_data_path"]'
compose up -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:19113/app/ps5upload/api/jobs >/dev/null
docker run --rm --user 1000:1000 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test ! -e /data/probe; echo custom-data >/data/custom-probe; mkdir -p /staging-root/ps5upload-staging; touch /staging-root/ps5upload-staging/custom'
test "$(sudo cat "$wizard_data_path/custom-probe")" = custom-data
sudo test -f "$wizard_data_path/ps5upload-staging/custom"
sudo test -e "$wizard_data_path/.ps5upload/ava/identity"
! compose logs --tail 40 | grep -F "no AVA1 identity at"
compose up -d --force-recreate --wait --wait-timeout 120
docker run --rm --user 1000:1000 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /data/custom-probe)" = custom-data'
unset wizard_data_path
compose up -d --wait --wait-timeout 120
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /data/probe)" = retained; test ! -e /data/custom-probe'
test "$(sudo cat "$work/应用 data/custom-probe")" = custom-data
# Reproduce fnOS private custom directories with a different owner than the package.
export wizard_game_path="$work/private games" wizard_data_path="$work/private data"
mkdir "$wizard_game_path" "$wizard_data_path"
echo private > "$wizard_game_path/private.pkg"
sudo chown -R 1000:1000 "$wizard_game_path" "$wizard_data_path"
sudo chmod 700 "$wizard_game_path" "$wizard_data_path"
compose up -d --wait --wait-timeout 120
docker run --rm --user 1000:1000 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /pkgs/private.pkg)" = private; ! touch /pkgs/should-fail; test -e /data/.ps5upload/ava/identity'
test "$(stat -c %u "$TRIM_APPDEST/app.sock")" = 65532
docker top ps5upload-fnos -eo uid,gid,args
docker top ps5upload-fnos -eo uid,gid,args | grep -E '^ *1000 +1000 +/ps5upload-engine'
docker top ps5upload-fnos -eo uid,gid,args | grep -E '^ *65532 +65532 +/fnos-gateway /gateway/app.sock'
export wizard_puid=1001 wizard_pgid=1001
sudo chown -R 1001:1001 "$wizard_game_path" "$wizard_data_path"
compose up -d --wait --wait-timeout 120
docker top ps5upload-fnos -eo uid,gid,args | grep -E '^ *1001 +1001 +/ps5upload-engine'
docker run --rm --user 1001:1001 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /pkgs/private.pkg)" = private; test -e /data/.ps5upload/ava/identity'
# Actual gateway socket and engine, simulated fnOS administrator headers.
for i in $(seq 1 30); do [ -S "$TRIM_APPDEST/app.sock" ] && break; sleep 1; done
sock="$TRIM_APPDEST/app.sock"
test -S "$sock"
base=http://192.168.1.250:5666/app/ps5upload
test "$(sudo curl -s --unix-socket "$sock" -o /dev/null -w '%{http_code}' "$base/")" = 403
sudo curl -fsS --unix-socket "$sock" -H 'X-Trim-Isadmin: true' -H 'Host: 192.168.1.250:5666' -D "$work/headers" "$base/" > "$work/page"
grep -qi '^x-frame-options: SAMEORIGIN' "$work/headers"
grep -qi "frame-ancestors 'self'" "$work/headers"
sudo curl -fsS --unix-socket "$sock" -H 'X-Trim-Isadmin: true' -H 'Host: 192.168.1.250:5666' -H 'Origin: http://192.168.1.250:5666' "$base/api/jobs" >/dev/null
test "$(compose ps -q | wc -l)" -eq 1
docker inspect -f '{{.Config.Image}}' ps5upload-fnos | grep -Fx ghcr.io/phantomptr/ps5upload-engine-webui:latest
compose stop
test ! -S "$sock"
compose up -d --wait --wait-timeout 120
test -S "$sock"
sudo curl -fsS --unix-socket "$sock" -H 'X-Trim-Isadmin: true' "$base/api/jobs" >/dev/null
echo "Single official container, persistent storage and gateway lifecycle passed"
