import type { PluginAPI } from "@ampcode/plugin";

export const description = "Reads GitHub pull request conversations with the locally authenticated gh CLI.";

type Input = { prNumber?: number; repo?: string; includeEmptyReviews?: boolean; maxComments?: number };
type User = { login?: string | null } | null;
type Summary = { number: number; title?: string; url?: string; author?: User };
type IssueComment = { id: number; user: User; body?: string | null; created_at: string; html_url: string };
type Review = { id: number; user: User; state: string; body?: string | null; submitted_at?: string | null; html_url?: string | null };
type ReviewComment = { id: number; user: User; body?: string | null; created_at: string; html_url: string; path?: string; line?: number | null; original_line?: number | null; in_reply_to_id?: number };
type Comment = { kind: "issue" | "review" | "review_comment"; id: number; author: string; state?: string; path?: string; line?: number; reply?: number; createdAt?: string; url?: string; body: string };

async function run(command: string, args: string[], cwd: string, timeoutMs = 20_000) {
  const process = Bun.spawn([command, ...args], { cwd, stdout: "pipe", stderr: "pipe" });
  const timeout = setTimeout(() => process.kill(), timeoutMs);
  const [stdout, stderr, code] = await Promise.all([
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
    process.exited,
  ]).finally(() => clearTimeout(timeout));
  return { stdout, stderr, code };
}

function parseRepo(remote: string): string | undefined {
  return remote.match(/^git@github\.com:([^/]+\/[^/]+?)(?:\.git)?$/)?.[1]
    ?? remote.match(/^https?:\/\/github\.com\/([^/]+\/[^/]+?)(?:\.git)?$/)?.[1];
}

async function resolveRepo(cwd: string, explicit?: string): Promise<string> {
  if (explicit) return explicit;
  for (const [command, args] of [["git", ["remote", "-v"]], ["jj", ["git", "remote", "list"]]] as const) {
    const result = await run(command, [...args], cwd, 5_000);
    if (result.code !== 0) continue;
    for (const line of result.stdout.split("\n")) {
      const repo = parseRepo(line.trim().split(/\s+/)[1] ?? "");
      if (repo) return repo;
    }
  }
  throw new Error("could not infer a GitHub owner/name repository from git or jj remotes");
}

async function ghJson<T>(cwd: string, args: string[]): Promise<T> {
  const result = await run("gh", args, cwd);
  if (result.code !== 0) throw new Error(result.stderr.trim() || result.stdout.trim() || `gh exited ${result.code}`);
  return JSON.parse(result.stdout) as T;
}

async function prNumber(cwd: string, repo: string, selector?: string): Promise<number | undefined> {
  try {
    const args = ["pr", "view", ...(selector ? [selector] : []), "--repo", repo, "--json", "number"];
    return (await ghJson<{ number?: number }>(cwd, args)).number;
  } catch {
    return undefined;
  }
}

async function resolvePr(cwd: string, input: Input) {
  const repo = await resolveRepo(cwd, input.repo);
  if (input.prNumber !== undefined) return { repo, number: input.prNumber };
  const direct = await prNumber(cwd, repo);
  if (direct !== undefined) return { repo, number: direct };

  const candidates = new Set<string>();
  const branch = await run("git", ["branch", "--show-current"], cwd, 5_000);
  if (branch.code === 0 && branch.stdout.trim()) candidates.add(branch.stdout.trim());
  const bookmarks = await run("jj", ["log", "--no-graph", "-r", "@ | @-", "--template", 'bookmarks ++ "\\n"'], cwd, 5_000);
  if (bookmarks.code === 0) bookmarks.stdout.split(/\s+/).filter(Boolean).forEach((value) => candidates.add(value));
  for (const candidate of candidates) {
    const number = await prNumber(cwd, repo, candidate);
    if (number !== undefined) return { repo, number };
  }
  throw new Error(`failed to resolve a PR from the current branch or jj bookmarks; pass prNumber explicitly`);
}

async function pages<T>(cwd: string, endpoint: string): Promise<T[]> {
  return (await ghJson<T[][]>(cwd, ["api", "--paginate", "--slurp", endpoint])).flat();
}

