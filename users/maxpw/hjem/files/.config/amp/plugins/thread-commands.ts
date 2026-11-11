import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import type { PluginAPI, PluginThread, ThreadMessage } from "@ampcode/plugin";

export const description = "Saves the latest answer, copies a transcript, and summarizes local Git or Jujutsu changes.";

const JJ_PROMPT = `Inspect the current Jujutsu repository, then respond with only:\n\n1. A short 1–2 sentence summary of the current working-copy change.\n2. A list of changed files with +/- line counts when available.\n3. A total +/- line count at the bottom when available.\n\nUse jj commands, not git commands. Prefer jj st, jj diff --stat, and jj diff. Keep it concise.`;
const GIT_PROMPT = `Inspect the current Git repository, then respond with only:\n\n1. A short 1–2 sentence summary of the current worktree changes.\n2. A list of changed files with +/- line counts when available.\n3. A total +/- line count at the bottom when available.\n\nPrefer git status --short, git diff --stat HEAD, and git diff HEAD. Keep it concise.`;

function text(message: ThreadMessage): string {
  return message.content
    .filter((block): block is Extract<typeof block, { type: "text" }> => block.type === "text")
    .map((block) => block.text)
    .join("\n\n");
}

async function allMessages(thread: PluginThread): Promise<ThreadMessage[]> {
  const messages: ThreadMessage[] = [];
  for (let offset = 0; ; offset += 20) {
    const page = await thread.messages({ full: true, from: "start", offset, limit: 20 });
    messages.push(...page);
    if (page.length < 20) return messages;
  }
}

async function commandSucceeds(command: string, args: string[], cwd: string): Promise<boolean> {
  try {
    const child = Bun.spawn([command, ...args], { cwd, stdout: "ignore", stderr: "ignore" });
    const timeout = setTimeout(() => child.kill(), 2_000);
    const code = await child.exited.finally(() => clearTimeout(timeout));
    return code === 0;
  } catch {
    return false;
  }
}

async function copyToClipboard(value: string): Promise<void> {
  const commands = process.platform === "darwin"
    ? [["pbcopy"]]
    : process.platform === "win32"
      ? [["clip"]]
      : [["wl-copy"], ["xclip", "-selection", "clipboard"]];
  for (const command of commands) {
    try {
      const child = Bun.spawn(command, { stdin: "pipe", stdout: "ignore", stderr: "ignore" });
      child.stdin.write(value);
      child.stdin.end();
      if (await child.exited === 0) return;
    } catch {
      // Try the next platform clipboard command.
    }
  }
  throw new Error("No supported clipboard command is available");
}

export default function threadCommands(amp: PluginAPI) {
  const cwd = amp.system.workspaceRoot ? amp.helpers.filePathFromURI(amp.system.workspaceRoot) : process.cwd();

  amp.registerCommand("save-md", {
    title: "Save latest answer as Markdown",
    category: "Thread",
    description: "Save the latest assistant response without thinking or tool calls",
  }, async (ctx) => {
    if (!ctx.thread) return ctx.ui.notify("Start a thread before saving an answer.");
    const latest = (await ctx.thread.messages({ from: "end", limit: 20 })).reverse().find((message) => message.role === "assistant");
    if (!latest) return ctx.ui.notify("No assistant response to save.");
    const markdown = text(latest);
    if (!markdown.trim()) return ctx.ui.notify("The latest assistant response has no Markdown text.");
    const name = await ctx.ui.input({ title: "Save Markdown", helpText: "Filename relative to the workspace", submitButtonText: "Save" });
    if (!name?.trim()) return;
    const file = resolve(cwd, name.trim().endsWith(".md") ? name.trim() : `${name.trim()}.md`);
    try {
      await writeFile(file, markdown.endsWith("\n") ? markdown : `${markdown}\n`, { encoding: "utf8", flag: "wx" });
      await ctx.ui.notify(`Saved Markdown to ${file}`);
    } catch (error) {
      if (error && typeof error === "object" && "code" in error && error.code === "EEXIST") {
        await ctx.ui.notify(`File already exists: ${file}`);
        return;
      }
      throw error;
    }
  });

  amp.registerCommand("copy-all", {
    title: "Copy thread transcript",
    category: "Thread",
    description: "Copy all user and assistant messages to the clipboard",
  }, async (ctx) => {
    if (!ctx.thread) return ctx.ui.notify("Start a thread before copying its transcript.");
    const sections = (await allMessages(ctx.thread))
      .filter((message) => message.role === "user" || message.role === "assistant")
      .map((message) => ({ role: message.role, value: text(message).trim() }))
      .filter(({ value }) => value)
      .map(({ role, value }) => `${role.toUpperCase()}:\n${value}`);
    if (!sections.length) return ctx.ui.notify("No user or assistant messages to copy.");
    await copyToClipboard(sections.join("\n\n---\n\n"));
    await ctx.ui.notify(`Copied ${sections.length} messages to the clipboard.`);
  });

  amp.registerCommand("changes", {
    title: "Summarize VCS changes",
    category: "VCS",
    description: "Ask the agent for a concise summary of current Git or Jujutsu changes",
  }, async (ctx) => {
    if (!ctx.thread) return ctx.ui.notify("Start a thread before summarizing changes.");
    const prompt = await commandSucceeds("jj", ["root"], cwd)
      ? JJ_PROMPT
      : await commandSucceeds("git", ["rev-parse", "--show-toplevel"], cwd)
        ? GIT_PROMPT
        : undefined;
    if (!prompt) return ctx.ui.notify("No Jujutsu or Git repository found.");
    await ctx.thread.appendUserMessage({ type: "user-message", content: prompt }, { steer: true });
  });
}
