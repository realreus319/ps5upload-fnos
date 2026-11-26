#!/bin/bash
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/中文 game" "$work/staging" "$work/data"
touch "$work/file"
export TRIM_TEMP_LOGFILE="$work/error.log"
unset wizard_game_path wizard_staging_path wizard_data_path
for hook in install_init install_callback config_init config_callback; do
  script="cmd/$hook"
  bash "$script"
  wizard_game_path="$work/中文 game" wizard_staging_path="$work/staging" wizard_data_path="$work/data" bash "$script"
  if wizard_game_path="$work/missing" wizard_staging_path="$work/file" wizard_data_path=relative bash "$script"; then
    echo "Invalid paths accepted by $hook" >&2; exit 1
  fi
  grep -F "游戏目录" "$TRIM_TEMP_LOGFILE"
  grep -F "临时安装包目录" "$TRIM_TEMP_LOGFILE"
  grep -F "应用数据目录" "$TRIM_TEMP_LOGFILE"
  if wizard_data_path=/ bash "$script"; then exit 1; fi
  if wizard_game_path="$work/a:b" bash "$script"; then exit 1; fi
  if [ "$(id -u)" != 0 ]; then
    chmod 500 "$work/data"
    wizard_data_path="$work/data" bash "$script"
    chmod 000 "$work/data"
    wizard_game_path="$work/data" wizard_data_path="$work/data" bash "$script"
    chmod 700 "$work/data"
    mkdir -p "$work/private/child"
    chmod 000 "$work/private"
    wizard_game_path="$work/private/child" bash "$script"
    chmod 700 "$work/private"
  fi
done
echo "Path checks passed"
