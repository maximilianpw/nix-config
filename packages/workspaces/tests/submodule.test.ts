import { afterEach, beforeEach, expect, test } from "bun:test";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";
import { parse } from "../src/command";
import { Repository } from "../src/repository";
import { type Fixture, fixture } from "./fixtures";

let f: Fixture;
beforeEach(() => {
  f = fixture("submodule");
});
afterEach(() => {
  f.dispose();
});

function success(args: string[]) {
  const result = f.cli(args);
  expect(result.stderr).toBe("");
  expect(result.status).toBe(0);
  return result.json();
}

test("submodule primary and linked JJ workspaces share repository identity", () => {
  const primary = Repository.load(f.repo, f.commands);
  expect(primary.primary).toBe(f.repo);
  expect(primary.commonGitDir).not.toBe(join(f.repo, ".git"));
  success(["create", "task", "--no-open"]);
  const linked = Repository.load(f.path("task"), f.commands);
  expect(linked.primary).toBe(f.repo);
  expect(linked.commonGitDir).toBe(primary.commonGitDir);
  expect(linked.workspace("default").path).toBe(f.repo);
  expect(primary.workspace("task").path).toBe(f.path("task"));
  expect(linked.status().files).toBe(0);
  expect(readFileSync(join(f.path("task"), "hello.txt"), "utf8")).toBe(
    "trunk\n",
  );
  success(["open", "task"]);
  expect(f.calls()).toContainEqual(["project_open", `dir=${f.path("task")}`]);
});

test("submodule cleanup still protects primary and archives linked workspace files", () => {
  const refused = f.cli(["cleanup", "default", "--confirm", f.repo]);
  expect(refused.json()).toMatchObject({ error: { code: "unsafe_cleanup" } });
  success(["create", "task", "--no-open"]);
  writeFileSync(join(f.path("task"), "hello.txt"), "preserved\n");
  const receipt = parse(
    z.object({ result: z.object({ archive: z.string() }) }),
    success(["cleanup", "task", "--confirm", f.path("task")]),
    "test receipt",
  ).result;
  expect(existsSync(f.path("task"))).toBe(false);
  expect(readFileSync(join(receipt.archive, "hello.txt"), "utf8")).toBe(
    "preserved\n",
  );
  expect(
    Repository.load(f.repo, f.commands)
      .list()
      .map((workspace) => workspace.name),
  ).toEqual(["default"]);
});

test("submodule picker combines both types from a linked Git-only checkout", () => {
  success(["create", "jj-task", "--no-open"]);
  success(["create", "git-task", "--vcs", "git", "--no-open"]);
  const gitPath = `${f.repo}.git-git-task`;
  const result = f.cli(["list"], {}, gitPath);
  expect(result.status).toBe(0);
  const inventory = parse(
    z.object({
      result: z.object({
        workspaces: z.array(
          z.object({
            kind: z.enum(["jj", "git"]),
            path: z.string(),
          }),
        ),
      }),
    }),
    result.json(),
    "mixed submodule list",
  ).result.workspaces;
  expect(inventory).toEqual([
    { kind: "jj", path: f.repo },
    { kind: "jj", path: f.path("jj-task") },
    { kind: "git", path: gitPath },
  ]);
  const opened = f.cli(["open", "git-task", "--vcs", "git"], {}, gitPath);
  expect(opened.status).toBe(0);
  expect(f.calls()).toContainEqual(["project_open", `dir=${gitPath}`]);
});

test("a substituted Git directory is rejected even for submodule repositories", () => {
  success(["create", "task", "--no-open"]);
  writeFileSync(
    join(f.path("task"), ".git"),
    `gitdir: ${join(f.directory, "source", ".git")}\n`,
  );
  expect(() => Repository.load(f.path("task"), f.commands)).toThrow(
    "Git and jj do not share",
  );
});
