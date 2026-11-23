import { homedir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { Commands, errorEnvelope, WorkspaceError } from "./command";
import { runPopup } from "./popup";
import { Repository } from "./repository";
import { Rex, targetDirectory } from "./rex";
import { WorkspaceCatalog } from "./workspace-catalog";

const help = `workspaces — JJ and Git workspaces in one picker, opened as Rex sessions

  create NAME [--vcs jj|git] [--base BASE] [--no-open]
  list [--vcs jj|git]
  open NAME_OR_PATH [--vcs jj|git]
  status [--snapshot]
  cleanup NAME                         Preview; does not snapshot or move
  cleanup NAME --confirm /exact/path    Snapshot, pin recovery, ARCHIVE (no deletion)
  pick create|open|cleanup             Interactive picker for a terminal

Common: --repo /absolute/path (default: cwd) --state-dir /absolute/path
  (default: $XDG_STATE_HOME/workspaces, else ~/.local/state/workspaces)
All noninteractive results/errors are JSON; failures exit 1. Help exits 0.
Creation defaults to JJ when available, otherwise Git.
JJ bases: trunk (default), current (NEW child of the snapshotted @ change).
Git bases: current (default, Git HEAD) or an explicit local commit/ref. Creates a new
branch named NAME; source edits stay untouched. Existing branches are never reset.
Opening never converts repositories. Cleanup/status remain JJ-only.
Use --vcs or an exact listed path when a name is ambiguous.
Opening shows the checkout's Rex session (the project_open action).
Closing a session never cleans up its checkout. Cleanup never closes terminals.
`;

function pickAction(input: string | undefined): "create" | "open" | "cleanup" {
  if (input === "create" || input === "open" || input === "cleanup")
    return input;
  throw new WorkspaceError(
    "invalid_input",
    "Unknown picker. Use create, open or cleanup.",
  );
}

async function main(): Promise<unknown> {
  let args: ReturnType<typeof readArgs>;
  try {
    args = readArgs();
  } catch (cause) {
    throw new WorkspaceError(
      "invalid_input",
      "Invalid command arguments. Run `workspaces --help` for supported commands and flags.",
      { cause },
    );
  }
  const { values, positionals } = args;
  const [command, name] = positionals;
  if (values.help || !command) {
    process.stdout.write(help);
    return undefined;
  }
  if (
    !["create", "list", "open", "status", "cleanup", "pick"].includes(command)
  ) {
    throw new WorkspaceError(
      "invalid_input",
      "Unknown command. Run `workspaces --help` for supported commands.",
    );
  }
  const takesName = ["create", "open", "cleanup", "pick"].includes(command);
  if (positionals.length !== (takesName ? 2 : 1)) {
    throw new WorkspaceError(
      "invalid_input",
      "Command has missing or extra arguments. Run `workspaces --help` for its syntax.",
    );
  }
  if (
    (values.confirm && command !== "cleanup") ||
    (values.snapshot && command !== "status") ||
    (values.base && command !== "create") ||
    (values.vcs && !["create", "list", "open"].includes(command)) ||
    (values["no-open"] && command !== "create")
  ) {
    throw new WorkspaceError(
      "invalid_input",
      "Flag does not apply to this command. Check `workspaces --help`; no operation was started.",
    );
  }
  const kind = values.vcs;
  if (kind !== undefined && kind !== "jj" && kind !== "git") {
    throw new WorkspaceError("invalid_input", "Invalid VCS. Choose jj or git.");
  }
  const env = process.env;
  const commands = new Commands(env);
  const rex = new Rex(commands, process.cwd());
  const path = targetDirectory(values.repo, process.cwd());
  if (command === "status") {
    const repository = Repository.load(path, commands);
    if (values.snapshot) repository.snapshot();
    return {
      ...repository.status(),
      source: values.snapshot ? "snapshot-now" : "last-snapshot",
    };
  }
  const workspaces = WorkspaceCatalog.load(
    path,
    commands,
    rex,
    () =>
      values["state-dir"] ??
      join(
        env.XDG_STATE_HOME || join(homedir(), ".local", "state"),
        "workspaces",
      ),
  );
  if (command === "list") {
    return {
      workspaces: workspaces
        .list()
        .filter((entry) => !kind || entry.kind === kind),
    };
  }
  if (command === "pick") {
    try {
      await runPopup(pickAction(name), workspaces);
    } finally {
      // Bun can retain the keypress input handle after pause(); release
      // stdin so the process exits and Rex closes the popup.
      process.stdin.destroy();
    }
    return undefined;
  }
  if (!name)
    throw new WorkspaceError(
      "invalid_input",
      "Workspace name is required. Run `workspaces --help` for syntax.",
    );
  if (command === "create") {
    const workspace = workspaces.create(name, kind, values.base);
    const opened = values["no-open"]
      ? undefined
      : workspaces.open(name, workspace.kind);
    return { workspace, opened };
  }
  if (command === "open") return workspaces.open(name, kind);
  if (command === "cleanup")
    return values.confirm
      ? workspaces.cleanup(name, values.confirm)
      : workspaces.planCleanup(name);
  throw new WorkspaceError(
    "invalid_input",
    "Command could not be dispatched. Check `workspaces --help`.",
  );
}

function readArgs() {
  return parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    strict: true,
    options: {
      help: { type: "boolean", short: "h" },
      repo: { type: "string" },
      "state-dir": { type: "string" },
      base: { type: "string" },
      vcs: { type: "string" },
      "no-open": { type: "boolean" },
      snapshot: { type: "boolean" },
      confirm: { type: "string" },
    },
  });
}

try {
  const result = await main();
  if (result !== undefined) console.log(JSON.stringify({ ok: true, result }));
} catch (cause) {
  console.error(JSON.stringify(errorEnvelope(cause)));
  process.exitCode = 1;
}
