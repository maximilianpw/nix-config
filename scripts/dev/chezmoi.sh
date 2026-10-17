#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/MaxPW777/dotfiles.git}"
SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi}"

usage() {
    echo "usage: $0 {bootstrap|check|preview|apply}" >&2
}

require_chezmoi() {
    if ! command -v chezmoi >/dev/null 2>&1; then
        echo "chezmoi is not on PATH; apply the Nix/Home Manager config first." >&2
        exit 1
    fi
}

command="${1:-}"
case "$command" in
    bootstrap)
        require_chezmoi
        if [[ -d "$SOURCE_DIR/.git" ]]; then
            echo "chezmoi source already initialized at $SOURCE_DIR"
        elif [[ -e "$SOURCE_DIR" ]]; then
            echo "Refusing to replace non-Git source directory: $SOURCE_DIR" >&2
            exit 1
        else
            # init clones only; applying remains a separate, reviewable step.
            chezmoi --source "$SOURCE_DIR" init --guess-repo-url=false "$DOTFILES_REPO_URL"
        fi
        "$0" check
        ;;
    check)
        require_chezmoi
        [[ -d "$SOURCE_DIR/.git" ]] || {
            echo "No chezmoi source at $SOURCE_DIR; run '$0 bootstrap' first." >&2
            exit 1
        }
        # Render and plan every target without scripts, external refreshes, or
        # destination writes. This catches invalid source state safely.
        chezmoi --source "$SOURCE_DIR" --refresh-externals=never --no-tty --dry-run apply >/dev/null
        echo "chezmoi source renders successfully"
        ;;
    preview)
        require_chezmoi
        chezmoi --source "$SOURCE_DIR" --refresh-externals=never --no-pager diff
        ;;
    apply)
        require_chezmoi
        echo "Reviewing managed-file changes before interactive apply..."
        chezmoi --source "$SOURCE_DIR" --refresh-externals=never --no-pager diff
        # Interactive mode requires confirmation for changed/pre-existing files.
        chezmoi --source "$SOURCE_DIR" --refresh-externals=never --interactive apply
        ;;
    *)
        usage
        exit 2
        ;;
esac
