import { test, expect } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { BridgeError, atomicJson, bridge, command, locations } from "./bridge-lib.mjs";
import { annotationContext, exactTranscript, navigateNeovim, setup, socketCandidates } from "./tools.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.join(os.homedir(), ".config/herdr/plugins/github/annotate-9c299759567c");

function fixture(body) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "herdr-port-test-")));
  const env = { ...process.env, HERDR_APP_HOME: path.join(root, "app"), HERDR_LEGACY_HOME: path.join(root, "legacy") };
  fs.mkdirSync(env.HERDR_APP_HOME, { recursive: true });
  fs.mkdirSync(env.HERDR_LEGACY_HOME);
  fs.writeFileSync(path.join(env.HERDR_LEGACY_HOME, "plugins.json"), JSON.stringify([{ plugin_id: "annotate", enabled: true, plugin_root: pluginRoot }]));
  try {
    const value = body({ root, env, loc: locations(env) });
    if (value?.then) return value.finally(() => fs.rmSync(root, { recursive: true, force: true }));
    fs.rmSync(root, { recursive: true, force: true });
    return value;
  } catch (error) { fs.rmSync(root, { recursive: true, force: true }); throw error; }
}

function terminal(overrides = {}) {
  return { address: "t1", state: "live", cwd: "/repo", reported: true, status: { app: "pi", state: "idle" }, foreground: { pid: 123, name: "pi", cwd: "/repo", argv: ["pi"] }, ...overrides };
}
const pins = { MIGRATED_TARGET_ADDRESS: "t1", MIGRATED_TARGET_PID: "123", MIGRATED_TARGET_APP: "pi" };

function inventory({ live = [terminal()], spaces = [{ id: "s1", folder: "/repo", machine: null, tabs: [{ terminals: [{ terminal: "t1", pane: "p1" }] }] }], onDo } = {}) {
  return (binary, args) => {
    if (binary === "hc" && args[0] === "ls") return JSON.stringify({ terminals: live.map(({ address, state, cwd }) => ({ address, state, cwd })) });
    if (binary === "hc" && args[0] === "get") return JSON.stringify(live.find((t) => t.address === args[1]));
    if (binary === "herdr-app" && args[0] === "ls") return JSON.stringify({ spaces });
    if (binary === "herdr-app" && args[0] === "do") return JSON.stringify(onDo ? onDo(args) : { ok: true });
    throw new Error(`Unexpected command ${binary} ${args.join(" ")}`);
  };
}

test("compatibility calls have no fallback to the legacy binary", () => {
  for (const args of [["server", "stop"], ["plugin", "pane", "open"], ["pane", "resize"], ["unknown"]]) {
    expect(() => bridge(args, { run: () => { throw new Error("must not execute"); } })).toThrow(BridgeError);
  }
});

test("cleanup inventory covers hidden local programs and excludes remote cwd namespaces", () => fixture(({ env }) => {
  const run = inventory({ live: [terminal(), terminal({ address: "t2", cwd: "/repo/other", foreground: { pid: 124, cwd: "/repo/other" } }), terminal({ address: "kim/t1", cwd: "/remote" })] });
  const panes = bridge(["pane", "list"], { env, run }).result.panes;
  expect(panes.map((p) => p.pane_id)).toEqual(["p1", "t2"]);
  expect(panes[1].workspace_id).toBe("unshown");
}));

test("an empty local space folder resolves to this machine's home, not an invalid checkout", () => fixture(({ env }) => {
  const run = inventory({ spaces: [{ id: "home", folder: "", machine: null, tabs: [] }] });
  const spaces = bridge(["workspace", "list"], { env, run }).result.workspaces;
  expect(spaces[0].worktree.checkout_path).toBe(os.homedir());
}));

test("unknown live terminal directories fail closed before archival", () => fixture(({ env }) => {
  expect(() => bridge(["pane", "list"], { env, run: inventory({ live: [terminal({ cwd: null, foreground: null })] }) })).toThrow("unknown directory");
}));