function login(user: User | undefined): string {
  return user?.login ?? "unknown";
}

function normalized(issue: IssueComment[], reviews: Review[], inline: ReviewComment[], includeEmpty: boolean): Comment[] {
  const comments: Comment[] = issue.map((comment) => ({
    kind: "issue", id: comment.id, author: login(comment.user), createdAt: comment.created_at, url: comment.html_url, body: comment.body ?? "",
  }));
  for (const review of reviews) {
    if (!includeEmpty && !(review.body ?? "").trim()) continue;
    comments.push({ kind: "review", id: review.id, author: login(review.user), state: review.state, createdAt: review.submitted_at ?? undefined, url: review.html_url ?? undefined, body: review.body ?? "" });
  }
  for (const comment of inline) {
    comments.push({ kind: "review_comment", id: comment.id, author: login(comment.user), path: comment.path, line: comment.line ?? comment.original_line ?? undefined, reply: comment.in_reply_to_id, createdAt: comment.created_at, url: comment.html_url, body: comment.body ?? "" });
  }
  return comments.sort((a, b) => String(a.createdAt ?? "").localeCompare(String(b.createdAt ?? "")) || a.id - b.id);
}

function format(comment: Comment): string {
  const location = comment.path ? ` ${comment.path}${comment.line ? `:${comment.line}` : ""}` : "";
  const state = comment.state ? ` [${comment.state}]` : "";
  const reply = comment.reply ? ` (reply to ${comment.reply})` : "";
  return `- ${comment.kind}${state} #${comment.id}${location}${reply} by ${comment.author} at ${comment.createdAt ?? "unknown"}\n  ${comment.body.replace(/\n/g, "\n  ")}${comment.url ? `\n  ${comment.url}` : ""}`;
}

export default function githubPrComments(amp: PluginAPI) {
  const cwd = amp.system.workspaceRoot ? amp.helpers.filePathFromURI(amp.system.workspaceRoot) : process.cwd();
  amp.registerTool({
    name: "github_pr_comments",
    title: "GitHub PR comments",
    description: "Read issue comments, reviews, and inline review comments from a GitHub pull request using the authenticated gh CLI.",
    inputSchema: {
      type: "object",
      properties: {
        prNumber: { type: "number", description: "PR number; inferred from the current branch when omitted" },
        repo: { type: "string", description: "Repository in owner/name form; inferred from remotes when omitted" },
        includeEmptyReviews: { type: "boolean", description: "Include reviews with no body" },
        maxComments: { type: "integer", minimum: 1, maximum: 1000, description: "Maximum comments, default 200" },
      },
    },
    async execute(raw) {
      try {
        const input = raw as Input;
        const pr = await resolvePr(cwd, input);
        const [summary, issue, reviews, inline] = await Promise.all([
          ghJson<Summary>(cwd, ["pr", "view", String(pr.number), "--repo", pr.repo, "--json", "number,title,url,author"]),
          pages<IssueComment>(cwd, `repos/${pr.repo}/issues/${pr.number}/comments?per_page=100`),
          pages<Review>(cwd, `repos/${pr.repo}/pulls/${pr.number}/reviews?per_page=100`),
          pages<ReviewComment>(cwd, `repos/${pr.repo}/pulls/${pr.number}/comments?per_page=100`),
        ]);
        const all = normalized(issue, reviews, inline, input.includeEmptyReviews ?? false);
        const comments = all.slice(0, input.maxComments ?? 200);
        const header = `GitHub PR comments for ${pr.repo}#${summary.number}: ${summary.title ?? "(untitled)"}\n${summary.url ?? ""}\nAuthor: ${login(summary.author)}\nCounts: ${issue.length} issue comments, ${reviews.length} reviews, ${inline.length} inline comments${comments.length < all.length ? `; showing ${comments.length} of ${all.length}` : ""}`;
        return `${header}\n\n${comments.length ? comments.map(format).join("\n\n") : "No comments found."}`;
      } catch (error) {
        throw new Error(`github_pr_comments failed: ${error instanceof Error ? error.message : String(error)}`);
      }
    },
  });
}
