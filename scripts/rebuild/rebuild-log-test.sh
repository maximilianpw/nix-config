#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=../rebuild/lib/rebuild-log.sh
source "$here/lib/rebuild-log.sh"

eval_failure=$'warning: Git tree is dirty\nerror:\n       … while evaluating the attribute \'foo\'\n\n       error: attribute \'b\' missing\n\nError: nh trailer\nerror: second error'
expected=$'error:\n       … while evaluating the attribute \'foo\'\n\n       error: attribute \'b\' missing'
actual=$(summarize_rebuild_failure <<< "$eval_failure")
[[ $actual == "$expected" ]] || { printf 'unexpected eval summary:\n%s\n' "$actual" >&2; exit 1; }

activation_failure=$(printf 'line %s\n' $(seq 1 40); echo 'warning: the following units failed: foo.service')
actual=$(summarize_rebuild_failure <<< "$activation_failure")
grep -Fxq 'No Nix error found; last lines of output:' <<< "$actual"
grep -Fxq 'warning: the following units failed: foo.service' <<< "$actual"
if grep -Fxq 'line 10' <<< "$actual"; then
    echo "fallback summary printed more than the tail" >&2
    exit 1
fi

clean=$(printf 'a\n\n\033[2K\033[1mb\033[0m\n' | clean_rebuild_log)
[[ $clean == $'a\n\nb' ]]
[[ $(clean_rebuild_log <<< "$clean") == "$clean" ]]

echo "rebuild log tests passed"
