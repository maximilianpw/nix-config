# Plan 012: Reconcile recovery instructions with the archive contract

> Documentation-only implementation. Never execute a restore, mask/unmask, service stop/start, Borg command, activation, database command, or plaintext cleanup from the runbook as verification. Read this plan fully; preserve unrelated work and update its status/index when done.
>
> Drift check: `git diff --stat 9482048 -- docs/homelab-recovery.md lib/homelab-services.nix lib/homelab.nix modules/services/backup.nix docs/media-stack.md docs/leerr.md`. Source files are read-only references; only the documentation scope below may change.

## Status

- Status: DONE — reviewed commit `c127741`, integrated as `62aba74` on `cleanup/2026-09-20-complete`
- Priority: P1
- Effort: M
- Risk: MED: recovery instructions are safety-sensitive even when only prose changes
- Depends on: none
- Category: docs/correctness
- Planned at: commit `9482048`, 2026-09-20

## Context and current state

Kim's service inventory owns recovery contracts. `lib/homelab-inventory.nix` derives `backup.archivePaths` from primary state minus transformed paths plus produced artifacts. `modules/services/backup.nix:69–86` exposes `config.custom.backup.manifestMetadata`, including `expectedArchivePaths`, `expectedPrimaryStatePaths`, application versions, and per-service recovery metadata. **Primary state paths are not necessarily archive members.** An archived manifest and its checkout govern a real restore; today's configuration is only the maintenance reference.

The central runbook repeats manually maintained selections that have drifted:

- `docs/homelab-recovery.md:55–77` masks application services but omits `tunarr.service` and `leerr.service`.
- Its section 3 extraction at lines 88–101 includes `home/maxpw/.local/share/t3code`, but that live directory is excluded from Borg. The same document correctly states at lines 329–338 that its artifact is `var/backup/t3code/state.tar`.
- `lib/homelab-services.nix:370–381` declares `/var/lib/leerr`, `leerr.service`, and `docs/leerr.md#recovery`.
- `lib/homelab-services.nix:849–861` declares `/var/lib/tunarr`, `tunarr.service`, and `docs/media-stack.md#recovery`.
- `lib/homelab-services.nix:923–928` declares:
  ```nix
  state.paths = ["/home/maxpw/.local/share/t3code"];
  backup = {
    strategy = "archive-transform";
    artifacts = ["/var/backup/t3code/state.tar"];
    transformedPaths = ["/home/maxpw/.local/share/t3code"];
  };
  ```
- `docs/media-stack.md:506–526` already owns the media recovery procedure and includes Tunarr. The central runbook's duplicate media subsection omits it.

Preserve the existing safety model: version-matched recovery, a single archive, empty staging/destinations, no automatic activation, isolated ingress, explicit operator decisions, and application acceptance before ingress. This is not permission to implement a restore generator.

## Scope

Only modify `docs/homelab-recovery.md`, this plan's status, and `advisor-plans/README.md`.

Read but do not change the inventory, backup implementation, service runbooks, shell tools, tests, secrets, or live data. Do not redesign PostgreSQL/Paperless recovery or remove their ordering and mutually exclusive restore routes.

## Steps and verification

### 1. Inspect authoritative metadata without touching backups

Run the following local evaluation and retain its non-secret metadata in a task-owned temporary directory:

```sh
scratch=$(mktemp -d)
nix eval --json .#nixosConfigurations.kim.config.custom.backup.manifestMetadata > "$scratch/manifest.json"
python3 - "$scratch/manifest.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
p = set(m['expectedArchivePaths'])
assert {'/var/backup/t3code/state.tar', '/var/lib/tunarr', '/var/lib/leerr'} <= p
assert '/home/maxpw/.local/share/t3code' not in p
print('Archive contract confirmed')
PY
```

Expected: exit 0 and the message. No live archive or credentials are required. Read the full runbook and each referenced service's recovery contract before editing. Compare masks with declared quiesce units, service-start triggers, and the existing explicit ingress/backup/updater protections. Do not conflate operational monitoring units with the exact set that must be masked.

### 2. Repair the staging and service-stop instructions

- Add `tunarr.service` and `leerr.service` to the pre-activation system mask example. Preserve existing masks and the separately scoped T3 Code user-manager instruction.
- In section 3, replace the excluded T3 Code live member with `var/backup/t3code/state.tar`; include `var/lib/tunarr` and `var/lib/leerr`.
- Compare the complete member list against `expectedArchivePaths`, allowing checkout recovery to remain in section 2. If another member is missing, reconcile it from its owning runbook and inventory before adding it. Do not guess archive layout or change backup implementation to match prose.
- Explain immediately before the example that it reflects the maintained revision: operators must reconcile it with the **selected archive's** manifest, transforms, versions, and owning runbooks. The source tree itself is already staged separately. Retain the single-archive and empty-staging requirements.
- Add a read-only metadata inspection example only if useful. It must not automatically generate or execute restore/mask commands.

