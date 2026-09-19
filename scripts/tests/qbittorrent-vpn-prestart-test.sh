#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/scripts/qbittorrent-vpn-prestart.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

config_file=$tmp/qBittorrent.conf
cat >"$config_file" <<'EOF'
[BitTorrent]
Session\DefaultSavePath=/srv/media/torrents/
Session\ShareLimitAction=Stop

[Preferences]
WebUI\Username=admin
Connection\Interface=eth0
EOF

export QBIT_CONFIG_FILE=$config_file
export QBIT_BOOTSTRAP_CONFIG=$tmp/unused-bootstrap.conf
export QBIT_NETWORK_INTERFACE=wg0-mullvad
export QBIT_WEBUI_CSRF_PROTECTION=true
export QBIT_WEBUI_HOST_HEADER_VALIDATION=false
export QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT=0
export QBIT_GLOBAL_MAX_RATIO=1
export QBIT_GLOBAL_MAX_SEEDING_MINUTES=1440
export QBIT_SHARE_LIMIT_ACTION=RemoveWithContent

bash "$script"

grep --fixed-strings --quiet 'Connection\Interface=wg0-mullvad' "$config_file"
grep --fixed-strings --quiet 'WebUI\CSRFProtection=true' "$config_file"
grep --fixed-strings --quiet 'WebUI\HostHeaderValidation=false' "$config_file"
grep --fixed-strings --quiet 'WebUI\MaxAuthenticationFailCount=0' "$config_file"
grep --fixed-strings --quiet 'Session\GlobalMaxRatio=1' "$config_file"
grep --fixed-strings --quiet 'Session\GlobalMaxSeedingMinutes=1440' "$config_file"
grep --fixed-strings --quiet 'Session\ShareLimitAction=RemoveWithContent' "$config_file"
grep --fixed-strings --quiet 'WebUI\Username=admin' "$config_file"
! grep --fixed-strings --quiet 'Session\ShareLimitAction=Stop' "$config_file"
