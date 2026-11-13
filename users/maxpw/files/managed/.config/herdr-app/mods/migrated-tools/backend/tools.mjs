import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath, pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { BridgeError, agentName, command, coreTerminal, decode, locations, privateDirectory } from "./bridge-lib.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
export const bridgePath = path.join(here, "bridge");

export function annotateRoot(env = process.env) {
  const legacy = env.HERDR_LEGACY_HOME || path.join(os.homedir(), ".config/herdr");
  const registry = decode(fs.readFileSync(path.join(legacy, "plugins.json"), "utf8"), "Legacy plugin registry");
  const root = registry.find((p) => p.plugin_id === "annotate" && p.enabled)?.plugin_root;
  if (typeof root !== "string" || !path.isAbsolute(root) || !fs.existsSync(path.join(root, "src/editor.ts")) || !fs.existsSync(path.join(root, "bin/plannotator-tui"))) throw new BridgeError("dependency_missing", "The installed Annotate backend is missing; restore that plugin before using the port");
  return root;
}

function checkJournalTree(directory) {
  return JSON.stringify(fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).map((entry) => {
    if (entry.isSymbolicLink()) throw new BridgeError("unsafe_state", "A legacy JJ journal contains a symlink; inspect it before migration");
    if (entry.name === "lock" || entry.name.endsWith(".lock")) throw new BridgeError("busy", "A legacy JJ journal is locked; finish or inspect the original operation before migration");
    if (entry.isDirectory()) return [entry.name, checkJournalTree(path.join(directory, entry.name))];
    if (!entry.isFile()) throw new BridgeError("unsafe_state", "A legacy JJ journal contains a non-file entry");
    return [entry.name, createHash("sha256").update(fs.readFileSync(path.join(directory, entry.name))).digest("hex")];
  }));
}

export function setup(env = process.env) {
  const loc = locations(env);
  for (const directory of [loc.state, loc.requests, loc.annotations, loc.jj]) privateDirectory(directory);
  const state = path.join(loc.jj, "state");
  if (!fs.existsSync(state)) {
    const source = path.join(env.HERDR_LEGACY_HOME || path.join(os.homedir(), ".config/herdr"), "plugins/config/personal.herdr-jj/state");
    const temporary = path.join(loc.jj, `.import-${randomUUID()}`);
    privateDirectory(temporary);
    try {
      if (fs.existsSync(source)) {
        const before = checkJournalTree(source);
        fs.cpSync(source, temporary, { recursive: true, dereference: false });
        if (before !== checkJournalTree(source) || before !== checkJournalTree(temporary)) throw new BridgeError("state_conflict", "Legacy JJ journals changed during import; retry once the old operation has finished");
      }
      fs.renameSync(temporary, state);
    } catch (error) {
      fs.rmSync(temporary, { recursive: true, force: true });
      if (!["EEXIST", "ENOTEMPTY"].includes(error.code) || !fs.existsSync(state)) throw error;
    }
  }
  privateDirectory(state);
  return { ...loc, jjState: state, bridge: bridgePath, annotate: annotateRoot(env) };
}

export function socketCandidates(stdout) {
  return [...new Set(stdout.split("\n").filter((line) => line.startsWith("n/")).map((line) => line.slice(1).replace(/ type=STREAM.*$/, "")).filter((socket) => !socket.includes("->")))];
}

