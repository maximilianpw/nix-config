import { test, expect } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const tui = path.join(os.homedir(), ".config/herdr/plugins/github/annotate-9c299759567c/bin/plannotator-tui");

// Never attach this fixture core to the person's App. Its XDG paths, session,
// programs and input are all disposable and receive no herdr.space labels.
test("real hc isolation: private snapshot TUI, feedback transport, and target identity", async () => {
  const root = fs.realpathSync(fs.mkdtempSync("/tmp/hp-"));
  const env = { ...process.env, HC_SESSION: `port-${randomUUID().slice(0, 12)}`, XDG_CONFIG_HOME: path.join(root, "config"), XDG_STATE_HOME: path.join(root, "state"), XDG_RUNTIME_DIR: path.join(root, "runtime"), HERDR_APP_HOME: path.join(root, "app") };
  delete env.HC_TERMINAL_ID;
  for (const directory of [env.XDG_CONFIG_HOME, env.XDG_STATE_HOME, env.XDG_RUNTIME_DIR, env.HERDR_APP_HOME]) fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  const owned = [];
  let started = false;
  const call = (args, { allowTimeout = false, extraEnv = {} } = {}) => {
    const result = spawnSync("hc", args, { env: { ...env, ...extraEnv }, cwd: root, encoding: "utf8", timeout: 15000 });
    if (result.error || (result.status !== 0 && !(allowTimeout && result.status === 124))) throw new Error(result.error?.message || result.stderr || `hc ${args[0]} failed (${result.status})`);
    return result.stdout;
  };
  const waitForForeground = async (address) => {
    const stream = Bun.spawn(["hc", "events", "--terminal", address, "--json"], { env, cwd: root, stdout: "pipe", stderr: "ignore" });
    const deadline = setTimeout(() => stream.kill(), 5000);
    let buffer = "";
    try {
      const decoder = new TextDecoder();
      for await (const chunk of stream.stdout) {
        buffer += decoder.decode(chunk, { stream: true });
        let newline;
        while ((newline = buffer.indexOf("\n")) >= 0) {
          const raw = JSON.parse(buffer.slice(0, newline));
          buffer = buffer.slice(newline + 1);
          const event = raw.params || raw;
          if ((event.type === "foreground" && event.terminal === address && event.data?.pid) || (event.terminals || raw.result?.terminals || []).some((t) => t.address === address && t.foreground?.pid)) return;
        }
      }
      throw new Error("Foreground facts did not arrive from the isolated core event stream");
    } finally { clearTimeout(deadline); stream.kill(); await stream.exited; }
  };
  const launch = (argv) => {
    const result = JSON.parse(call(["run", "--bg", "--json", "--no-parent", "--outlive-parent", "--no-notify", "--cwd", root, "--", ...argv]));
    started = true;
    expect(typeof result.address).toBe("string");
    owned.push(result.address);
    return result.address;
  };
  try {
    const document = path.join(root, "snapshot.md");
    fs.writeFileSync(document, "# Snapshot smoke test\n\nFixture terminal content.\n", { mode: 0o600 });
    const viewer = launch([tui, document]);
    call(["wait", viewer, "--output", "Snapshot smoke test", "--timeout", "3"], { allowTimeout: true });
    const snapshot = JSON.parse(call(["read", viewer, "--json"]));
    expect(snapshot.text).toContain("Snapshot smoke test");
    expect(snapshot.text).toContain("Fixture terminal content");
    call(["keys", viewer, "q"]);
    call(["wait", viewer, "--timeout", "3"]);

    const program = 'import sys\ndef report(state):\n sys.stdout.write(chr(27)+"]7501;state="+state+":app=port-fixture"+chr(27)+chr(92));sys.stdout.flush()\nreport("idle")\nfor line in sys.stdin:\n print("Received fixture feedback: "+line.strip(),flush=True)\n report("working")\n';
    const agent = launch(["python3", "-u", "-c", program]);
    call(["wait", agent, "--timeout", "3"]);
    await waitForForeground(agent);
    const original = JSON.parse(call(["get", agent, "--json"]));
    expect(original.reported).toBe(true);
    expect(original.status.app).toBe("port-fixture");
    const reviewEnv = { ...env, MIGRATED_TARGET_ADDRESS: agent, MIGRATED_TARGET_PID: String(original.foreground.pid), MIGRATED_TARGET_APP: "port-fixture" };
    const delivered = spawnSync(path.join(here, "bridge"), ["agent", "prompt", agent, "- Only disposable fixture feedback"], { env: reviewEnv, encoding: "utf8", timeout: 15000 });
    expect(delivered.status).toBe(0);
    expect(JSON.parse(delivered.stdout).result.started).toBe(true);
    const output = JSON.parse(call(["read", agent, "--json"]));
    expect(output.text).toContain("Received fixture feedback: - Only disposable fixture feedback");
    const refused = spawnSync(path.join(here, "bridge"), ["agent", "prompt", agent, "Must not send"], { env: { ...reviewEnv, MIGRATED_TARGET_PID: "0" }, encoding: "utf8", timeout: 10000 });
    expect(refused.status).toBe(1);
    expect(JSON.parse(refused.stderr).error.code).toBe("agent_not_ready");

    const review = launch(["bun", path.join(here, "tools.mjs"), "review", "last", JSON.stringify({ terminal: agent, cwd: root, machine: null })]);
    call(["wait", review, "--output", "Focused terminal output", "--timeout", "3"], { allowTimeout: true });
    const reviewScreen = JSON.parse(call(["read", review, "--json"]));
    expect(reviewScreen.text).toContain("Focused terminal output");
    const privateSnapshot = path.join(env.HERDR_APP_HOME, "data/migrated/requests", `snapshot-${review}`, "focused-terminal-output.md");
    expect(fs.statSync(privateSnapshot).mode & 0o777).toBe(0o600);
    expect(fs.readFileSync(privateSnapshot, "utf8")).toContain("not a structured last reply");
    call(["keys", review, "q"]);
    call(["wait", review, "--timeout", "3"]);
    expect(fs.existsSync(path.dirname(privateSnapshot))).toBe(false);
  } finally {
    for (const address of owned) {
      try { call(["kill", address]); } catch {}
      try { call(["rm", address]); } catch {}
    }
    if (started) {
      // This exact HC_SESSION/XDG environment created the core above.
      call(["server", "stop"]);
    }
    fs.rmSync(root, { recursive: true, force: true });
  }
}, 45000);
