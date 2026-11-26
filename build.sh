#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
root="$PWD"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
python3 scripts/icons.py
mkdir -p "$stage/ps5upload"
cp -a manifest ICON.PNG ICON_256.PNG app cmd config wizard "$stage/ps5upload/"
for hook in install_init install_callback uninstall_init uninstall_callback upgrade_init upgrade_callback config_init config_callback; do
  if [ ! -f "$stage/ps5upload/cmd/$hook" ]; then
    printf '#!/bin/bash\nexit 0\n' > "$stage/ps5upload/cmd/$hook"
  fi
done
chmod +x "$stage/ps5upload/cmd/"*
(cd "$stage" && fnpack build -d "$stage/ps5upload")
shopt -s nullglob
files=("$stage/"*.fpk)
[ "${#files[@]}" -eq 1 ] || { echo "Expected exactly one FPK" >&2; exit 1; }
cp "${files[0]}" "$root/ps5upload.fpk"
test -s "$root/ps5upload.fpk"
