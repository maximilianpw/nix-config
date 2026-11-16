import type { PluginAPI } from "@ampcode/plugin";

export const description = "Shows the local Jujutsu change or Git branch and changed-file count in Amp's status area.";

async function run(command: string, args: string[], cwd: string): Promise<string> {
  const child = Bun.spawn([command, ...args], { cwd, stdout: "pipe", stderr: "pipe" });
  const timeout = setTimeout(() => child.kill(), 2_000);
  const [stdout, code] = await Promise.all([
    new Response(child.stdout).text(),
    child.exited,
  ]).finally(() => clearTimeout(timeout));
  if (code !== 0) throw new Error(`${command} exited ${code}`);
  return stdout.trimEnd();
}

async function summary(cwd: string): Promise<string> {
  try {
    await run("jj", ["root"], cwd);
    const [id, description, status] = await Promise.all([
      run("jj", ["log", "-r", "@", "--no-graph", "-T", "change_id.shortest()"], cwd),
      run("jj", ["log", "-r", "@", "--no-graph", "-T", "description.first_line()"], cwd),
      run("jj", ["st"], cwd),
    ]);
    const count = status.split("\n").filter((line) => /^[AMDRC?][ MDRC?]?\s+/.test(line.trim())).length;
    return `󱗆 ${id.trim()} · ${description.trim() || "no description"} · ${count} changed ${count === 1 ? "file" : "files"}`;
  } catch {
    // Fall through to Git.
  }

  try {
    await run("git", ["rev-parse", "--show-toplevel"], cwd);
    const [branch, head, status] = await Promise.all([
      run("git", ["branch", "--show-current"], cwd),
      run("git", ["rev-parse", "--short", "HEAD"], cwd),
      run("git", ["status", "--porcelain=v1"], cwd),
    ]);
    const count = status.split("\n").filter((line) => line.trim()).length;
    return ` ${branch.trim() || `detached ${head.trim()}`} · ${count} changed ${count === 1 ? "file" : "files"}`;
  } catch {
    return "";
  }
}

export default function vcsStatus(amp: PluginAPI) {
  const cwd = amp.system.workspaceRoot ? amp.helpers.filePathFromURI(amp.system.workspaceRoot) : process.cwd();
  const status = amp.experimental?.createStatusItem();
  if (!status) {
    amp.logger.log("VCS status is unavailable because this Amp client does not support status items.");
    return;
  }
  const statusItem = status;
  let generation = 0;

  async function refresh() {
    const current = ++generation;
    const text = await summary(cwd);
    if (current === generation) statusItem.update({ text });
  }

  amp.on("session.start", refresh);
  amp.on("tool.result", async (event) => {
    const shell = amp.helpers.shellCommandFromToolCall(event);
    if (shell || amp.helpers.filesModifiedByToolCall(event)?.length) await refresh();
    return undefined;
  });
  amp.on("agent.end", async () => {
    await refresh();
  });

  const interval = setInterval(() => void refresh(), 2_000);
  void refresh();
  amp.onDispose(() => clearInterval(interval));
}
