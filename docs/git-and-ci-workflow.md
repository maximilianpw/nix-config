# Git merging and dependency-update CI

## Mergiraf

`users/maxpw/modules/git.nix` enables Home Manager's Mergiraf integrations
for Git and Jujutsu. These take effect after the normal host activation;
evaluation and regression builds do not change the active user configuration.

- Git uses Mergiraf as its merge driver, with `diff3` conflict markers.
  Unsupported languages fall back to line-based merging. Conflicts Mergiraf
  cannot resolve remain for manual review.
- Jujutsu uses Mergiraf as the default merge editor. Run `jj resolve`, or
  explicitly `jj resolve --tool mergiraf`. This does not make every JJ merge
  resolve automatically.
- Review successful syntax-aware resolutions with the `mergiraf review <id>`
  command printed by Mergiraf, and run the affected project's tests. A clean
  textual merge is not a semantic correctness guarantee.
- For a new Git operation that should use ordinary merging instead, prefix
  it with `mergiraf=0` in Bash/Fish, or `with-env { mergiraf: "0" } { ... }`
  in Nushell. This does not undo an already completed merge.

Hunk remains the pager. Moved-code colors are configured for Git's own colored
diff output; custom pagers may render differently. Existing rerere and pull
policy are unchanged. `rebase.missingCommitsCheck = "error"` guards accidental
omissions from an interactive-rebase todo list. `push.useForceIfIncludes` adds
protection to applicable force-with-lease invocations; it does not make ordinary
force pushes safe, and does not apply to every explicit lease form.

The `git-merge-regression` flake checks on `aarch64-darwin` and `x86_64-linux`
assert the configured integration and exercise real Git and JJ merges in
isolated fixtures. For example:

```sh
nix build .#checks.aarch64-darwin.git-merge-regression --no-link
```

See [Mergiraf's usage guide](https://mergiraf.org/usage.html) for review,
fallback and conflict-resolution behavior.

## Targeted flake-input update PRs

In GitHub Actions, choose **Update flake inputs → Run workflow** and optionally
supply space-separated public root input names, such as `hyprland` or
`llm-agents home-manager`.

- Empty or whitespace-only selection updates every public root input, as does
  the weekly scheduled run.
- `scripts/ci/select-flake-inputs.sh` reads names from `flake.lock` without
  fetching dependencies. Unknown names, options, nested input paths and the
  private `superlocal` input are rejected before any update.
- Names are sorted and deduplicated. Targeted selections use stable hashed PR
  branches separate from the weekly all-public-input branch.
- Evaluation with the public Superlocal stub still gates PR creation;
  lightweight CI is dispatched afterward with `full_builds=false`. Merge and
  host activation remain manual.

The selector's regression tests run under `make check-scripts`. They use
disposable lockfile fixtures and never call Nix or GitHub.

## CI run policy and time limits

Pushes to `main`, pull requests targeting `main`, and ordinary manual runs use
only the five lightweight Linux jobs: flake health, lint, shell tests,
regression checks (including Mergiraf), and evaluation of Kim, its parked
desktop profile, Cuno and Joyce. These do not build full host systems or WSL
images. Cold dependency downloads/builds can still take time.

Full Kim, Cuno-image and Joyce builds are opt-in: choose **CI → Run workflow**
and enable **full_builds**, or explicitly dispatch:

```sh
gh workflow run ci.yml --ref main -f full_builds=true
```

All five lightweight jobs must pass before the full builds start. Automated
update workflows explicitly pass `full_builds=false`; weekly updates do not
silently trigger host builds. Full runs have a separate concurrency group so
an ordinary check run on the same branch does not cancel an intentional build.
New runs of the same mode and branch still cancel superseded runs.

Job timeouts cap runaway work, not the expected duration:

| Job | Timeout |
| --- | --- |
| Flake health | 5 minutes |
| Lint, shell tests, host evaluation | 10 minutes each |
| Regression checks | 15 minutes |
| Each opt-in full host/image build | 45 minutes |
| Flake-input update | 20 minutes |
| Package update | 30 minutes |

Cold full builds may exceed the 45-minute budget and be cancelled. Build
locally rather than raise that budget by default. Skipped full-build jobs are
not evidence of build success; explicitly request them when needed. Changes
to these workflows take effect on GitHub only after they are pushed.

## Shared Nix setup and health policy

`.github/actions/nix-setup/action.yml` owns the pinned Determinate installer
and optional Magic Nix Cache. Cache is enabled for the lint, shell, regression,
evaluation, Darwin-build and update jobs. Kim/Cuno build jobs keep Cachix
without adding another cache, and flake-health needs no build cache. CI timing
benefits are unmeasured until these workflows run on GitHub.

Flake Checker explicitly checks both `nixpkgs` and `nixpkgs-unstable`, fails on
reported policy violations, and rejects a missing lockfile. Its default owner,
supported-release and age checks remain enabled. This is intentionally stricter
than the previous advisory-only invocation.
