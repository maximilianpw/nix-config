import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { PluginAPI } from "@ampcode/plugin";

export const description = "Uses the local Executor CLI to discover and call configured integrations.";

type Action = "search" | "describe" | "integrations" | "call" | "resume";
type Input = {
  action: Action;
  query?: string;
  path?: string;
  args?: Record<string, unknown>;
  namespace?: string;
  limit?: number;
  executionId?: string;
  decision?: "accept" | "decline" | "cancel";
  content?: Record<string, unknown>;
};

function required(value: string | undefined, field: string, action: Action): string {
  const normalized = value?.trim();
  if (!normalized) throw new Error(`Executor ${action} requires \`${field}\``);
  return normalized;
}

function commandArgs(input: Input): string[] {
  switch (input.action) {
    case "search": {
      const args = ["tools", "search", required(input.query, "query", input.action)];
      if (input.namespace?.trim()) args.push("--namespace", input.namespace.trim());
      args.push("--limit", String(input.limit ?? 10));
      return args;
    }
    case "describe":
      return ["tools", "describe", required(input.path, "path", input.action)];
    case "integrations": {
      const args = ["tools", "integrations"];
      if (input.query?.trim()) args.push("--query", input.query.trim());
      args.push("--limit", String(input.limit ?? 20));
      return args;
    }
    case "call": {
      const segments = required(input.path, "path", input.action).split(".");
      if (segments.some((segment) => segment.length === 0)) throw new Error("Executor call requires a dot-separated path without empty segments");
      return ["call", ...segments, JSON.stringify(input.args ?? {})];
    }
    case "resume": {
      const executionId = required(input.executionId, "executionId", input.action);
      if (!input.decision) throw new Error("Executor resume requires `decision`");
      const args = ["--log-level", "debug", "resume", "--execution-id", executionId, "--action", input.decision];
      if (input.decision === "accept") args.push("--content", JSON.stringify(input.content ?? {}));
      return args;
    }
  }
}

function failure(stdout: string, stderr: string, code: number): string {
  const message = [stderr.trim(), stdout.trim()].filter(Boolean).join("\n");
  if (message.includes('"_tag":"ApprovalExpiredError"')) {
    const id = message.match(/"executionId":"([^"]+)"/)?.[1];
    return `Executor could not resume execution${id ? ` ${id}` : ""}. The approval expired; trigger the original action again.`;
  }
  return message.slice(0, 8_000) || `executor exited with code ${code}`;
}

async function run(args: string[], cwd: string) {
  const process = Bun.spawn(["executor", ...args], { cwd, stdout: "pipe", stderr: "pipe" });
  const timeout = setTimeout(() => process.kill(), 60_000);
  const [stdout, stderr, code] = await Promise.all([
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
    process.exited,
  ]).finally(() => clearTimeout(timeout));
  if (code !== 0) throw new Error(failure(stdout, stderr, code));
  return stderr.trim() ? `${stdout.trimEnd()}\n\n[stderr]\n${stderr.trimEnd()}` : stdout;
}

export default function executor(amp: PluginAPI) {
  const tempDirectories = new Set<string>();
  const cwd = amp.system.workspaceRoot ? amp.helpers.filePathFromURI(amp.system.workspaceRoot) : process.cwd();

  amp.registerTool({
    name: "executor",
    title: "Executor",
    description: "Discover and call tools from the configured Executor gateway. Search before calling unfamiliar capabilities. A paused execution must not be accepted without user approval.",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["search", "describe", "integrations", "call", "resume"] },
        query: { type: "string" },
        path: { type: "string", description: "Fully qualified Executor tool path" },
        args: { type: "object", additionalProperties: true },
        namespace: { type: "string" },
        limit: { type: "integer", minimum: 1, maximum: 50 },
        executionId: { type: "string" },
        decision: { type: "string", enum: ["accept", "decline", "cancel"] },
        content: { type: "object", additionalProperties: true },
      },
      required: ["action"],
    },
    async execute(raw) {
      const output = (await run(commandArgs(raw as Input), cwd)).trimEnd() || "(no output)";
      const lines = output.split("\n");
      if (Buffer.byteLength(output) <= 50 * 1024 && lines.length <= 2_000) return output;

      const directory = await mkdtemp(join(tmpdir(), "amp-executor-"));
      const file = join(directory, "output.txt");
      tempDirectories.add(directory);
      await writeFile(file, output, { encoding: "utf8", mode: 0o600 });
      return `${lines.slice(0, 2_000).join("\n").slice(0, 50 * 1024)}\n\n[Output truncated. Full output saved to ${file}]`;
    },
  });

  amp.onDispose(async () => {
    await Promise.allSettled([...tempDirectories].map((directory) => rm(directory, { recursive: true, force: true })));
  });
}