test("opening records a durable checkout binding and deduplicates App spaces", () => fixture(({ root, env, loc }) => {
  const checkout = path.join(root, "checkout with spaces");
  fs.mkdirSync(checkout);
  let created = 0;
  const run = inventory({ spaces: [], onDo: (args) => {
    expect(args[1]).toBe("space.new");
    expect(args[args.indexOf("--folder") + 1]).toBe(checkout);
    created++;
    return { space: "new-space" };
  } });
  const result = bridge(["worktree", "open", "--path", checkout, "--label", "jj: example", "--focus"], { env, run });
  expect(result.result.workspace_id).toBe("new-space");
  expect(JSON.parse(fs.readFileSync(loc.bindings, "utf8"))["new-space"]).toBe(checkout);
  expect(created).toBe(1);
  const rebound = inventory({ spaces: [{ id: "new-space", folder: root, machine: null, tabs: [] }], onDo: (args) => { expect(args[1]).toBe("space.select"); return { ok: true }; } });
  bridge(["worktree", "open", "--path", checkout, "--focus"], { env, run: rebound });
  const listed = bridge(["workspace", "list"], { env, run: rebound }).result.workspaces;
  expect(listed[0].worktree.checkout_path).toBe(checkout);
}));

test("metadata ignores stale sequence numbers and retains clear tokens", () => fixture(({ env, loc }) => {
  bridge(["workspace", "report-metadata", "s1", "--seq", "20", "--token", "vcs_status=jj abc ~2", "--clear-token", "vcs_bookmark"], { env });
  bridge(["workspace", "report-metadata", "s1", "--seq", "19", "--token", "vcs_status=stale"], { env });
  const value = JSON.parse(fs.readFileSync(loc.metadata, "utf8")).s1;
  expect(value.tokens).toEqual({ vcs_status: "jj abc ~2", vcs_bookmark: "" });
  expect(fs.statSync(loc.metadata).mode & 0o777).toBe(0o600);
}));

test("expired VCS cache entries do not accumulate as spaces close", () => fixture(({ env, loc }) => {
  atomicJson(loc.metadata, { closed: { seq: 1, expires: 0, tokens: { vcs_status: "expired" } } });
  bridge(["workspace", "report-metadata", "active", "--seq", "20", "--token", "vcs_status=jj active"], { env });
  const cache = JSON.parse(fs.readFileSync(loc.metadata, "utf8"));
  expect(Object.keys(cache)).toEqual(["active"]);
}));

test("feedback is pinned to the original address, agent, and foreground pid", () => fixture(({ env }) => {
  const calls = [];
  const run = (binary, args) => {
    calls.push([binary, args]);
    if (args[0] === "get") return JSON.stringify(terminal());
    if (args[0] === "send") return JSON.stringify({ turn: 3, started: true });
    throw new Error("unexpected");
  };
  const result = bridge(["agent", "prompt", "t1", "Review feedback"], { env: { ...env, ...pins }, run });
  expect(result.result.started).toBe(true);
  expect(calls[1]).toEqual(["hc", ["send", "--json", "t1", "--", "Review feedback"]]);
  for (const changed of [terminal({ foreground: { pid: 999 } }), terminal({ status: { app: "codex", state: "idle" } })]) {
    expect(() => bridge(["agent", "prompt", "t1", "No"], { env: { ...env, ...pins }, run: () => JSON.stringify(changed) })).toThrow("changed or restarted");
  }
  expect(() => bridge(["agent", "prompt", "t2", "No"], { env: { ...env, ...pins }, run })).toThrow("not explicitly pinned");
}));

test("a submitted but unobserved prompt is reported as uncertain without resubmission", () => fixture(({ env }) => {
  let sends = 0;
  expect(() => bridge(["agent", "prompt", "t1", "Feedback"], { env: { ...env, ...pins }, run: (_binary, args) => {
    if (args[0] === "get") return JSON.stringify(terminal());
    sends++;
    return JSON.stringify({ turn: 3, started: false });
  } })).toThrow("Inspect the original agent");
  expect(sends).toBe(1);
}));

test("blocked agents are never force-prompted", () => fixture(({ env }) => {
  const calls = [];
  try {
    bridge(["agent", "prompt", "t1", "Feedback"], { env: { ...env, ...pins }, run: (binary, args) => {
      calls.push(args[0]);
      return JSON.stringify(terminal({ status: { app: "pi", state: "blocked" } }));
    } });
    throw new Error("expected refusal");
  } catch (error) { expect(error.code).toBe("agent_blocked"); }
  expect(calls).toEqual(["get"]);
}));

