import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";

export class BridgeError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

export function command(binary, args, options = {}) {
  const result = spawnSync(binary, args, { encoding: "utf8", timeout: 25000, maxBuffer: 8 * 1024 * 1024, ...options });
  if (result.error || result.status !== 0) {
    let detail;
    try { detail = JSON.parse(result.stderr).error; } catch {}
    throw new BridgeError(detail?.kind === "blocked" ? "agent_blocked" : "command_failed", detail?.message || result.error?.message || result.stderr?.trim() || `${binary} failed`);
  }
  return result.stdout;
}

export function decode(text, label) {
  try { return JSON.parse(text); } catch { throw new BridgeError("invalid_response", `${label} returned invalid JSON`); }
}

export function privateDirectory(directory) {
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  const stat = fs.lstatSync(directory);
  if (!stat.isDirectory() || stat.isSymbolicLink() || stat.uid !== process.getuid()) throw new BridgeError("unsafe_state", "Migration state must be an owned directory, not a symlink");
  fs.chmodSync(directory, 0o700);
  return directory;
}

export function locations(env = process.env) {
  const home = env.HERDR_APP_HOME || path.join(os.homedir(), ".config/herdr-app");
  if (!path.isAbsolute(home)) throw new BridgeError("invalid_input", "HERDR_APP_HOME must be absolute");
  const state = path.join(home, "data/migrated");
  return { home, state, requests: path.join(state, "requests"), annotations: path.join(state, "annotations"), jj: path.join(state, "jj"), bindings: path.join(state, "bindings.json"), metadata: path.join(state, "vcs-status.json") };
}

export function atomicJson(file, value) {
  privateDirectory(path.dirname(file));
  const temporary = `${file}.${randomUUID()}.tmp`;
  try { fs.writeFileSync(temporary, JSON.stringify(value), { flag: "wx", mode: 0o600 }); fs.renameSync(temporary, file); }
  finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
}

export function readJson(file, fallback) {
  try {
    const stat = fs.lstatSync(file);
    if (!stat.isFile() || stat.isSymbolicLink()) throw new BridgeError("unsafe_state", "Migration state is not a regular file");
    return decode(fs.readFileSync(file, "utf8"), "Migration state");
  } catch (error) { if (error.code === "ENOENT") return fallback; throw error; }
}

function withLock(file, body) {
  const lock = `${file}.lock`;
  privateDirectory(path.dirname(file));
  try { fs.mkdirSync(lock, { mode: 0o700 }); }
  catch (error) { if (error.code === "EEXIST") throw new BridgeError("busy", "Migration metadata is busy; retry once the other operation finishes. A crashed operation's lock requires manual inspection."); throw error; }
  try { return body(); } finally { fs.rmdirSync(lock); }
}

export function coreTerminal(address, run = command) {
  const terminal = decode(run("hc", ["get", address, "--json"]), "hc get");
  if (!terminal || terminal.address !== address || terminal.state !== "live") throw new BridgeError("agent_not_found", "The original terminal is no longer live");
  return terminal;
}

export function agentName(terminal) {
  const app = terminal.status?.app || "";
  if (/claude/i.test(app)) return "claude";
  if (/codex/i.test(app)) return "codex";
  if (/copilot/i.test(app)) return "copilot";
  if (/droid/i.test(app)) return "droid";
  if (/^pi$/i.test(app)) return "pi";
  return app || null;
}

function pinnedTerminal(address, env, run) {
  if (!env.MIGRATED_TARGET_ADDRESS || address !== env.MIGRATED_TARGET_ADDRESS) throw new BridgeError("pane_not_found", "Review target was not explicitly pinned");
  const terminal = coreTerminal(address, run);
  const pid = terminal.foreground?.pid;
  if (!terminal.reported || !terminal.status?.app || String(pid) !== env.MIGRATED_TARGET_PID || terminal.status.app !== env.MIGRATED_TARGET_APP) throw new BridgeError("agent_not_ready", "The agent changed or restarted since this review opened; reopen the review");
  return terminal;
}

