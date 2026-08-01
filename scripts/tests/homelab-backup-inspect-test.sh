#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
inspect="$repo_root/scripts/homelab-backup-inspect.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/ha/hass"
printf 'configuration\n' > "$tmp/ha/hass/configuration.yaml"
tar -cf "$tmp/ha.tar" -C "$tmp/ha" hass

cat > "$tmp/good.jsonl" <<'EOF'
{"path":"var/backup/homelab/manifest.json"}
{"path":"var/backup/home-assistant/config.tar"}
{"path":"var/backup/postgresql/all.sql.zstd"}
{"path":"srv/paperless/export/manifest.json"}
{"path":"srv/paperless/consume"}
{"path":"srv/paperless/media/documents/originals/example.pdf"}
{"path":"srv/nextcloud/config/config.php"}
{"path":"var/lib/private/uptime-kuma/kuma.db"}
{"path":"var/lib/bitwarden_rs/rsa_key.pem"}
{"path":"home/maxpw/nix-config/flake.nix"}
{"path":"home/maxpw/.local/share/t3code/userdata/state.sqlite"}
{"path":"srv/new-service/data"}
EOF
cat > "$tmp/missing.jsonl" <<'EOF'
{"path":"var/backup/homelab/manifest.json"}
EOF
cat > "$tmp/manifest.json" <<'EOF'
{
  "schemaVersion": 1,
  "gitRevision": "test",
  "gitDirty": false,
  "expectedArchivePaths": [
    "/var/backup/homelab/manifest.json",
    "/var/backup/home-assistant/config.tar",
    "/var/backup/postgresql",
    "/srv/paperless/export",
    "/srv/paperless/consume",
    "/srv/paperless/media",
    "/srv/nextcloud",
    "/var/lib/private/uptime-kuma",
    "/var/lib/bitwarden_rs",
    "/home/maxpw/nix-config",
    "/home/maxpw/.local/share/t3code",
    "/srv/new-service"
  ]
}
EOF
grep -Fv 'srv/new-service/data' "$tmp/good.jsonl" > "$tmp/drift.jsonl"

cat > "$tmp/borg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FIXTURE_DIR/calls"
if [[ $1 == list && $2 == --json && $# == 2 ]]; then
  printf '%s\n' '{"archives":[{"name":"good","start":"2026-08-01","id":"abc"}]}'
elif [[ $1 == list && $2 == --json-lines ]]; then
  case "$3" in
    ::good) cat "$FIXTURE_DIR/good.jsonl" ;;
    ::missing) cat "$FIXTURE_DIR/missing.jsonl" ;;
    ::drift) cat "$FIXTURE_DIR/drift.jsonl" ;;
    *) exit 2 ;;
  esac
elif [[ $1 == info && $2 == --json ]]; then
  printf '%s\n' "{\"archives\":[{\"name\":\"${3#::}\"}]}"
elif [[ $1 == extract && $2 == --stdout ]]; then
  case "$4" in
    var/backup/homelab/manifest.json) cat "$FIXTURE_DIR/manifest.json" ;;
    var/backup/home-assistant/config.tar) cat "$FIXTURE_DIR/ha.tar" ;;
    *) exit 2 ;;
  esac
else
  echo "unexpected Borg invocation: $*" >&2
  exit 2
fi
EOF
chmod +x "$tmp/borg"

export FIXTURE_DIR=$tmp
export BORG_BIN=$tmp/borg
export JQ_BIN
JQ_BIN=$(command -v jq)
export TAR_BIN
TAR_BIN=$(command -v tar)

bash "$inspect" > "$tmp/list.out"
grep -Fq $'good\t2026-08-01\tabc' "$tmp/list.out"
bash "$inspect" good > "$tmp/good.out"
grep -Fq 'Archive inspection passed; no files were restored' "$tmp/good.out"
if bash "$inspect" missing > "$tmp/missing.out" 2> "$tmp/missing.err"; then
  echo "incomplete archive unexpectedly passed inspection" >&2
  exit 1
fi
grep -Fq 'MISSING: var/backup/home-assistant/config.tar' "$tmp/missing.err"
if bash "$inspect" drift > "$tmp/drift.out" 2> "$tmp/drift.err"; then
  echo "manifest-declared service missing from archive unexpectedly passed" >&2
  exit 1
fi
grep -Fq 'MISSING: srv/new-service' "$tmp/drift.err"

if grep -Ev '^(list --json|list --json-lines ::[^ ]+|info --json ::[^ ]+|extract --stdout ::[^ ]+ (var/backup/homelab/manifest\.json|var/backup/home-assistant/config\.tar))$' "$tmp/calls" | grep -q .; then
  echo "inspector issued a mutating or unrecognized Borg command" >&2
  exit 1
fi

echo "homelab backup inspector tests passed"