test("legacy journal receipts are copied once without changing the source", () => fixture(({ env, loc }) => {
  const source = path.join(env.HERDR_LEGACY_HOME, "plugins/config/personal.herdr-jj/state/repo");
  fs.mkdirSync(source, { recursive: true });
  fs.writeFileSync(path.join(source, "cleanup-example.json"), '{"phase":"archived"}');
  const installed = setup(env);
  const copied = path.join(installed.jjState, "repo/cleanup-example.json");
  expect(fs.readFileSync(copied, "utf8")).toBe('{"phase":"archived"}');
  fs.writeFileSync(path.join(source, "later.json"), "{}");
  setup(env);
  expect(fs.existsSync(path.join(installed.jjState, "repo/later.json"))).toBe(false);
  expect(fs.statSync(loc.requests).mode & 0o777).toBe(0o700);
}));

test("active legacy locks or journal symlinks prevent import", () => fixture(({ env }) => {
  const source = path.join(env.HERDR_LEGACY_HOME, "plugins/config/personal.herdr-jj/state/repo");
  fs.mkdirSync(path.join(source, "lock"), { recursive: true });
  expect(() => setup(env)).toThrow("locked");
  fs.rmdirSync(path.join(source, "lock"));
  fs.symlinkSync("/tmp", path.join(source, "unsafe"));
  expect(() => setup(env)).toThrow("symlink");
}));

test("annotation export uses the original JSONL schema without touching legacy stores", () => fixture(async ({ env }) => {
  const loc = setup(env);
  fs.writeFileSync(path.join(loc.annotations, "annotations.jsonl"), JSON.stringify({ selectedText: "quoted", capturedAt: "2026-01-01", context: { workspace_label: "fixture" }, id: "a1", comment: "comment", createdAt: "2026-01-01" }) + "\n", { mode: 0o600 });
  const result = await annotationContext(env);
  expect(result.count).toBe(1);
  expect(result.text).toContain("quoted");
  expect(result.text).toContain("comment");
  fs.appendFileSync(path.join(loc.annotations, "annotations.jsonl"), "broken\n");
  await expect(annotationContext(env)).rejects.toThrow("invalid data");
}));

test("transcript selection requires one process-associated file, not a newest-session heuristic", () => {
  const agent = terminal({ status: { app: "claude-code", state: "idle" } });
  const first = "/Users/fixture/.claude/projects/project/one.jsonl";
  const second = "/Users/fixture/.claude/projects/project/two.jsonl";
  expect(exactTranscript(agent, () => `n${first}\n`)).toBe(first);
  expect(exactTranscript(agent, () => `n${first}\nn${second}\n`)).toBe(null);
  expect(exactTranscript(agent, () => "")).toBe(null);
});

test("socket discovery keeps absolute Unix socket names and rejects peer descriptions", () => {
  expect(socketCandidates("p123\nn/tmp/editor.sock type=STREAM\nn->0x123\nn/tmp/editor.sock type=STREAM\n")).toEqual(["/tmp/editor.sock"]);
});

test("unverified Neovim sockets never move an unrelated editor", () => {
  let mutated = false;
  const run = (binary, args) => {
    if (binary === "hc") return JSON.stringify(terminal({ foreground: { pid: 123, name: "nvim" } }));
    if (binary === "lsof") return "n/tmp/socket\n";
    if (args.at(-1) === "getpid()") return "456";
    mutated = true;
    return "1";
  };
  expect(navigateNeovim("t1", 123, "left", run).route).toBe("terminal");
  expect(mutated).toBe(false);
});