// Verify getpid() before using any discovered socket: an editor may also have
// client sockets connected to a different Neovim instance.
export function navigateNeovim(address, expectedPid, direction, run = command) {
  if (!["left", "down", "up", "right"].includes(direction)) throw new BridgeError("invalid_input", "Invalid navigation direction");
  const terminal = coreTerminal(address, run);
  if (String(terminal.foreground?.pid) !== String(expectedPid)) throw new BridgeError("target_changed", "Foreground process changed; press the navigation key again");
  const foreground = terminal.foreground;
  if (!/(^|\/)n?vim(?:diff)?$/.test(foreground?.name || "")) return { route: "pane" };
  if (!/(^|\/)nvim(?:diff)?$/.test(foreground.name)) return { route: "terminal" };
  let sockets;
  try { sockets = socketCandidates(run("lsof", ["-a", "-p", String(foreground.pid), "-U", "-Fn"])); }
  catch { return { route: "terminal", warning: "Unable to discover the Neovim RPC socket; keeping navigation inside the editor" }; }
  const movement = { left: "h", down: "j", up: "k", right: "l" }[direction];
  for (const socket of sockets) {
    let pid;
    try { pid = run("nvim", ["--server", socket, "--remote-expr", "getpid()"]).trim(); } catch { continue; }
    if (pid !== String(foreground.pid)) continue;
    const expression = `luaeval('(function() local before = vim.api.nvim_get_current_win(); vim.cmd("wincmd ${movement}"); return vim.api.nvim_get_current_win() ~= before and 1 or 0 end)()')`;
    const moved = run("nvim", ["--server", socket, "--remote-expr", expression]).trim();
    if (moved !== "0" && moved !== "1") throw new BridgeError("invalid_response", "Neovim returned an unexpected navigation result");
    return { route: moved === "1" ? "editor" : "pane" };
  }
  return { route: "terminal", warning: "No verified Neovim RPC socket; keeping navigation inside the editor" };
}

export async function annotationContext(env = process.env) {
  const loc = locations(env);
  const root = annotateRoot(env);
  const { loadAnnotations, newestFirstAnnotations } = await import(pathToFileURL(path.join(root, "src/store.ts")));
  const { formatAnnotations } = await import(pathToFileURL(path.join(root, "src/format.ts")));
  const loaded = loadAnnotations(loc.annotations);
  if (!loaded.ok) throw new BridgeError("invalid_state", loaded.message);
  const annotations = newestFirstAnnotations(loaded.value);
  return { text: annotations.length ? formatAnnotations(annotations) : "", count: annotations.length };
}

function reviewEnvironment(target, terminal) {
  return {
    ...process.env,
    HERDR_ENV: "1",
    HERDR_BIN_PATH: bridgePath,
    HERDR_PLUGIN_CONTEXT_JSON: "{}",
    HERDR_PANE_ID: "",
    PLANNOTATOR_TUI_DELIVER_TO: terminal?.reported && terminal.status?.app ? target.terminal : "",
    PLANNOTATOR_TUI_DELIVER_AGENT: terminal ? agentName(terminal) || "" : "",
    MIGRATED_TARGET_ADDRESS: target.terminal,
    MIGRATED_TARGET_PID: String(terminal?.foreground?.pid || ""),
    MIGRATED_TARGET_APP: terminal?.status?.app || "",
    PLANNOTATOR_TUI_CWD: target.machine ? locations().home : target.cwd || "",
  };
}

export function exactTranscript(terminal, run = command) {
  const args = terminal.foreground?.argv || [];
  for (let i = 0; i < args.length - 1; i++) {
    if (args[i] === "--session" && path.isAbsolute(args[i + 1]) && /\.jsonl$/.test(args[i + 1]) && fs.existsSync(args[i + 1])) return args[i + 1];
  }
  let output;
  try { output = run("lsof", ["-a", "-p", String(terminal.foreground.pid), "-Fn"]); } catch { return null; }
  const files = [...new Set(output.split("\n").filter((line) => line.startsWith("n/") && /\.jsonl$/.test(line)).map((line) => line.slice(1)))];
  const host = agentName(terminal);
  const matching = files.filter((file) => {
    if (host === "claude") return file.includes("/.claude/projects/");
    if (host === "pi") return file.includes("/.pi/") && file.includes("/sessions/");
    if (host === "codex") return file.includes("/sessions/") && path.basename(file).startsWith("rollout-");
    if (host === "copilot") return file.endsWith("/events.jsonl") && file.includes("/session-state/");
    if (host === "droid") return file.includes("/.factory/sessions/");
    return false;
  });
  if (matching.length !== 1) return null;
  return host === "copilot" ? path.dirname(matching[0]) : matching[0];
}

export function cleanupTool(address, env = process.env) {
  if (!/^t[a-z0-9]+$/.test(address)) throw new BridgeError("invalid_input", "Snapshot cleanup requires a local tool terminal address");
  const directory = path.join(locations(env).requests, `snapshot-${address}`);
  if (!fs.existsSync(directory)) return;
  const stat = fs.lstatSync(directory);
  if (!stat.isDirectory() || stat.isSymbolicLink() || stat.uid !== process.getuid()) throw new BridgeError("unsafe_state", "Refusing to clean an unowned or linked snapshot directory");
  fs.rmSync(directory, { recursive: true });
}

