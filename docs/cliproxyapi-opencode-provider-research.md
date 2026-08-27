# OpenCode Zen as a CLIProxyAPI upstream provider — research notes

Scope: can **OpenCode Zen** be configured as an *upstream* provider inside
CLIProxyAPI (CPA), which config block applies, and what the protocol and
authentication constraints are.

All claims below come from first-party sources: the CLIProxyAPI repository
(source and `config.example.yaml`), the OpenCode documentation source in
`sst/opencode`, the `models.dev` provider registry maintained by the same team,
and live unauthenticated probes of the Zen endpoints themselves.

Verified on 2026-08-27 against CLIProxyAPI `main` at commit
[`4b5f1ea`](https://github.com/router-for-me/CLIProxyAPI/commit/4b5f1eab25fca4b3815369a826e958e7c070a69e)
(2026-08-27), release `v7.2.143`; this repository pins `7.2.140`
(`packages/cliproxyapi.nix`).

---

## 0. Short answer

**Yes — for one of Zen's four protocol families, via the `openai-compatibility`
block.**

Zen is not one API. It is four differently-shaped endpoints behind one host,
each with its *own* required authentication header. CPA's provider blocks are
also protocol-specific. So "add Zen to CPA" is not a single provider entry; it
is up to three separate entries, only one of which is fully clean:

| Zen protocol family | CPA block | Verdict |
|---|---|---|
| Chat Completions | `openai-compatibility` | **Works.** URL and auth match exactly. Recommended first step. |
| OpenAI Responses | `codex-api-key` (with `base-url`) | Very likely works; URL and auth match exactly. Untested without a key. |
| Anthropic Messages | `claude-api-key` (with `base-url`) | **Auth mismatch.** CPA sends `Authorization: Bearer` to non-Anthropic hosts; Zen's `/messages` requires `x-api-key`. Workable only via a `headers:` override. |
| Google Gemini | `gemini-api-key` (with `base-url`) | **Not addressable.** CPA hardcodes `/v1beta/` into the path; Zen serves `/zen/v1/models/...`. |

A single `openai-compatibility` provider **cannot** represent all four. It can
serve *downstream* clients speaking any protocol, but it only ever talks one
protocol *upstream*: Chat Completions. See §4.

### Ox Alpha status

Ox Alpha was a temporary free stealth model. Zen exposed it as
`x-preview-f-free`, while OpenCode Go used `ox-alpha-free`. OpenCode removed it
from both catalogs in commit
[`ec25388`](https://github.com/anomalyco/opencode/commit/ec25388937666a71fcf8715020fe4be678843a2b).
A later OpenCode stats change maps `ox-alpha`, `ox-alpha-free`, and
`x-preview-f` to `glm-5.3-flash`, identifying the preview as GLM 5.3 Flash
([`1120d07`](https://github.com/anomalyco/opencode/commit/1120d0704e7b84cdda07b7dd291958caf95fa53a)).
Neither the retired aliases nor `glm-5.3-flash` appear in Zen's live model
catalog as of 2026-08-27, so the implementation must not declare them.

---

## 1. Downstream client vs. upstream gateway — do not conflate

Two unrelated things share the "OpenCode" name in this repo's context:

- **OpenCode CLI** — a coding agent. In this configuration it is a *downstream
  client* of CPA: `modules/cliproxyapi/home-manager.nix` writes
  `~/.config/opencode/opencode.json` with `provider.cliproxyapi.options.baseURL
  = "http://127.0.0.1:8317/v1"`. Requests flow OpenCode CLI → CPA → whatever
  credential CPA selects. CPA already has first-class support for this
  direction: its credential selector recognises OpenCode's
  `X-Session-Affinity` header for session-sticky routing
  ([`sdk/cliproxy/auth/selector.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/sdk/cliproxy/auth/selector.go#L896),
  and `config.example.yaml` line 222).
- **OpenCode Zen** — a hosted AI gateway sold by the same team, reachable at
  `https://opencode.ai/zen/v1`. This is the *upstream* side: CPA → Zen →
  model. Zen is "completely optional" to OpenCode CLI and "works like any other
  provider"
  ([`zen.mdx`](https://github.com/sst/opencode/blob/dev/packages/web/src/content/docs/zen.mdx)).

This document is about the second. Adding Zen upstream does not change, replace,
or require the existing OpenCode CLI downstream wiring, and vice versa.

---

## 2. What OpenCode Zen actually exposes

### 2.1 Base URL

`https://opencode.ai/zen/v1` — stated as the provider `api` field in the
models.dev registry entry:

```json
{"id":"opencode","env":["OPENCODE_API_KEY"],"npm":"@ai-sdk/openai-compatible",
 "api":"https://opencode.ai/zen/v1","name":"OpenCode Zen",
 "doc":"https://opencode.ai/docs/zen"}
```

(source: [`https://models.dev/api.json`](https://models.dev/api.json), key
`opencode`, fetched 2026-08-27)

`GET https://opencode.ai/zen/v1/models` is public (HTTP 200, no auth) and
returns an OpenAI-shaped list — 63 model ids on 2026-08-27.

### 2.2 Four endpoints, keyed by model

The Zen docs publish an explicit per-model endpoint table
([`zen.mdx` "Endpoints"](https://github.com/sst/opencode/blob/dev/packages/web/src/content/docs/zen.mdx);
rendered at [opencode.ai/docs/zen](https://opencode.ai/docs/zen)):

| Endpoint | AI SDK package | Protocol |
|---|---|---|
| `https://opencode.ai/zen/v1/responses` | `@ai-sdk/openai` | OpenAI Responses |
| `https://opencode.ai/zen/v1/messages` | `@ai-sdk/anthropic` | Anthropic Messages |
| `https://opencode.ai/zen/v1/chat/completions` | `@ai-sdk/openai-compatible` | OpenAI Chat Completions |
| `https://opencode.ai/zen/v1/models/<model-id>` | `@ai-sdk/google` | Google GenerativeLanguage |

The same split is machine-readable in models.dev: the provider default is
`@ai-sdk/openai-compatible`, and individual models override it with
`provider.npm`. Cross-referencing the 63 live model ids against models.dev
gives the authoritative partition:

- **Responses (25):** `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`, `gpt-5.5`,
  `gpt-5.5-pro`, `gpt-5.4`, `gpt-5.4-pro`, `gpt-5.4-mini`, `gpt-5.4-nano`,
  `gpt-5.3-codex-spark`, `gpt-5.3-codex`, `gpt-5.2`, `gpt-5.2-codex`, `gpt-5.1`,
  `gpt-5.1-codex-max`, `gpt-5.1-codex`, `gpt-5.1-codex-mini`, `gpt-5`,
  `gpt-5-codex`, `gpt-5-nano`, `grok-build-0.1`, `grok-4.6`, `grok-4.5`,
  `muse-spark-1.2`, `muse-spark-1.2-contributor-free`
- **Anthropic Messages (13):** `claude-fable-5`, `claude-opus-5`,
  `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-opus-4-5`,
  `claude-sonnet-5`, `claude-sonnet-4-6`, `claude-sonnet-4-5`, `claude-sonnet-4`,
  `claude-haiku-4-5`, `qwen3.6-plus`, `qwen3.5-plus`
- **Chat Completions (19):** `deepseek-v4-pro`, `deepseek-v4-flash`,
  `deepseek-v4-flash-free`, `glm-5.2`, `glm-5.1`, `glm-5`, `minimax-m3`,
  `minimax-m2.7`, `minimax-m2.5`, `kimi-k3`, `kimi-k2.7-code`, `kimi-k2.6`,
  `kimi-k2.5`, `big-pickle`, `mimo-v2.5-free`, `hy3-free`,
  `nemotron-3-ultra-free`, `nemotron-3.5-lightning-free`, `laguna-s-2.1-free`
- **Gemini (6):** `gemini-3.7-flash`, `gemini-3.6-flash`, `gemini-3.5-flash`,
  `gemini-3.5-flash-lite`, `gemini-3.1-pro`, `gemini-3-flash`

Note the model-id spelling difference between families: Claude ids use dashes
(`claude-opus-4-5`), Gemini and the rest use dots (`gemini-3.7-flash`,
`kimi-k2.7-code`).

### 2.3 Authentication is per-endpoint, and strict

The Zen docs do **not** document the auth header. Determined empirically on
2026-08-27 by sending a deliberately invalid key (`sk-bogus`) to each endpoint
and reading the discriminating error — `"Missing API key."` means the header
was not recognised at all, `"Invalid API key."` means the header was parsed and
the key was rejected:

| Endpoint | `Authorization: Bearer` | `x-api-key` | `x-goog-api-key` |
|---|---|---|---|
| `/zen/v1/chat/completions` | **Invalid API key** ✅ | Missing API key ❌ | Missing API key ❌ |
| `/zen/v1/responses` | **Invalid API key** ✅ | Missing API key ❌ | Missing API key ❌ |
| `/zen/v1/messages` | Missing API key ❌ | **Invalid API key** ✅ | — |
| `/zen/v1/models/<id>:generateContent` | Missing API key ❌ | — | **Invalid API key** ✅ |

All responses were HTTP 401 with body
`{"type":"error","error":{"type":"AuthError","message":"..."}}`.

Two further probe results that matter for the workarounds in §5:

- Sending **both** `Authorization: Bearer sk-bogus` and `x-api-key: sk-bogus`
  to `/messages` yields `"Invalid API key."` — i.e. Zen prefers `x-api-key` and
  tolerates a simultaneous `Authorization` header.
- `POST /zen/v1/models/gemini-3.7-flash:streamGenerateContent` with
  `x-goog-api-key` yields `"Invalid API key."` — so Zen does implement Google's
  `:generateContent` / `:streamGenerateContent` verb suffixes, even though the
  docs table shows the bare `/models/<id>` path.
- `POST /zen/v1beta/models/gemini-3.7-flash:generateContent` returns the
  marketing HTML page, not JSON — there is no `v1beta` prefix.

In short: each Zen endpoint accepts exactly the auth header native to the
protocol it emulates, and rejects the others.

---

## 3. What CLIProxyAPI's provider blocks actually send

Read from source at commit `4b5f1ea`.

### 3.1 `openai-compatibility` — Chat Completions

- **URL:** `strings.TrimSuffix(baseURL, "/") + "/chat/completions"`
  ([`openai_compat_executor.go:358`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/openai_compat_executor.go#L358);
  the endpoint constant is set at
  [line 107](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/openai_compat_executor.go#L107)).
- **Auth:** `Authorization: Bearer <api-key>` (same file, lines 62, 153, 247,
  365, 604).
- With `base-url: "https://opencode.ai/zen/v1"` this produces exactly
  `https://opencode.ai/zen/v1/chat/completions` with a Bearer token. **Exact
  match** for Zen's Chat Completions family.

**CPA already knows about Zen here.** A regression test in CPA's own tree is
named for it:

> `// Some OpenAI-compatible upstreams (e.g. OpenCode zen) append non-spec`
> `// metadata after data: [DONE]. Those trailing events must not be forwarded,`
> `// otherwise clients that treat every pre-[DONE] data line as a chat chunk`
> `// fail to deserialize (e.g. missing required "id").`

— [`openai_compat_executor_compact_test.go`, `TestOpenAICompatExecutorStreamDropsChunksAfterDone`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/openai_compat_executor_compact_test.go#L1145).
The test drives the executor with `base_url` ending in `/v1` and model
`deepseek-v4-flash-free` — a real Zen Chat Completions model id. This is the
strongest available evidence that `openai-compatibility` is the intended fit,
and that Zen's post-`[DONE]` `{"choices":[],"cost":"0"}` SSE frame is already
handled. The fix is present in the pinned `v7.2.140` (verified: the same test
exists at tag `v7.2.140`), so this repo needs no version bump for it.

### 3.2 `codex-api-key` — OpenAI Responses

- **URL:** `strings.TrimSuffix(baseURL, "/") + "/responses"`
  ([`codex_executor_execute.go:76`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/codex_executor_execute.go#L76),
  [`codex_executor_stream.go:82`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/codex_executor_stream.go#L82)).
- **Auth:** unconditionally `Authorization: Bearer <api-key>`
  ([`codex_executor_request.go:57-59`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/codex_executor_request.go#L57)).
- `base-url: "https://opencode.ai/zen/v1"` → `https://opencode.ai/zen/v1/responses`
  with Bearer. **Exact match** for Zen's Responses family.
- Codex CLI disguise headers (`Originator`, ChatGPT account id) are applied only
  when the credential is *not* an API key (`isAPIKey := codexAuthUsesAPIKey(auth)`,
  same file ~line 354), and `config.example.yaml` states `codex-header-defaults`
  "do not apply to `codex-api-key` entries". So a Zen `codex-api-key` entry sends
  a plain Responses request without OpenAI-specific cloaking. Low risk, but
  unverified against a live key.

### 3.3 `claude-api-key` — Anthropic Messages (auth mismatch)

CPA chooses the Claude auth header by *host*:

```go
isAnthropicBase := isAnthropicUpstreamURL(r.URL)
if strings.TrimSpace(apiKey) != "" {
    if isAnthropicBase && useAPIKey {
        r.Header.Del("Authorization")
        r.Header.Set("x-api-key", apiKey)
    } else {
        r.Header.Del("x-api-key")
        r.Header.Set("Authorization", "Bearer "+apiKey)
    }
}
```

— [`claude_executor_request.go:701-712`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/claude_executor_request.go#L701)
(the same rule is duplicated in `PrepareRequest`,
[`claude_executor.go:214-227`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/claude_executor.go#L214)).
`config.example.yaml` states the same intent explicitly: *"Auth scheme stays API
key (x-api-key on api.anthropic.com; Bearer on custom base-url)."*

`opencode.ai` is not an Anthropic host, so CPA would send `Authorization: Bearer`
— precisely the header Zen's `/messages` rejects with `"Missing API key."`. **A
plain `claude-api-key` entry pointed at Zen will 401 on every request.**

There is a mechanical escape hatch: per-entry `headers:` are applied *after* the
auth header, via `util.ApplyCustomHeadersFromAttrs`, which `Set`s each value
([`header_helpers.go:76-94`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/util/header_helpers.go#L76);
called at the end of `applyClaudeHeadersWithNativeProfile` in both the execute
and stream paths). So `headers: { x-api-key: "<zen key>" }` re-adds the header
Zen wants, and §2.3 confirms Zen tolerates the leftover `Authorization` header.
This duplicates the secret into a second config field and depends on ordering
that is an implementation detail, not a documented contract. Treat it as a
follow-up experiment, not a first move.

A second, softer concern: the Claude executor also applies request *cloaking*
(Claude Code CLI user-agent, `Anthropic-Beta` assembly, system-prompt
replacement) to non-Claude-Code clients by default (`cloak.mode: "auto"`). For a
third-party gateway that behaviour is unnecessary; `cloak.mode: "never"` would
be the conservative setting if this path is ever pursued.

### 3.4 `gemini-api-key` — not addressable

CPA builds Gemini URLs as
`fmt.Sprintf("%s/%s/models/%s:%s", baseURL, glAPIVersion, baseModel, action)`
with `glAPIVersion = "v1beta"` hardcoded
([`gemini_executor.go:34`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/gemini_executor.go#L34),
[line 176](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/gemini_executor.go#L176),
[line 288](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/gemini_executor.go#L288)).
The auth header is `x-goog-api-key` (line 90 and following), which *is* what Zen
wants — but no value of `base-url` can produce `/zen/v1/models/...`, because CPA
always inserts `/v1beta/` between the base and `models/`. Setting
`base-url: "https://opencode.ai/zen"` yields `.../zen/v1beta/models/...`, which
§2.3 shows returns the marketing HTML page.

**Zen's Gemini models are unreachable from CPA today** without an upstream
change to CPA (making the API version configurable). The Gemini models are also
absent from the other three Zen endpoints, so there is no fallback route.

---

## 4. Can one `openai-compatibility` provider represent all four protocols?

**No — not upstream. Yes — downstream.** The distinction is the whole point of
CPA and is worth stating precisely.

- **Upstream (CPA → Zen): one protocol only.** The executor hardcodes
  `to := sdktranslator.FromString("openai")` and `endpoint := "/chat/completions"`
  ([`openai_compat_executor.go:106-107`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/openai_compat_executor.go#L106)).
  The only variation is `opts.Alt == "responses/compact"`, which switches to
  `/responses/compact` — a Codex conversation-compaction side path, not a general
  Responses transport. An `openai-compatibility` provider therefore *always*
  speaks Chat Completions to the upstream, and can never reach `/responses`,
  `/messages`, or `/models/<id>`.

- **Downstream (client → CPA): all protocols.** The executor translates from
  whatever the client sent: `from := opts.SourceFormat`, then
  `sdktranslator` converts `from → openai`. So Claude Code (Anthropic Messages),
  Codex (Responses), a Gemini client, and a plain Chat Completions client can all
  target a Zen-backed `openai-compatibility` model, and CPA down-converts each to
  Chat Completions on the wire.

The practical consequence: **one provider entry per Zen protocol family.** A
complete Zen integration is an `openai-compatibility` entry *plus* a
`codex-api-key` entry *plus* (only with the header workaround) a
`claude-api-key` entry — three copies of the same secret, three sets of
`models:` lists. That is the cost of Zen's design, not of CPA's.

There is a lossy shortcut worth naming and rejecting: because CPA translates
downstream protocols, you *could* declare Zen's Claude and GPT models under the
single `openai-compatibility` entry and let CPA down-convert everything to Chat
Completions. Whether Zen's `/chat/completions` accepts `claude-*` or `gpt-*`
model ids at all is **unverified** (auth fails before model routing on an
unauthenticated probe, so this cannot be tested without a real key), and the
published per-model endpoint table says it should not. Even if it worked, it
would route Claude models through a Chat Completions down-conversion — losing
thinking blocks and Anthropic-native tool semantics — which defeats the purpose.

---

## 5. Recommended first implementation

Add **one** provider covering only the Chat Completions family. It is the only
configuration where CPA's URL construction and auth header match Zen exactly,
and where CPA has a named regression test for Zen's wire quirks.

### 5.1 Why prefix it

The shared server YAML is rendered by `modules/cliproxyapi/config.nix`
(`mkServerConfig`), which currently emits only `host`/`port`/`auth-dir`/
`api-keys`/`remote-management`/`routing`/`usage-statistics-enabled`. The existing
setup already serves model names that **collide** with Zen ids: `kimi-k3` and
`grok-4.6` are referenced in `modules/cliproxyapi/home-manager.nix`, and
`defaultModel = "gpt-5.6-sol"` in `config.nix`. Zen publishes `kimi-k3` and
`gpt-5.6-sol` under the same names.

`config.example.yaml` documents `prefix` on `openai-compatibility` as: *"optional:
require calls like `test/kimi-k2` to target this provider's credentials."* Using
`prefix: "zen"` makes every Zen model addressable as `zen/<id>` and leaves the
existing OAuth-backed routing for `kimi-k3` / `gpt-5.6-sol` completely untouched.
This keeps the change additive and trivially revertible — nothing that works
today changes behaviour.

### 5.2 The YAML to render

To be appended by `mkServerConfig` in `modules/cliproxyapi/config.nix`. Shown
here as literal YAML; the key must be secret-managed (see §5.3) rather than
inlined as below.

```yaml
# Keep Zen's overlapping model IDs from participating in unprefixed routing.
force-model-prefix: true

openai-compatibility:
  - name: "opencode-zen"
    prefix: "zen"
    base-url: "https://opencode.ai/zen/v1"
    api-key-entries:
      - api-key: "<OPENCODE_API_KEY>"
    models:
      - name: "kimi-k3"
        alias: "kimi-k3"
      - name: "minimax-m3"
        alias: "minimax-m3"
      - name: "glm-5.2"
        alias: "glm-5.2"
      - name: "deepseek-v4-pro"
        alias: "deepseek-v4-pro"
```

The implementation declares 10 models. It keeps the latest configured model in
each paid family, distinct current tiers, Big Pickle, and free models that
models.dev does not mark deprecated. Older non-deprecated versions
`glm-5.1`, `minimax-m2.7`, `kimi-k2.6`, and `kimi-k2.7-code` are intentionally
omitted from the curated proxy catalog because newer models from those families
are already present. Model display names, context lengths, and text/image
capabilities come from the OpenCode-owned
[`models.dev/api.json`](https://models.dev/api.json) catalog; audio and video are
excluded because CLIProxyAPI's OpenAI-compatible model metadata only supports
text and image inputs.

`models:` is an explicit list with no upstream discovery (the
`Models []OpenAICompatibilityModel` field is required; there is no auto-fetch
of `/v1/models` for this block, see
[`config_types.go:649-688`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/config/config_types.go#L649)),
so each entry is a deliberate choice rather than a bulk import that silently
rots as Zen deprecates ids.

Verification after a rebuild:

```bash
curl -s http://127.0.0.1:8317/v1/models -H "Authorization: Bearer <local key>" \
  | jq -r '.data[].id' | grep '^zen/'
curl -s http://127.0.0.1:8317/v1/chat/completions \
  -H "Authorization: Bearer <local key>" -H 'content-type: application/json' \
  -d '{"model":"zen/kimi-k3","messages":[{"role":"user","content":"say hi"}]}'
```

### 5.3 Secret handling

`apiKey` and `managementKeyHash` are local-only values, but a Zen key is a real
billable credential and must not become a Nix literal. The implementation stores
it as `opencode-zen-api-key` in `secrets/secrets.yaml` and uses a sops-nix
template to render the complete CLIProxyAPI configuration at activation time.
Nix evaluation sees only the sops placeholder, so the Zen key does not enter the
Nix store. NixOS, WSL, and Darwin all call the same `mkServerConfig` function and
point their process adapter at the rendered runtime path.

### 5.4 Explicitly deferred

- **Responses family (`codex-api-key` + `base-url`).** Mechanically correct on
  both URL and auth, and it would unlock `gpt-5.6-*` and `grok-4.*` through Zen.
  Deferred only because it is unverified against a live key and because it
  overlaps with credentials already configured. Do this second, once the Chat
  Completions path is proven.
- **Anthropic Messages family.** Blocked on the auth mismatch in §3.3. The
  `headers: { x-api-key: ... }` override is plausible and the probe in §2.3
  suggests Zen would accept it, but it duplicates the secret and leans on
  undocumented ordering. Consider filing an upstream issue asking CPA to send
  `x-api-key` for non-Anthropic Messages gateways, or to expose an auth-scheme
  toggle on `claude-api-key`.
- **Gemini family.** Blocked upstream in CPA (§3.4). Requires making
  `glAPIVersion` configurable. Nothing to do locally.

---

## 6. Open questions requiring a live Zen key

1. Does `/zen/v1/chat/completions` accept only its 19 documented model ids, or
   does it also route `claude-*` / `gpt-*` / `gemini-*`? (Cannot be probed
   unauthenticated — auth is rejected before model routing.)
2. Does `codex-api-key` + `base-url` against `/zen/v1/responses` work end to end,
   including streaming and reasoning-effort passthrough?
3. Does the `claude-api-key` + `headers: { x-api-key: ... }` override actually
   authenticate, and does Zen tolerate CPA's `Anthropic-Beta` header assembly?
4. Does Zen rate-limit or bill differently per protocol family?

---

## 7. Sources

- CLIProxyAPI repository — <https://github.com/router-for-me/CLIProxyAPI> (commit
  `4b5f1eab25fca4b3815369a826e958e7c070a69e`, 2026-08-27; release `v7.2.143`)
  - [`config.example.yaml`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/config.example.yaml) — `openai-compatibility` block at line 611, `codex-api-key` at 390, `claude-api-key` at 466, `gemini-api-key` at 318
  - [`internal/runtime/executor/openai_compat_executor.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/openai_compat_executor.go)
  - [`internal/runtime/executor/openai_compat_executor_compact_test.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/openai_compat_executor_compact_test.go)
  - [`internal/runtime/executor/claude_executor_request.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/claude_executor_request.go)
  - [`internal/runtime/executor/codex_executor_execute.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/codex_executor_execute.go)
  - [`internal/runtime/executor/gemini_executor.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/gemini_executor.go)
  - [`internal/util/header_helpers.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/util/header_helpers.go)
  - [`internal/config/config_types.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/config/config_types.go)
  - [`sdk/cliproxy/auth/selector.go`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/sdk/cliproxy/auth/selector.go)
- OpenCode Zen documentation — <https://opencode.ai/docs/zen>, source at
  [`sst/opencode:packages/web/src/content/docs/zen.mdx`](https://github.com/sst/opencode/blob/dev/packages/web/src/content/docs/zen.mdx)
- models.dev provider registry — <https://models.dev/api.json> (key `opencode`),
  fetched 2026-08-27
- Live Zen endpoints — `https://opencode.ai/zen/v1/models` (public), plus
  unauthenticated 401 probes of `/chat/completions`, `/responses`, `/messages`,
  and `/models/<id>:generateContent`, run 2026-08-27
- This repository — `modules/cliproxyapi/config.nix`,
  `modules/cliproxyapi/home-manager.nix`, `packages/cliproxyapi.nix`
