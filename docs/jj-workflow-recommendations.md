# Jujutsu: agent workspaces and stacked PRs

The jj configuration lives in `users/maxpw/modules/vcs/jujutsu.nix`.
Home Manager installs jj, jjui, and `bos/jj-stack`; the existing tmux and Herdr
jjui shortcuts remain unchanged. Apply these settings through the normal host
rebuild workflow. Building or testing this flake does not activate them.

## Everyday commands

| Command | Behavior |
| --- | --- |
| `jj f` | Fetch Git refs. No extra GitHub cleanup hook. |
| `jj tug <bookmark>` | Advance the named bookmark to `@-`. Without a name, select the nearest mutable bookmark, never trunk by default. |
| `jj check-stack <command> [args...]` | Check nonempty mutable ancestors of `@` without saving changes made by the command. |
| `jj stack <command>` | Run the pinned `bos/jj-stack` CLI. |
| `jj sync` | Run `jj-stack sync --all` for this repository's tracked stacks. |

In a stack, name the bookmark when using `tug`: otherwise the nearest bookmark
could belong to a lower PR. The old `tidy` and `tidy-all` aliases were removed:
their revsets could abandon unmerged ancestors of retained bookmarks.

Descriptions beginning with `wip:` or `private:` are blocked by
`git.private-commits` when pushing with jj. This is not a secret scanner, and it
does not constrain arbitrary Git or third-party pushes. `--allow-private` can
bypass the guard. Sign-on-push remains enabled.

## Automatic bookmark cleanup

No new cleanup setting is needed. `git.abandon-unreachable-commits = true`
remains enabled, and bookmarks pushed by jj are tracked automatically.

After a remote branch is deleted, run `jj f`:

- An unchanged local tracking bookmark is deleted automatically.
- A locally rewritten/moved bookmark becomes conflicted instead of losing work.
- An untracked local bookmark stays untouched.
- Commits that become unreachable can be abandoned; this is not a general test
  for whether an arbitrary local change has been squash-merged.

Use `jj bookmark list --tracked` to inspect tracking. For an existing branch:

```sh
jj bookmark track my-feature --remote origin
```

`jj bookmark forget my-feature` removes the local name without scheduling remote
deletion or abandoning its underlying changes. Remote deletion alone is not
proof that the work was merged; do not use it to discard unpublished edits.

## Stacked GitHub PRs

The installed tool is **bos/jj-stack**, not the unrelated npm project with the
same executable name. It maps one local jj change to one GitHub PR and follows
stable change IDs through amendments and rebases. It requires push access to the
same github.com repository; fork-only contributions and GitHub Enterprise Server
are not supported by the pinned version.

Start with inspection:

```sh
jj stack doctor
jj stack view --json <head-change-id>
```

When publishing is authorized:

```sh
jj stack submit <head-change-id>
```

After GitHub finishes merging a tracked stack, including a squash merge:

```sh
jj sync
```

**`jj sync` is mutating:** it can remove obsolete local changes, rebase the
remaining work, update/push remaining PR branches, and delete obsolete remote
branches. It handles all locally tracked stacks, not every old PR in the repo.
For a single stack, use `jj stack sync <head-change-id>`. It is never invoked by
`jj f` or shell startup. Agents must get explicit authorization before publishing,
merging, or running remote cleanup.

If trunk merely advances without a merge, fetch and rebase deliberately, then
submit; `sync` is for completed merges/stack synchronization, not a general
replacement for rebase. On conflicts or partial failure, inspect the result and
follow the recovery command rather than blindly retrying.

`doctor --fix` modifies local fetch rules/bookkeeping. Inspect plain `doctor`
first. Use explicit head change IDs in automation, especially while editing a
lower layer. The tool's lock only coordinates its own mutating commands, not
independent jj or Git commands.

## Agents and verification

Enable the non-interactive profile only for the agent process:

```sh
JJ_AGENT=1 pi
# Or another coding-agent executable.
```

The profile disables pagination/color, uses Git-format diffs and snapshot-style
conflict markers, and fails instead of opening an interactive editor. Supply
commit messages with `-m`. The normal human editor and diff pager stay unchanged.
This scope is opt-in; it is not exported globally or injected into every agent
launcher.

For independent editing agents explicitly requested by the user:

```sh
jj workspace add --colocate --name agent-auth -r 'trunk()' ../project-agent-auth
```

Give each agent its own directory and change. Workspaces isolate files, not the
repository history or bookmarks: coordinate rebases, bookmark movement, cleanup,
and publication. Leave stale-workspace detection enabled rather than silently
updating an agent's files. `jj workspace remove` deletes the directory, including
ignored files. `jj op restore` is repository-wide recovery, not per-agent undo.

jj 0.46.0 still lacks full native Git submodule management. For a parent repo
such as `vev-docker-compose`, use Git for submodule initialization, updates, and
pointer commits, while using jj inside each service repository. Colocated
workspaces do not initialize submodules recursively. The new template support
for reading submodule commit IDs is inspection support, not lifecycle management.
See the [open submodule tracking issue](https://github.com/jj-vcs/jj/issues/494).

Examples of non-mutating stack checks:

```sh
jj check-stack make lint
jj check-stack npm test
# Explicit head when currently editing a lower layer:
jj run --ignore-changes -r 'trunk()..<head-change-id>' -- <project-check>
```

Each isolated checkout needs its own dependencies/environment. Without
`--ignore-changes`, `jj run` may amend commits. Do not use `--ignore-errors` for a
verification gate: it prevents failed child commands from determining jj run's
exit status. The alias checks ancestors, not descendants above the current
revision, and skips empty commits.

## Packaging and regression checks

jj comes from the existing unstable overlay. The jj-stack input pins revision
`2524ab09ee01b4fa2f43e829b20e45a9a68bc1fa`: its Nix packaging was added after
v0.1.7. It retains its own nixpkgs pin for Python 3.14 and dependency overrides.
The package is exposed as `packages.<system>.jj-stack` on Darwin and Linux.

```sh
nix build .#jj-stack --no-link
nix build .#checks.aarch64-darwin.jujutsu-workflow-regression --no-link
nix build .#checks.x86_64-linux.jujutsu-workflow-regression --no-link
```

The regression check uses the actual Home Manager-generated TOML, disposable
repositories, and local bare Git remotes. It covers the push guard, agent scope,
non-mutating checks/failure propagation, bookmark movement, unchanged/modified/
untracked bookmark cleanup after squash merges, and packaged CLI aliases.
It does not publish to GitHub or validate a live repository's permissions.

## References

- [jj 0.46.0: colocated additional workspaces and cross-workspace undo protection](https://github.com/jj-vcs/jj/releases/tag/v0.46.0)
- [jj bookmark tracking](https://docs.jj-vcs.dev/v0.46.0/bookmarks/#remotes-and-tracked-bookmarks)
- [jj configuration](https://docs.jj-vcs.dev/v0.46.0/config/)
- [bos/jj-stack](https://github.com/bos/jj-stack)
- [jj-stack automation](https://www.serpentine.com/software/jj-stack/reference/automation/)
- [jj-stack merge and sync](https://www.serpentine.com/software/jj-stack/guides/merge-and-sync/)