function appInventory(run) {
  const app = decode(run("herdr-app", ["ls"]), "herdr-app ls");
  if (!Array.isArray(app.spaces)) throw new BridgeError("invalid_response", "App inventory is incomplete; refusing the operation");
  return app;
}

function appAndTerminals(run) {
  const app = appInventory(run);
  const core = decode(run("hc", ["ls", "--json"]), "hc ls");
  if (!Array.isArray(core.terminals) || core.terminals.some((t) => typeof t.address !== "string")) throw new BridgeError("invalid_response", "Core inventory is incomplete; refusing cleanup");
  // `hc ls --json` is a display summary, not the OpenRPC Terminal schema.
  // Get each full record so cwd/foreground and hidden programs stay in the guard.
  const local = core.terminals.filter((t) => !t.address.includes("/") && t.state === "live").map((t) => coreTerminal(t.address, run));
  if (local.some((t) => typeof t.cwd !== "string" || !path.isAbsolute(t.cwd) || (t.foreground && (typeof t.foreground.cwd !== "string" || !path.isAbsolute(t.foreground.cwd))))) throw new BridgeError("unsafe_cleanup", "A live local terminal has an unknown directory; refusing cleanup");
  return { app, local };
}

function flags(args, allowed) {
  const result = {};
  for (let i = 0; i < args.length; i++) {
    const key = args[i];
    if (!allowed.includes(key) || key in result) throw new BridgeError("unsupported", `Unsupported bridge flag: ${key}`);
    if (key === "--focus" || key === "--no-focus") result[key] = true;
    else {
      const value = args[++i];
      if (value === undefined) throw new BridgeError("invalid_input", `Missing bridge flag value: ${key}`);
      result[key] = value;
    }
  }
  return result;
}

