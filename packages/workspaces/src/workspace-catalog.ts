import { existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { type Commands, WorkspaceError } from "./command";
import { type GitWorkspace, GitWorkspaces } from "./git-workspaces";
import { type JjWorkspace, Repository } from "./repository";
import type { Rex } from "./rex";
import { WorkspaceState } from "./state";
import { Workspaces } from "./workspaces";

export type WorkspaceKind = "jj" | "git";
export type WorkspaceEntry = (JjWorkspace & { kind: "jj" }) | GitWorkspace;

export class WorkspaceCatalog {
  private constructor(
    readonly git: GitWorkspaces,
    readonly jj: Repository | undefined,
    private readonly rex: Rex,
    private readonly stateDirectory: () => string,
  ) {}

  static load(
    cwd: string,
    commands: Commands,
    rex: Rex,
    stateDirectory: () => string,
  ): WorkspaceCatalog {
    const git = GitWorkspaces.load(cwd, commands);
    const jjPath = [git.root, git.primary].find((path) =>
      existsSync(join(path, ".jj")),
    );
    const jj = jjPath ? Repository.load(jjPath, commands) : undefined;
    if (
      jj &&
      (jj.commonGitDir !== git.commonGitDir || jj.primary !== git.primary)
    ) {
      throw new WorkspaceError(
        "state_conflict",
        "JJ and Git workspace inventories belong to different repositories.",
      );
    }
    return new WorkspaceCatalog(git, jj, rex, stateDirectory);
  }

  get defaultKind(): WorkspaceKind {
    return this.jj ? "jj" : "git";
  }

  list(): WorkspaceEntry[] {
    const jj: WorkspaceEntry[] =
      this.jj?.list().map((entry) => ({ ...entry, kind: "jj" })) ?? [];
    const jjPaths = new Set(
      jj.flatMap((entry) => (entry.path ? [resolve(entry.path)] : [])),
    );
    const git = this.git
      .list()
      .filter(
        (entry) =>
          !jjPaths.has(resolve(entry.path)) &&
          !existsSync(join(entry.path, ".jj")),
      );
    // An unregistered .jj checkout may be an archive. Never relabel and reopen
    // it as a live Git workspace merely because its Git registration survives.
    return [...jj, ...git];
  }

  private state(): WorkspaceState {
    return new WorkspaceState(this.stateDirectory(), this.git.commonGitDir);
  }

  private requireJj(): Repository {
    if (!this.jj) {
      throw new WorkspaceError(
        "not_jj",
        "This repository has no JJ workspace. Choose Git, or explicitly initialize JJ yourself; workspaces never converts repositories.",
      );
    }
    return this.jj;
  }

  private jjWorkspaces(): Workspaces {
    return new Workspaces(this.requireJj(), this.state(), this.rex);
  }

  private select(nameOrPath: string, kind?: WorkspaceKind): WorkspaceEntry {
    const matches = this.list().filter(
      (entry) =>
        (!kind || entry.kind === kind) &&
        (entry.name === nameOrPath || entry.path === nameOrPath),
    );
    const [workspace] = matches;
    if (!workspace || matches.length !== 1) {
      throw new WorkspaceError(
        "invalid_input",
        matches.length > 1
          ? "Workspace name is ambiguous. Specify --vcs jj|git or the exact checkout path."
          : "Workspace was not found in the selected repository. Use list to choose an existing workspace.",
      );
    }
    return workspace;
  }

  create(name: string, kind = this.defaultKind, base?: string): WorkspaceEntry {
    if (kind === "jj") {
      const jj = this.requireJj();
      const jjBase = base ?? "trunk";
      if (jjBase !== "trunk" && jjBase !== "current") {
        throw new WorkspaceError(
          "invalid_input",
          "JJ base must be trunk or current.",
        );
      }
      if (jjBase === "current" && jj.root !== this.git.root) {
        throw new WorkspaceError(
          "invalid_input",
          "Continue current JJ change requires a JJ source workspace. Open a JJ workspace first, or start from trunk.",
        );
      }
      return { ...this.jjWorkspaces().create(name, jjBase), kind: "jj" };
    }
    // Git creation uses committed Git history only, even from a JJ checkout.
    // It never snapshots the source or copies its uncommitted changes.
    return this.git.create(name, base ?? "current", this.state());
  }

  open(nameOrPath: string, kind?: WorkspaceKind): unknown {
    const workspace = this.select(nameOrPath, kind);
    if (workspace.kind === "jj")
      return this.jjWorkspaces().open(workspace.name);
    const target = this.git.workspace(workspace.path);
    try {
      return this.rex.open(target.path);
    } catch (cause) {
      throw new WorkspaceError(
        "partial_operation",
        `Git checkout is retained at ${target.path}, but Rex did not open it. Inspect the workspace list, then retry open; do not create a replacement checkout.`,
        { cause },
      );
    }
  }

  planCleanup(name: string) {
    return this.jjWorkspaces().planCleanup(name);
  }
  cleanup(name: string, confirmation: string) {
    return this.jjWorkspaces().cleanup(name, confirmation);
  }
}
