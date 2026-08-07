# Kim homelab automation and local AI options

## Implementation status

The provider-independent reliability work is implemented in this repository:

- weekly reviewed `flake.lock` pull requests and full-CI dispatch;
- post-switch smoke checks with retries and manual rollback guidance;
- read-only stale Docker-container reporting and Prometheus metrics;
- local Alertmanager routing, adaptive CPU baselines, and operational alerts;
- monthly Borg `--verify-data` checks for the latest archive; and
- optional secret-file wiring for host, backup, and alert webhooks.

External alert delivery and dead-man heartbeats stay inactive until their
provider URLs are supplied. A second off-site Borg destination also needs a
chosen storage target and credentials. No Ollama or other model service is
planned: there is not yet a concrete workload that justifies its shared
CPU/GPU/RAM cost on Kim.

## Recommendation

Kim does not need an autonomous AI operator. The highest-value next step is a
small reliability layer that can report failures outside Kim, followed by a
reviewed update/deployment pipeline. Local AI is a good third layer when it is
kept private, resource-bounded, and read-only.

Recommended order:

1. Choose an off-site encrypted backup target and external webhook/heartbeat
   provider, then activate the prepared secret-file options.
2. Let the adaptive monitoring baseline collect at least 24 hours of history
   before tuning its anomaly threshold.
3. Classify deliberately long-running Docker containers with
   `homelab.keep=true`; keep cleanup manual until the reports are trusted.
4. Complete and record a restore drill from the local and future off-site
   repositories.

## Current fit and gaps

Kim has a Ryzen AI 9 HX 370, 24 CPU threads, 58 GiB of usable RAM, a Radeon
890M, and a detected Ryzen AI NPU at `/dev/accel/accel0`. That is ample for a
small quantized local model, but CPU, GPU, and system memory are shared with the
homelab workloads.

The repository already has unusually strong foundations:

- typed service inventory driving ingress, monitoring, backup expectations,
  and presentation;
- daily Borg backups and weekly incremental checks;
- Prometheus, Grafana, SMART, Uptime Kuma, and runtime smoke checks;
- CI evaluation, regression tests, complete Kim builds, and automated custom
  package update pull requests;
- guarded NixOS rebuilds with generation retention and rollback support.

The important remaining gaps are operational rather than AI-related:

- no configured off-site backup;
- external dead-man and Alertmanager destination URLs are not yet configured;
- the restore-drill directory contains a template but no completed drill;
- custom packages receive update pull requests, but flake inputs do not;
- several development Docker containers can remain running for days without an
  explicit retention policy.

## Phase 1: reliability automation

### Off-site backup and independent heartbeat

Add a second encrypted destination and test extraction from another machine.
The backup coordinator should signal start, success, and failure to a service
outside Kim. Healthchecks.io supports systemd timer schedules, grace periods,
and explicit failure signals; ping URLs must be treated as secrets.