// This intentionally implements only the plugin calls we ported. There is no
// fallback to the old `herdr` binary, even when an upstream plugin changes.
export function bridge(args, { env = process.env, run = command } = {}) {
  const loc = locations(env);
  const [group, action] = args;
  if (group === "plugin" && action === "config-dir" && args[2] === "personal.herdr-jj" && args.length === 3) return { raw: privateDirectory(loc.jj) };
  if (group === "pane" && action === "list" && args.length === 2) {
    const { app, local } = appAndTerminals(run);
    const byAddress = new Map(app.spaces.filter((s) => !s.machine).flatMap((s) => s.tabs.flatMap((tab) => tab.terminals.map((t) => [t.terminal, { pane: t.pane, space: s.id }]))));
    return { result: { panes: local.map((t) => ({ pane_id: byAddress.get(t.address)?.pane || t.address, workspace_id: byAddress.get(t.address)?.space || "unshown", cwd: t.cwd, foreground_cwd: t.foreground?.cwd ?? null, agent: agentName(t), focused: false })) } };
  }
  if (group === "workspace" && action === "list" && args.length === 2) {
    const app = appInventory(run);
    const bindings = readJson(loc.bindings, {});
    return { result: { workspaces: app.spaces.filter((s) => !s.machine).map((s) => {
      const checkout = Object.hasOwn(bindings, s.id) ? bindings[s.id] : s.folder === "" ? os.homedir() : s.folder;
      if (typeof checkout !== "string" || !path.isAbsolute(checkout)) throw new BridgeError("unsafe_cleanup", "An App space has an unknown bound directory; refusing cleanup");
      return { workspace_id: s.id, worktree: { checkout_path: checkout } };
    }) } };
  }
  if (group === "worktree" && action === "open") {
    const options = flags(args.slice(2), ["--cwd", "--path", "--label", "--focus", "--no-focus"]);
    if (!options["--path"] || !path.isAbsolute(options["--path"]) || !fs.statSync(options["--path"]).isDirectory()) throw new BridgeError("invalid_input", "Checkout must be an existing absolute directory");
    const checkout = fs.realpathSync(options["--path"]);
    return withLock(loc.bindings, () => {
      const app = appInventory(run);
      const bindings = readJson(loc.bindings, {});
      const existing = app.spaces.find((s) => !s.machine && (bindings[s.id] === checkout || s.folder === checkout));
      let id = existing?.id;
      if (id) {
        if (options["--focus"]) run("herdr-app", ["do", "space.select", "--id", id]);
      } else {
        if (!options["--focus"]) throw new BridgeError("unsupported", "New App spaces are shown immediately; this adapter requires --focus");
        const created = decode(run("herdr-app", ["do", "space.new", "--folder", checkout, "--name", options["--label"] || path.basename(checkout), "--argv", JSON.stringify(["fish", "--login"])]), "space.new");
        id = created.space;
        if (typeof id !== "string") throw new BridgeError("partial_operation", "Checkout is intact, but the App did not return a space id. Inspect spaces before retrying Open.");
      }
      bindings[id] = checkout;
      atomicJson(loc.bindings, bindings);
      return { result: { workspace_id: id, checkout_path: checkout } };
    });
  }
  if (group === "workspace" && action === "report-metadata") {
    const id = args[2];
    const tokens = {};
    let seq;
    for (let i = 3; i < args.length; i += 2) {
      const [flag, value] = args.slice(i, i + 2);
      if (value === undefined || !["--source", "--seq", "--ttl-ms", "--token", "--clear-token"].includes(flag)) throw new BridgeError("unsupported", "Unsupported metadata request");
      if (flag === "--seq") seq = Number(value);
      if (flag === "--token") {
        const equals = value.indexOf("=");
        if (equals < 0) throw new BridgeError("invalid_input", "Invalid metadata token");
        tokens[value.slice(0, equals)] = value.slice(equals + 1);
      }
      if (flag === "--clear-token") tokens[value] = "";
    }
    if (!id || !Number.isFinite(seq)) throw new BridgeError("invalid_input", "Invalid metadata identity/sequence");
    return withLock(loc.metadata, () => {
      const statuses = Object.fromEntries(Object.entries(readJson(loc.metadata, {})).filter(([, value]) => value?.expires > Date.now()));
      if ((statuses[id]?.seq ?? 0) <= seq) { statuses[id] = { seq, expires: Date.now() + 300000, tokens }; atomicJson(loc.metadata, statuses); }
      return { result: {} };
    });
  }
  if (group === "pane" && action === "get" && args.length === 3) {
    const t = pinnedTerminal(args[2], env, run);
    return { result: { pane: { agent: agentName(t), pane_id: args[2] } } };
  }
  if (group === "pane" && action === "process-info" && args.length === 4 && args[2] === "--pane") {
    const t = pinnedTerminal(args[3], env, run);
    return { result: { process_info: { foreground_process_group_id: t.foreground.pid, foreground_processes: [{ pid: t.foreground.pid, name: agentName(t) || t.foreground.name }] } } };
  }
  if (group === "agent" && action === "read" && args.length === 7 && args[3] === "--source" && args[4] === "recent-unwrapped" && args[5] === "--format" && args[6] === "text") {
    pinnedTerminal(args[2], env, run);
    const read = decode(run("hc", ["read", args[2], "--lines", "20000", "--json"]), "hc read");
    if (typeof read.text !== "string") throw new BridgeError("invalid_response", "Core returned no terminal text");
    return { raw: read.text };
  }
  if (group === "agent" && action === "prompt" && args.length === 4) {
    const t = pinnedTerminal(args[2], env, run);
    if (t.status.state === "blocked") throw new BridgeError("agent_blocked", "The original agent is at a dialog; feedback was not sent");
    if (!args[3].trim()) throw new BridgeError("empty_agent_prompt", "Feedback is empty");
    const sent = decode(run("hc", ["send", "--json", args[2], "--", args[3]]), "hc send");
    if (sent.started === false) throw new BridgeError("delivery_uncertain", "Core submitted the feedback, but did not observe agent activity. Inspect the original agent before retrying; automatic resubmission could duplicate it.");
    return { result: sent };
  }
  throw new BridgeError("unsupported", `Unsupported legacy plugin call: ${group || ""} ${action || ""}`);
}
