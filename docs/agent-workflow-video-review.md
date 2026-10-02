# Agent workflow video review

Reviewed on 2026-10-02 against nix-config revision `e82647c`, with a limited
read-only look at the separate `pi-config` checkout.

This records what we take from Theo's video
[If you have a Claude sub, watch this](https://www.youtube.com/watch?v=D8PikZ1KhUo)
and what we deliberately do not. The full caption transcript was read. Caption
wording and timestamps may be approximate.

The central lesson is to let agents finish useful, verified work between human
interventions. The persistent T3 server on Kim, the centralized proxy, the Fleet
configuration, and the recovery procedures already support that workflow. The
configuration gaps the review surfaced are tracked in the backlogs, not here.

## Lessons we adopt

| Video section | Speaker's argument | What we take from it |
| --- | --- | --- |
| [30:25](https://www.youtube.com/watch?v=D8PikZ1KhUo&t=1825s) | Verification before merging and easy recovery afterward allow more autonomous work. | Require evidence of the requested behavior and keep a tested recovery path. Repeated agent reviews alone do not establish correctness. |
| [33:20](https://www.youtube.com/watch?v=D8PikZ1KhUo&t=2000s) | Bring agents into problem discovery before prescribing an implementation. | Supply symptoms, constraints, and desired behavior so the agent can look for simpler solutions. |
| [39:40](https://www.youtube.com/watch?v=D8PikZ1KhUo&t=2380s) | Treat threads as tasks and review those that need attention. | Track running, blocked, and completed work. Keep concurrency within our ability to assess results. |
| [46:20](https://www.youtube.com/watch?v=D8PikZ1KhUo&t=2780s) | Ask for the complete deliverable upfront instead of requesting each predictable next step. | Include implementation, relevant verification, and review evidence in the task. Request a preview or PR follow-through when wanted and authorized. |
| [59:06](https://www.youtube.com/watch?v=D8PikZ1KhUo&t=3546s) | Persistent remote development lets work continue after closing a laptop. | Use Kim for longer tasks and return when a decision or result is ready. |

For ordinary coding tasks this means specifying the problem, constraints,
desired result, verification, and authorization boundary upfront. A completed
task should explain what changed, show verification evidence, and name any
remaining decision. Useful measures are the share of tasks accepted without
another instruction round, interventions per task, review time, and regressions
after acceptance. Increase concurrency only while those stay manageable.

## Claims we do not turn into requirements

Unused subscription quota is not, by itself, a reason to generate more work.
The subscription is already paid; speculative changes still consume review time
and create maintenance obligations. Token usage, simultaneous threads, and PR
counts are weak measures of useful output.

The speaker's subscription valuations and claims about account bans, privacy
equivalence, provider margins, and residential proxies were not independently
verified. They should not drive account purchases or authentication changes
without separate research. Categorical claims about operating systems and cloud
hosting do not substitute for measurements of our workloads.

Explicit authorization for publishing, deploying, and live operations stays.
The autonomy worth expanding is investigation, local implementation,
verification, and preparing a result a human can assess.

## What the review surfaced

Checking our setup against the video's assumptions found these gaps. Each is
tracked where it will be worked on.

- The public proxy health route never contacts CLIProxyAPI, and the quota
  service was outside the monitored unit inventory. Both are addressed by a
  fixed-target readiness probe and a start-limited, inventoried quota unit.
  Decided 2026-10-02: crash-loop containment is the accepted contract; no
  pre-activation compatibility preflight for the pi-config checkout.
- Kim declared no build concurrency or service resource weights. Measured
  2026-10-02: one compile saturates all cores with no user-visible service
  degradation. Decision: CPU and IO scheduler weights on the Nix daemon, no
  caps. See `docs/kim-build-contention.md` once merged.
- The shared agent policy references skills that are not installed. See the
  [agent tooling backlog](agent-tooling-backlog.md#prompt-debt-validation).
- Unattended credential scope and a first scheduled report remain open
  decisions, now with more detail in the
  [agent tooling backlog](agent-tooling-backlog.md#deferred-work).

## Review limits

This was a read-only configuration assessment, not a security audit. No live
failure injection, provider inference tests, concurrent build benchmarks, sleep
and reconnect tests, or restore drills were performed. Fleet's external runtime
and individual application repositories were not reviewed.
