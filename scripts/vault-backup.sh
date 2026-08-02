#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: vault-backup

Export the self-hosted Bitwarden/Vaultwarden account as password-protected
JSON files under ~/Sync/Recovery/Vaultwarden. The personal vault and every
accessible organization are exported with the same recovery passphrase.
EOF
}

case "${1:-}" in
--help | -h)
  usage
  exit 0
  ;;
"") ;;
*)
  usage >&2
  exit 2
  ;;
esac

: "${VAULTWARDEN_URL:?vault-backup requires VAULTWARDEN_URL}"

sync_root="${VAULT_SYNC_ROOT:-$HOME/Sync}"
backup_dir="${VAULT_BACKUP_DIR:-$sync_root/Recovery/Vaultwarden}"
vault_was_unlocked=false
temporary_files=()

cleanup() {
  local temporary_file

  for temporary_file in "${temporary_files[@]}"; do
    rm -f -- "$temporary_file"
  done

  if [[ "$vault_was_unlocked" == true ]]; then
    bw lock >/dev/null 2>&1 || true
  fi

  unset VAULT_EXPORT_PASSWORD BW_SESSION
}
trap cleanup EXIT

normalize_url() {
  printf '%s' "${1%/}"
}

read_status() {
  bw status
}

validate_export() {
  local export_file=$1

  jq -e '
    type == "object"
    and .encrypted == true
    and .passwordProtected == true
    and (.salt | type == "string" and length > 0)
    and (.data | type == "string" and length > 0)
  ' "$export_file" >/dev/null
}

export_vault() {
  local output_file=$1
  local organization_id=${2:-}

  VAULT_EXPORT_OUTPUT="$output_file" \
    VAULT_EXPORT_ORGANIZATION_ID="$organization_id" \
    expect <<'EOF'
set timeout -1

set export_password $env(VAULT_EXPORT_PASSWORD)
unset env(VAULT_EXPORT_PASSWORD)
set command [list bw export --format encrypted_json --password --output $env(VAULT_EXPORT_OUTPUT)]
if {$env(VAULT_EXPORT_ORGANIZATION_ID) ne ""} {
  lappend command --organizationid $env(VAULT_EXPORT_ORGANIZATION_ID)
}

spawn {*}$command
set prompted 0

expect {
  -re {Export file password:} {
    set prompted 1
    log_user 0
    send -- "$export_password\r"
    log_user 1
    exp_continue
  }
  eof {
    set wait_result [wait]
    set exit_code [lindex $wait_result 3]
    if {$exit_code == 0 && $prompted == 0} {
      puts stderr "Bitwarden did not request an export password"
      exit 1
    }
    exit $exit_code
  }
}
EOF
}

if [[ "$backup_dir" == "$sync_root" || "$backup_dir" == "$sync_root/"* ]]; then
  if [[ ! -d "$sync_root/.stfolder" ]]; then
    echo "error: $sync_root is not an active Syncthing folder (.stfolder is missing)" >&2
    exit 1
  fi
fi

umask 077
mkdir -p -- "$backup_dir"

status_json=$(read_status)
vault_status=$(jq -r '.status' <<<"$status_json")
current_server=$(jq -r '.serverUrl // ""' <<<"$status_json")
expected_server=$(normalize_url "$VAULTWARDEN_URL")

if [[ "$vault_status" == "unauthenticated" ]]; then
  if [[ "$(normalize_url "$current_server")" != "$expected_server" ]]; then
    bw config server "$expected_server" >/dev/null
  fi

  echo "Log in to $expected_server"
  bw login >/dev/null
  status_json=$(read_status)
  vault_status=$(jq -r '.status' <<<"$status_json")
  current_server=$(jq -r '.serverUrl // ""' <<<"$status_json")
fi

if [[ "$(normalize_url "$current_server")" != "$expected_server" ]]; then
  echo "error: Bitwarden CLI is logged in to $current_server, not $expected_server" >&2
  echo "Run 'bw logout' before using vault-backup for the self-hosted vault." >&2
  exit 1
fi

case "$vault_status" in
locked)
  echo "Unlock the Vaultwarden account"
  BW_SESSION=$(bw unlock --raw)
  export BW_SESSION
  vault_was_unlocked=true
  ;;
unlocked) ;;
*)
  echo "error: unexpected Bitwarden vault status: $vault_status" >&2
  exit 1
  ;;
esac

echo "Synchronizing the vault before export..."
bw sync >/dev/null

organizations_json=$(bw list organizations)
organization_ids_text=$(jq -r '
  if type != "array" then error("expected an array of organizations") else . end
  | .[]
  | if (.id | type == "string" and test("^[0-9a-fA-F-]{36}$"))
    then .id
    else error("organization has an invalid id")
    end
' <<<"$organizations_json")
organization_ids=()
if [[ -n "$organization_ids_text" ]]; then
  mapfile -t organization_ids <<<"$organization_ids_text"
fi
unset organizations_json organization_ids_text
export_count=$((1 + ${#organization_ids[@]}))

echo "This will create $export_count password-protected export file(s)."
echo "Use a strong recovery passphrase that is available without Vaultwarden."
if ! IFS= read -r -s -p "Recovery passphrase: " VAULT_EXPORT_PASSWORD; then
  printf '\n' >&2
  exit 1
fi
printf '\n'

if [[ -z "$VAULT_EXPORT_PASSWORD" ]]; then
  echo "error: recovery passphrase cannot be empty" >&2
  exit 1
fi

if ! IFS= read -r -s -p "Confirm recovery passphrase: " confirmation; then
  printf '\n' >&2
  exit 1
fi
printf '\n'

if [[ "$VAULT_EXPORT_PASSWORD" != "$confirmation" ]]; then
  unset confirmation
  echo "error: recovery passphrases do not match" >&2
  exit 1
fi
unset confirmation
export VAULT_EXPORT_PASSWORD

timestamp=$(date -u '+%Y-%m-%dT%H%M%SZ')
final_files=()

personal_file="$backup_dir/vault-$timestamp-personal.encrypted.json"
if [[ -e "$personal_file" ]]; then
  echo "error: export already exists: $personal_file" >&2
  exit 1
fi
personal_temporary=$(mktemp "$backup_dir/.vault-export.XXXXXX")
temporary_files+=("$personal_temporary")
export_vault "$personal_temporary"
validate_export "$personal_temporary"
final_files+=("$personal_file")

for organization_id in "${organization_ids[@]}"; do
  organization_file="$backup_dir/vault-$timestamp-organization-$organization_id.encrypted.json"
  if [[ -e "$organization_file" ]]; then
    echo "error: export already exists: $organization_file" >&2
    exit 1
  fi

  organization_temporary=$(mktemp "$backup_dir/.vault-export.XXXXXX")
  temporary_files+=("$organization_temporary")
  export_vault "$organization_temporary" "$organization_id"
  validate_export "$organization_temporary"
  final_files+=("$organization_file")
done

for index in "${!temporary_files[@]}"; do
  mv -- "${temporary_files[$index]}" "${final_files[$index]}"
done

printf 'Created encrypted Syncthing export:\n'
printf '  %s\n' "${final_files[@]}"
printf '\nAttachments and Sends remain covered by the server-level Borg backup.\n'
