#!/bin/bash
set -euo pipefail
fail(){ printf '%s\n' "$*" > "${TRIM_TEMP_LOGFILE:-/dev/stderr}"; exit 1; }
mode="$1"
: "${TRIM_APPDEST:?}" "${TRIM_PKGVAR:?}" "${TRIM_PKGETC:?}" "${TRIM_UID:?}" "${TRIM_GID:?}"
mkdir -p "$TRIM_PKGETC" "$TRIM_PKGVAR/data"
cfg="$TRIM_PKGETC/ps5upload.env"
dest="$TRIM_APPDEST/docker/.env"
old_path=""; old_ip=""
if [ -f "$cfg" ]; then
 old_path=$(sed -n "s/^GAME_PATH='\(.*\)'$/\1/p" "$cfg")
 old_ip=$(sed -n "s/^ALLOW_IP='\(.*\)'$/\1/p" "$cfg")
fi
game="${wizard_game_path:-$old_path}"
ip="${wizard_allow_ip:-$old_ip}"
[ -n "$game" ] && [ -d "$game" ] || fail "游戏目录不存在"
game=$(realpath -e -- "$game")
# Do not allow arbitrary system directories or dotenv metacharacters.
case "$game" in /vol[0-9]*/*) ;; *) fail "请选择飞牛存储卷中的共享目录";; esac
case "$game$TRIM_PKGVAR" in *"'"*|*$'\n'*|*$'\r'*|*'\\'*) fail "路径包含不支持的字符";; esac
[ -r "$game" ] && [ -x "$game" ] || fail "应用用户没有游戏目录读取权限"
[[ "$ip" =~ ^(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})/(2[4-9]|3[0-2])$ ]] || fail "请输入可信私有 IPv4 网段，掩码 /24 至 /32"
IFS='./' read -r a b c d mask <<< "$ip"
for octet in "$a" "$b" "$c" "$d"; do (( 10#$octet <= 255 )) || fail "IP 地址无效"; done
umask 077
tmp=$(mktemp "$TRIM_PKGETC/.env.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf "GAME_PATH='%s'\nALLOW_IP='%s'\nDATA_PATH='%s'\nENGINE_UID='%s'\nENGINE_GID='%s'\n" "$game" "$ip" "$TRIM_PKGVAR/data" "$TRIM_UID" "$TRIM_GID" > "$tmp"
if [ "$mode" = config ]; then
 docker compose --env-file "$tmp" -f "$TRIM_APPDEST/docker/docker-compose.yaml" -p ps5upload-fnos config -q || fail "Compose 配置无效"
 if [ "$(docker inspect -f '{{.State.Running}}' ps5upload-fnos 2>/dev/null || true)" = true ]; then
  docker compose --env-file "$tmp" -f "$TRIM_APPDEST/docker/docker-compose.yaml" -p ps5upload-fnos up -d || fail "容器重建失败，请检查 Docker 管理器"
 fi
fi
cp "$tmp" "$dest"
mv "$tmp" "$cfg"
