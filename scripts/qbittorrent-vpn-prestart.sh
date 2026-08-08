#!/usr/bin/env bash
set -euo pipefail

config_file=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
: "${QBIT_BOOTSTRAP_CONFIG:?QBIT_BOOTSTRAP_CONFIG must be set}"

if [[ ! -e $config_file ]]; then
  install -Dm0600 -o qbittorrent -g media "$QBIT_BOOTSTRAP_CONFIG" "$config_file"
fi

set_preference() {
  local key=$1 value=$2 escaped_key
  escaped_key="$(printf '%s' "$key" | sed 's/\\/\\\\/g')"

  if grep --fixed-strings --quiet "$key=" "$config_file"; then
    sed --in-place "\|^$escaped_key=|c\\$escaped_key=$value" "$config_file"
  else
    sed --in-place "/^\[Preferences\]$/a\\$escaped_key=$value" "$config_file"
  fi
}

# qBittorrent rewrites its config after WebUI changes, so reconcile the VPN
# and proxy/security contract on every start without replacing the
# operator-managed username or password hash.
set_preference 'Connection\Interface' "$QBIT_NETWORK_INTERFACE"
set_preference 'WebUI\CSRFProtection' "$QBIT_WEBUI_CSRF_PROTECTION"
set_preference 'WebUI\HostHeaderValidation' "$QBIT_WEBUI_HOST_HEADER_VALIDATION"
set_preference 'WebUI\MaxAuthenticationFailCount' "$QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT"
