#!/usr/bin/env bash
set -euo pipefail

config_file=${QBIT_CONFIG_FILE:-/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf}
: "${QBIT_BOOTSTRAP_CONFIG:?QBIT_BOOTSTRAP_CONFIG must be set}"
: "${QBIT_NETWORK_INTERFACE:?QBIT_NETWORK_INTERFACE must be set}"
: "${QBIT_WEBUI_CSRF_PROTECTION:?QBIT_WEBUI_CSRF_PROTECTION must be set}"
: "${QBIT_WEBUI_HOST_HEADER_VALIDATION:?QBIT_WEBUI_HOST_HEADER_VALIDATION must be set}"
: "${QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT:?QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT must be set}"
: "${QBIT_GLOBAL_MAX_RATIO:?QBIT_GLOBAL_MAX_RATIO must be set}"
: "${QBIT_GLOBAL_MAX_SEEDING_MINUTES:?QBIT_GLOBAL_MAX_SEEDING_MINUTES must be set}"
: "${QBIT_SHARE_LIMIT_ACTION:?QBIT_SHARE_LIMIT_ACTION must be set}"

if [[ ! -e $config_file ]]; then
  install -Dm0600 -o qbittorrent -g media "$QBIT_BOOTSTRAP_CONFIG" "$config_file"
fi

set_ini_value() {
  local section=$1 key=$2 value=$3 escaped_key
  escaped_key="$(printf '%s' "$key" | sed 's/\\/\\\\/g')"

  if grep --fixed-strings --quiet "$key=" "$config_file"; then
    sed --in-place "\|^$escaped_key=|c\\$escaped_key=$value" "$config_file"
  elif grep --quiet "^\[${section}\]$" "$config_file"; then
    sed --in-place "/^\[${section}\]$/a\\$escaped_key=$value" "$config_file"
  else
    printf '\n[%s]\n%s=%s\n' "$section" "$key" "$value" >>"$config_file"
  fi
}

# qBittorrent rewrites its config after WebUI changes, so reconcile the VPN,
# proxy/security, and share-limit contract on every start without replacing the
# operator-managed username or password hash.
set_ini_value Preferences 'Connection\Interface' "$QBIT_NETWORK_INTERFACE"
set_ini_value Preferences 'WebUI\CSRFProtection' "$QBIT_WEBUI_CSRF_PROTECTION"
set_ini_value Preferences 'WebUI\HostHeaderValidation' "$QBIT_WEBUI_HOST_HEADER_VALIDATION"
set_ini_value Preferences 'WebUI\MaxAuthenticationFailCount' "$QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT"
set_ini_value BitTorrent 'Session\GlobalMaxRatio' "$QBIT_GLOBAL_MAX_RATIO"
set_ini_value BitTorrent 'Session\GlobalMaxSeedingMinutes' "$QBIT_GLOBAL_MAX_SEEDING_MINUTES"
set_ini_value BitTorrent 'Session\ShareLimitAction' "$QBIT_SHARE_LIMIT_ACTION"