export function review(mode, target) {
  const root = annotateRoot();
  const tui = path.join(root, "bin/plannotator-tui");
  const terminal = target.terminal ? coreTerminal(target.terminal) : null;
  if (terminal?.reported && terminal.status?.app && !terminal.foreground?.pid) throw new BridgeError("agent_not_ready", "Core agent process facts are still loading; reopen the review once the agent is ready");
  const env = reviewEnvironment(target, terminal);
  let args;
  let temporary;
  let toolAddress;
  if (mode === "documents") {
    if (target.machine) throw new BridgeError("remote_backend_missing", "Remote document review needs the Annotate backend on that machine; no files were copied or remote setup changed");
    if (!target.cwd || !path.isAbsolute(target.cwd) || !fs.statSync(target.cwd).isDirectory()) throw new BridgeError("invalid_input", "The original pane's folder is unavailable");
    args = [target.cwd];
  } else {
    if (!terminal?.reported || !terminal.status?.app || !terminal.foreground?.pid) throw new BridgeError("agent_not_found", "Focus a live agent before reviewing its last reply");
    const host = agentName(terminal);
    const transcript = !target.machine ? exactTranscript(terminal) : null;
    if (transcript) args = ["last", "--host", host, "--pid", String(terminal.foreground.pid), "--session", transcript];
    else {
      const snapshot = decode(command("hc", ["read", target.terminal, "--lines", "20000", "--json"]), "hc read");
      if (typeof snapshot.text !== "string" || !snapshot.text.trim()) throw new BridgeError("unavailable", "The original agent has no readable terminal output");
      toolAddress = process.env.HC_TERMINAL_ID;
      if (!/^t[a-z0-9]+$/.test(toolAddress || "")) throw new BridgeError("invalid_input", "Snapshot reviews must run in their own local core tool terminal");
      const requests = privateDirectory(locations().requests);
      temporary = path.join(requests, `snapshot-${toolAddress}`);
      fs.mkdirSync(temporary, { mode: 0o700 });
      const file = path.join(temporary, "focused-terminal-output.md");
      fs.writeFileSync(file, `# Focused terminal output — ${target.terminal}\n\nNo unambiguous transcript was exposed by this agent process. This is a terminal snapshot, not a structured last reply.${snapshot.complete ? "" : " The core reports that part of the output may be missing."}\n\n${snapshot.text}`, { flag: "wx", mode: 0o600 });
      args = [file];
    }
  }
  try {
    const result = spawnSync(tui, args, { env, cwd: mode === "documents" ? target.cwd : locations().home, stdio: "inherit" });
    if (result.error || result.status !== 0) throw new BridgeError("review_failed", result.error?.message || "The document review did not finish successfully");
  } finally { if (temporary) cleanupTool(toolAddress); }
}

async function main() {
  const [action, ...args] = process.argv.slice(2);
  if (action === "setup") return setup();
  if (action === "navigation") {
    const on = args[3];
    const run = on ? (binary, argv) => binary === "hc" ? command(binary, argv) : command("hc", ["exec", "--on", on, "--", binary, ...argv]) : command;
    return navigateNeovim(args[0], args[1], args[2], run);
  }
  if (action === "annotation-context") return annotationContext();
  if (action === "cleanup-tool") { cleanupTool(args[0]); return undefined; }
  if (action === "review") { review(args[0], decode(args[1], "Review target")); return undefined; }
  throw new BridgeError("invalid_input", "Unknown migrated-tools backend action");
}

if (import.meta.main) {
  try { const result = await main(); if (result !== undefined) console.log(JSON.stringify(result)); }
  catch (error) {
    if (process.argv[2] === "review" && process.stdin.isTTY) {
      console.error(`Review unavailable: ${error.message}\nPress Enter to close.`);
      try { fs.readSync(0, Buffer.alloc(1), 0, 1); } catch {}
    } else console.error(JSON.stringify({ error: { code: error.code || "tools_failed", message: error.message } }));
    process.exitCode = 1;
  }
}