Verify using the one-off script below after this step. It checks documentation, not a real archive:

```sh
python3 - "$scratch/manifest.json" <<'PY'
import json, pathlib, re, sys
m = json.load(open(sys.argv[1]))
s = pathlib.Path('docs/homelab-recovery.md').read_text()
section = s.split('## 3. Stage the complete recovery point', 1)[1].split('\n## ', 1)[0]
block = re.search(r'```sh\n(.*?)```', section, re.S).group(1)
start = block.index('sudo borg-restore-main')
command = block[start:].replace('\\\n', ' ').splitlines()[0]
selected = command.split()[4:]  # sudo, command, archive, staging destination
required = {p.lstrip('/') for p in m['expectedArchivePaths']}
required.discard('home/maxpw/nix-config')  # section 2 stages the checkout
missing = sorted(p for p in required if not any(p == root or p.startswith(root + '/') for root in selected))
assert not missing, f'Missing documented archive members: {missing}'
assert 'home/maxpw/.local/share/t3code' not in selected
masks = s.split('## 3.', 1)[0]
assert 'tunarr.service' in masks and 'leerr.service' in masks
print('Documented recovery selection matches the archive contract')
PY
```

Expected: exit 0. Keep the recognizable section heading and one explicit extraction example so this check remains unambiguous. If another shell-command shape is necessary, adapt the one-off parser transparently and review its extracted members; do not weaken membership assertions.

### 3. Reduce duplicated service procedures without losing safety gates

Replace the central `### Media stack` step-by-step duplicate with a brief coordination summary and a link to `docs/media-stack.md#recovery`. Keep the central reminders to hold all media writers/readers stopped, restore matching control state, and treat `/srv/media` as excluded/recoverable only from a separate copy. The owning media runbook retains detailed namespace/VPN, start-order, hardlink, and playback/transcode checks.

Add a short `### Leerr` subsection that links `docs/leerr.md#recovery`, identifies its staged state and archived-version requirement, and does not copy the full encryption/login recovery procedure. Preserve all existing section anchors for other services. Retain T3 Code's detailed transformed-artifact explanation.

Verify: `git diff -- docs/homelab-recovery.md` shows only the reconciled lists, ownership explanation, and bounded service subsection changes. `test -f docs/media-stack.md && test -f docs/leerr.md` exits 0. Confirm both linked files still contain `## Recovery` with `grep -n '^## Recovery' docs/media-stack.md docs/leerr.md`.

### 4. Check documentation and record the verification boundary

Run `git diff --check` (exit 0), rerun the metadata/member assertions, and inspect `git diff --stat` for scope. No full build or permanent test is required for this documentation-only fix. Remove only task-created scratch metadata when finished.

Record explicitly: source/manifest agreement was checked; no actual restore, drill, service masking, or archive recoverability was tested. Do not mark a quarterly recovery gate complete.

## Done criteria

- [x] Metadata evaluation and both one-off assertion scripts passed in review.
- [x] All current required archive members are represented in sections 2/3.
- [x] T3 Code uses the transformed artifact, never its excluded live tree, in extraction selection.
- [x] Leerr/Tunarr are held stopped and point to maintained owning runbooks.
- [x] Media recovery has one detailed procedure, not two diverging copies.
- [x] Existing safety gates, PostgreSQL/Paperless branches, and service anchors remain.
- [x] Only allowed source files changed; diff checks passed; plan/index status is DONE.

## STOP conditions and maintenance

Stop if an inventory/manifest contradiction needs production changes, a path's actual archive representation is uncertain, or validation would require a live archive or activation. Report uncertainty rather than inventing a safe-looking command. Local evaluation failure is a blocker to claiming full metadata agreement, not a reason to run recovery tools.

Suggested commit if requested: `Reconcile recovery documentation with archive contracts`. Future service additions and transformed backup changes must update central coordination lists and the owning runbook together. A generated documentation checker may be considered separately; this cleanup does not add another permanent test suite.

## Execution review

Sol implemented the one-file documentation change in
`/home/maxpw/nix-config-cleanup-worktrees/recovery`. Worker assertions verified
all 28 required archive paths after checkout exclusion and all 31 declared
system quiesce units. The coordinator read the full diff and independently
evaluated and compared the archive-path/quiesce metadata. Runbook targets and
whitespace checks passed; the normal generated commit hook completed. Commit
`c127741` leaves a clean worktree. No archive inspection, restore, service mask,
activation, or quarterly recovery acceptance was performed. The reviewed
source commit `c127741` was cherry-picked as `62aba74` on the isolated
integration branch; main remains untouched.