Sources: [Healthchecks.io systemd task monitoring](https://healthchecks.io/docs/monitoring_systemd_tasks/),
[failure signals](https://healthchecks.io/docs/signaling_failures/), and
[Borg repository checks](https://borgbackup.readthedocs.io/en/latest/usage/check.html).

The existing weekly Borg check is a useful fast check. Add a less frequent,
longer `--verify-data` check only after measuring its runtime and I/O impact.
Schedule a real restore drill separately; repository integrity alone does not
prove that application data is recoverable.

### Alert delivery

Route the existing Prometheus alerts through Alertmanager to one tested mobile
destination, such as an Apprise-supported channel or Home Assistant mobile
notification. Alertmanager provides grouping, deduplication, routing,
inhibition, and silencing. It remains local, so the external heartbeat is still
required for host, power, or network loss.

Source: [Prometheus Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/).

### Reviewed updates and safer activation

Extend the existing update workflow with a weekly `flake.lock` pull request.
Renovate's Nix manager understands flake inputs and lock-file maintenance. The
existing CI should remain the merge gate, and activation on Kim should remain a
manual decision because the host contains stateful applications.

After a successful switch, run `homelab-check` with a short retry window and
record the previous generation. Report failures prominently and offer rollback;
do not automatically roll back database migrations.

Source: [Renovate Nix manager](https://docs.renovatebot.com/modules/manager/nix/).

### Development-container hygiene

Add a daily read-only report for containers older than a chosen threshold. It
should show compose project, working directory, age, restart policy, bound
ports, CPU, memory, and disk use. Require an explicit label such as
`homelab.ephemeral=true` before any timer is allowed to stop a container, and a
second label before removal. Production and unlabeled containers should only
generate a report.

This solves a deterministic lifecycle problem and does not need an LLM.

## Deferred local AI options

### Ollama proof of concept (not selected)

Ollama currently lists the Ryzen AI 9 HX 370 among its supported Linux AMD
devices. Nixpkgs provides CPU, ROCm, and Vulkan Ollama packages plus a native
NixOS module with declarative model loading. Because AMD's supported ROCm Linux
matrix is narrower than NixOS, benchmark both Vulkan and ROCm rather than
assuming either path.

Start conservatively:

- one quantized 3B–8B tool-capable model;
- 4K–8K context;
- one loaded model and one parallel request;
- a short keep-alive so the model releases shared memory when idle;
- loopback binding, with access only through an authenticated Tailnet service;
- no public Cloudflare ingress to the unauthenticated model API.

Sources: [Ollama AMD and Vulkan support](https://github.com/ollama/ollama/blob/main/docs/gpu.mdx),
[Ollama FAQ and concurrency controls](https://docs.ollama.com/faq), and
[llama.cpp hardware backends](https://github.com/ggml-org/llama.cpp).

### Read-only alert explainer

The most useful first workload is an event-driven alert explainer:

1. Prometheus and Alertmanager decide that an alert is real.
2. A small service gathers a bounded Prometheus snapshot, the relevant unit
   status, and recent journal lines.
3. Ollama produces a short structured explanation and likely next checks.
4. The notification always includes the raw alert and runbook link, even if the
   model fails.

The model must not restart services, edit configuration, rebuild Kim, or
receive unrestricted tools. Logs and documents are untrusted input and may
contain prompt injection or secrets.

Grafana also publishes a PromQL anomaly-detection framework using recording
rules. It is a lower-risk way to add adaptive baselines for CPU, temperature,
I/O wait, backup duration, and per-service CPU. Anomaly bands are context, not a
replacement for hard health and recovery alerts.

Sources: [Grafana webhook contact points](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/webhook-notifier/)
and [Grafana PromQL anomaly detection](https://github.com/grafana/promql-anomaly-detection).

### Home Assistant

Home Assistant has an official Ollama conversation integration. Device control
is experimental; Home Assistant recommends exposing fewer than 25 entities
when testing local models. Begin with conversation and summaries, then expose a
small set of non-critical entities if the selected model proves reliable.

A fully local voice pipeline is also mature: Speech-to-Phrase or Whisper for
speech recognition, Piper for speech, and openWakeWord through Wyoming.
Speech-to-Phrase is the efficient choice for ordinary home commands; Whisper is
more useful for open-ended LLM conversations.

Sources: [Home Assistant Ollama integration](https://www.home-assistant.io/integrations/ollama/),
[local voice setup](https://www.home-assistant.io/voice_control/voice_remote_local_assistant/),
and [Wyoming integration](https://www.home-assistant.io/integrations/wyoming/).

### Existing document and photo AI

Immich already supplies semantic search, face recognition, and OCR. Its
machine-learning ROCm backend is experimental and substantially heavier than
the native service, so the current VA-API video offload should be evaluated
before adding another Immich acceleration path.

Paperless-ngx development documentation contains native local AI features, but
Kim should wait until those features reach the pinned stable package rather
than adding a separate Paperless AI sidecar with another state and security
boundary.

Sources: [Immich search](https://docs.immich.app/features/searching/),
[Immich ML acceleration](https://docs.immich.app/features/ml-hardware-acceleration/),
and [Paperless-ngx advanced usage development documentation](https://github.com/paperless-ngx/paperless-ngx/blob/dev/docs/advanced_usage.md).

## What not to add yet

- Do not use the LLM as the monitoring decision-maker or self-healing control
  plane.
- Do not deploy the full n8n AI starter stack merely to connect one webhook; it
  duplicates PostgreSQL and adds Qdrant plus another stateful UI. Add n8n only
  after identifying several durable cross-service workflows.
- Do not target the Ryzen NPU first. The kernel driver is active, but AMD's
  Linux SDK uses a specialized, Ubuntu-oriented runtime and preprocessed model
  flows; it does not transparently accelerate Ollama, Immich, or Home Assistant
  on NixOS.
- Do not enable unattended `system.autoUpgrade` for this stateful host. Reviewed
  update pull requests plus a manual promotion step provide most of the value
  without turning application migrations into an automatic event.

Sources: [n8n self-hosted AI starter kit](https://github.com/n8n-io/self-hosted-ai-starter-kit)
and [AMD Ryzen AI Linux requirements](https://ryzenai.docs.amd.com/en/latest/linux.html).

## Implemented first slice

The repository now contains:

1. Alertmanager with optional delivery to a tested webhook destination.
2. Optional external heartbeats for Borg backup success and host availability.
3. Weekly flake-input update pull requests.
4. Post-switch `homelab-check` reporting.
5. A stale Docker-container report with no deletion behavior.

The external options remain intentionally unset until a provider and secret
paths are chosen. Ollama remains deferred until a useful workload is identified.