test("Neovim navigation uses a real isolated RPC server and falls back at window edges", () => fixture(async ({ root }) => {
  const socket = path.join(root, "nvim.sock");
  const child = spawn("nvim", ["--headless", "-u", "NONE", "-i", "NONE", "-n", "--listen", socket], { stdio: "ignore" });
  try {
    for (let i = 0; !fs.existsSync(socket) && i < 100; i++) await new Promise((resolve) => setTimeout(resolve, 10));
    expect(fs.existsSync(socket)).toBe(true);
    command("nvim", ["--server", socket, "--remote-expr", 'execute("vsplit | wincmd h")']);
    const run = (binary, args) => binary === "hc" ? JSON.stringify(terminal({ foreground: { pid: child.pid, name: "nvim" } })) : command(binary, args);
    expect(navigateNeovim("t1", child.pid, "right", run).route).toBe("editor");
    expect(navigateNeovim("t1", child.pid, "right", run).route).toBe("pane");
    expect(() => navigateNeovim("t1", 999, "left", run)).toThrow("changed");
  } finally {
    child.kill("SIGTERM");
    await new Promise((resolve) => child.once("exit", resolve));
  }
}));

test("JJ create/list/archive keeps original safeguards through the App adapter (disposable repo)", () => fixture(({ root, env }) => {
  const repo = path.join(root, "repo");
  fs.mkdirSync(repo);
  command("git", ["init", repo]);
  command("git", ["-C", repo, "config", "user.email", "fixture@example.invalid"]);
  command("git", ["-C", repo, "config", "user.name", "Port test"]);
  command("git", ["-C", repo, "config", "commit.gpgsign", "false"]);
  command("git", ["-C", repo, "config", "core.hooksPath", "/dev/null"]);
  command("git", ["-C", repo, "config", "core.fsmonitor", "false"]);
  fs.writeFileSync(path.join(repo, "file.txt"), "fixture\n");
  command("git", ["-C", repo, "add", "file.txt"]);
  command("git", ["-C", repo, "commit", "-m", "fixture"]);
  command("jj", ["--config", 'signing.behavior="drop"', "git", "init", "--colocate"], { cwd: repo });
  const adapter = path.join(root, "fixture-adapter");
  fs.writeFileSync(adapter, `#!/usr/bin/env bun\nimport { bridge } from ${JSON.stringify(path.join(here, "bridge-lib.mjs"))};\ntry { const r=bridge(process.argv.slice(2), {run:(b,a)=>{if(b==='hc'&&a[0]==='ls')return JSON.stringify({terminals:[]}); if(b==='herdr-app'&&a[0]==='ls')return JSON.stringify({spaces:[]}); throw Error('Unexpected live operation '+b+' '+a.join(' ')); }}); console.log(r.raw ?? JSON.stringify(r)); } catch(e) {console.error(JSON.stringify({error:{code:e.code,message:e.message}}));process.exit(1);}\n`, { mode: 0o700 });
  const state = path.join(root, "jj-state");
  const jjConfig = path.join(root, "jj.toml");
  fs.writeFileSync(jjConfig, '[user]\nname="Port test"\nemail="fixture@example.invalid"\n[signing]\nbehavior="drop"\n');
  const scoped = { ...env, HERDR_BIN_PATH: adapter, GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: "/dev/null", JJ_CONFIG: jjConfig };
  const invoke = (argv) => JSON.parse(command("herdr-jj", [...argv, "--repo", repo, "--state-dir", state], { env: scoped, cwd: repo }));
  const created = invoke(["create", "port-test", "--vcs", "jj", "--base", "current", "--no-open"]);
  expect(created.ok).toBe(true);
  const checkout = created.result.workspace.path;
  expect(checkout.startsWith(root + path.sep)).toBe(true);
  expect(fs.existsSync(checkout)).toBe(true);
  expect(invoke(["list"]).result.workspaces.some((w) => w.name === "port-test")).toBe(true);
  const preview = invoke(["cleanup", "port-test"]);
  expect(preview.ok).toBe(true);
  expect(fs.existsSync(checkout)).toBe(true);
  const archived = invoke(["cleanup", "port-test", "--confirm", checkout]);
  expect(archived.ok).toBe(true);
  expect(fs.existsSync(archived.result.archive)).toBe(true);
  expect(fs.existsSync(path.join(archived.result.archive, "file.txt"))).toBe(true);
  expect(fs.existsSync(checkout)).toBe(false);
  expect(archived.result.bookmark.startsWith("herdr-jj-recovery/")).toBe(true);
}), 30000);
