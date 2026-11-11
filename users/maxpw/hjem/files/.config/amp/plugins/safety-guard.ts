import path from "node:path";
import type { PluginAPI, ToolCallResult } from "@ampcode/plugin";

export const description = "Blocks protected-path writes and Git hook bypasses, and confirms dangerous local shell commands.";

const DANGEROUS_COMMANDS = [
  { pattern: /\brm\s+(?:-[^\s]*r[^\s]*f?|-[^\s]*f[^\s]*r|--recursive|--force)/i, label: "recursive/forced remove" },
  { pattern: /\bsudo\b/i, label: "sudo" },
  { pattern: /\b(chmod|chown|chgrp)\b.*\b(?:777|666)\b/i, label: "broad permission/ownership change" },
  { pattern: /\b(?:dd|mkfs|diskutil|shutdown|reboot)\b/i, label: "system/disk operation" },
  { pattern: /\b(?:curl|wget)\b[^\n|;]*\|\s*(?:sh|bash|zsh)\b/i, label: "downloaded script execution" },
];

const WRITEISH_COMMAND = /\b(?:rm|mv|cp|mkdir|touch|chmod|chown|chgrp|ln|tee|truncate|dd|mkfs|install)\b|(?:^|[^<])>(?!>)|>>|\b(?:npm|pnpm|yarn|bun)\s+(?:install|add|remove|uninstall|update|ci|link|publish)\b|\b(?:git|jj)\s+(?:add|commit|push|pull|merge|rebase|reset|checkout|branch|stash|cherry-pick|revert|tag|init|clone|new|squash|describe|bookmark)\b/i;
const GIT_COMMAND = /(?:^|[;&|(\n]\s*)git(?:\s|$)/;
const GIT_ENV = "export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\n";
const PATH_WRITE_TOOLS = new Set(["apply_patch", "create_file", "write_file", "edit_file", "write", "edit"]);

function protectedPath(raw: string, cwd: string): string | undefined {
  const absolute = path.resolve(cwd, raw.startsWith("@") ? raw.slice(1) : raw);
  const base = path.basename(absolute);
  if (base === ".env" || base.startsWith(".env.")) return ".env files";
  if (absolute === "/nix/store" || absolute.startsWith("/nix/store/")) return "/nix/store";
  if (absolute.includes(`${path.sep}.git${path.sep}`)) return ".git";
  if (absolute.includes(`${path.sep}.jj${path.sep}`)) return ".jj";
  if (absolute.includes(`${path.sep}node_modules${path.sep}`)) return "node_modules";
  if (absolute.endsWith(`${path.sep}.pi${path.sep}agent${path.sep}auth.json`)) return "Pi auth.json";
  return undefined;
}

function protectedCommandPath(command: string): string | undefined {
  if (/\/nix\/store(?:\/|\b)/.test(command)) return "/nix/store";
  if (/(?:^|[\s'\"])(?:\.\/)?\.env(?:\b|\.)/.test(command)) return ".env files";
  if (/(?:^|[\s'\"])(?:node_modules|\.git|\.jj)(?:\/|\b)/.test(command)) return "protected metadata";
  return undefined;
}

function pathsFromPatch(patchText: string): string[] {
  return [...patchText.matchAll(/^\*\*\* (?:Add|Update|Delete) File: (.+)$/gm)].map((match) => match[1]);
}

function reject(message: string): ToolCallResult {
  return { action: "reject-and-continue", message };
}

export default function safetyGuard(amp: PluginAPI) {
  const cwd = amp.system.workspaceRoot
    ? amp.helpers.filePathFromURI(amp.system.workspaceRoot)
    : process.cwd();

  amp.on("tool.call", async (event, ctx) => {
    const directPath = PATH_WRITE_TOOLS.has(event.tool) && typeof event.input.path === "string"
      ? event.input.path
      : undefined;
    const patchPaths = typeof event.input.patchText === "string" ? pathsFromPatch(event.input.patchText) : [];
    for (const candidate of directPath ? [directPath, ...patchPaths] : patchPaths) {
      const reason = protectedPath(candidate, cwd);
      if (reason) return reject(`Blocked ${event.tool} write to protected path (${reason}): ${candidate}`);
    }

    const shell = amp.helpers.shellCommandFromToolCall(event);
    if (!shell) return { action: "allow" };

    const dangerous = DANGEROUS_COMMANDS.find(({ pattern }) => pattern.test(shell.command));
    if (dangerous) {
      if (amp.activeThread.current?.id !== event.thread.id) {
        return reject(`Dangerous background command blocked: ${dangerous.label}`);
      }
      const allowed = await ctx.ui.confirm({
        title: "Dangerous shell command",
        message: `${dangerous.label}:\n\n\`\`\`sh\n${shell.command}\n\`\`\``,
        confirmButtonText: "Allow",
      });
      if (!allowed) return reject(`Dangerous command blocked: ${dangerous.label}`);
    }

    const commandPath = protectedCommandPath(shell.command);
    if (commandPath && WRITEISH_COMMAND.test(shell.command)) {
      return reject(`Blocked shell command that appears to modify ${commandPath}.`);
    }
    if (/--no-verify\b/.test(shell.command) && GIT_COMMAND.test(shell.command)) {
      return reject("Blocked --no-verify. Fix the failing Git hook or ask the user for help.");
    }
    if (GIT_COMMAND.test(shell.command) && !shell.command.startsWith(GIT_ENV)) {
      return { action: "modify", input: { ...event.input, command: `${GIT_ENV}${shell.command}` } };
    }
    return { action: "allow" };
  });
}
