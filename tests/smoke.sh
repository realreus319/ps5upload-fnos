#!/bin/bash
set -euo pipefail
work=$(mktemp -d)
chmod 755 "$work"
export TRIM_UID=65532 TRIM_GID=65532
export TRIM_DATA_SHARE_PATHS="$work/默认 游戏目录" TRIM_PKGVAR="$work/appdata"
mkdir -p "$TRIM_DATA_SHARE_PATHS" "$TRIM_PKGVAR" "$work/existing games" "$work/upload cache"
chmod 755 "$TRIM_DATA_SHARE_PATHS" "$work/existing games"
sudo chown 65532:65532 "$TRIM_PKGVAR" "$work/upload cache"
echo default > "$TRIM_DATA_SHARE_PATHS/default.pkg"
echo existing > "$work/existing games/existing.pkg"
compose(){ docker compose -p ps5upload-fnos -f app/docker/docker-compose.yaml "$@"; }
cleanup(){ compose logs --tail 80 || true; compose down -v || true; sudo rm -rf "$work"; }
trap cleanup EXIT
unset wizard_game_path wizard_staging_path wizard_ps5_addr wizard_data_path
compose config --format json | python3 -c 'import json,os,sys; m=next(x for x in json.load(sys.stdin)["services"]["ps5upload"]["volumes"] if x["target"]=="/data"); assert m["type"]=="bind" and m["source"]==os.environ["TRIM_PKGVAR"]'
compose config -q
compose pull
compose up -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:19113/api/jobs >/dev/null
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /pkgs/default.pkg)" = default; ! touch /pkgs/should-fail; mkdir -p /staging-root/ps5upload-staging; echo staged >/staging-root/ps5upload-staging/probe; echo retained >/data/probe'
test -f "$TRIM_PKGVAR/ps5upload-staging/probe"
test "$(cat "$TRIM_PKGVAR/probe")" = retained
export wizard_game_path="$work/existing games" wizard_staging_path="$work/upload cache" wizard_ps5_addr=192.168.1.177
compose up -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:19113/api/jobs >/dev/null
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
sudo chown 65532:65532 "$wizard_data_path"
compose config --format json | python3 -c 'import json,os,sys; m=next(x for x in json.load(sys.stdin)["services"]["ps5upload"]["volumes"] if x["target"]=="/data"); assert m["type"]=="bind" and m["source"]==os.environ["wizard_data_path"]'
compose up -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:19113/api/jobs >/dev/null
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test ! -e /data/probe; echo custom-data >/data/custom-probe'
test "$(cat "$wizard_data_path/custom-probe")" = custom-data
compose up -d --force-recreate --wait --wait-timeout 120
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /data/custom-probe)" = custom-data'
unset wizard_data_path
compose up -d --wait --wait-timeout 120
docker run --rm --user 65532:65532 --volumes-from ps5upload-fnos busybox:1.37 sh -ec 'test "$(cat /data/probe)" = retained; test ! -e /data/custom-probe'
test "$(cat "$work/应用 data/custom-probe")" = custom-data
echo "Direct wizard variables, custom data path and persistence tests passed"
