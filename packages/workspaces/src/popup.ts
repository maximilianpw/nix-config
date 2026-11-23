import { WorkspaceError } from "./command";
import {
  InputDialog,
  runDialog,
  WorkspaceForm,
  WorkspacePicker,
} from "./popup-ui";
import type { WorkspaceCatalog } from "./workspace-catalog";

export async function runPopup(
  action: "create" | "open" | "cleanup",
  workspaces: WorkspaceCatalog,
): Promise<void> {
  try {
    if (action === "create") {
      const draft = await runDialog(
        new WorkspaceForm({
          primary: workspaces.git.primary,
          allowJj: Boolean(workspaces.jj),
          allowCurrentJj: workspaces.jj?.root === workspaces.git.root,
        }),
      );
      workspaces.create(draft.name, draft.kind, draft.base);
      workspaces.open(draft.name, draft.kind);
      return;
    }
    const items = workspaces
      .list()
      .filter(
        (workspace) =>
          workspace.path &&
          (action !== "cleanup" ||
            (workspace.kind === "jj" &&
              workspace.path !== workspaces.jj?.primary)),
      );
    if (items.length === 0)
      throw new WorkspaceError(
        "invalid_input",
        action === "cleanup"
          ? "No eligible JJ workspaces. Git cleanup is not supported."
          : "No workspaces are available in this repository.",
      );
    const selection = await runDialog(
      new WorkspacePicker(
        action === "open" ? "open workspace" : "archive JJ workspace",
        items.flatMap((item) =>
          item.path
            ? [
                {
                  id: item.path,
                  name: item.name,
                  path: item.path,
                  kind: item.kind,
                  current: item.path === workspaces.git.root,
                },
              ]
            : [],
        ),
        action === "open" ? "open" : "continue",
      ),
    );
    const workspace = items.find((item) => item.path === selection);
    if (!workspace)
      throw new WorkspaceError(
        "state_conflict",
        "Workspace selection was lost. Reopen the picker.",
      );
    if (action === "open") {
      workspaces.open(selection, workspace.kind);
      return;
    }
    const plan = workspaces.planCleanup(workspace.name);
    const confirmation = await runDialog(
      new InputDialog(
        "confirm archive",
        [
          "Close or move every Rex terminal inside it first.",
          "Tracked work is snapshotted and pinned. Files move to an archive; nothing is deleted. Ignored files block cleanup.",
          "Type the full path to confirm:",
          plan.path,
        ],
        "archive",
      ),
    );
    const receipt = workspaces.cleanup(workspace.name, confirmation);
    await runDialog(
      new InputDialog(
        "Archived without deleting files",
        [receipt.archive, `Recovery: ${receipt.bookmark}`],
        "close",
      ),
    );
  } catch (cause) {
    if (cause instanceof WorkspaceError && cause.code === "cancelled") return;
    if (!process.stdin.isTTY) throw cause;
    const message =
      cause instanceof WorkspaceError
        ? cause.message
        : "Operation failed. Inspect the repository and workspace state before retrying.";
    try {
      await runDialog(
        new InputDialog("workspace unavailable", [message], "close"),
      );
    } catch (dismissal) {
      if (
        !(dismissal instanceof WorkspaceError && dismissal.code === "cancelled")
      )
        throw dismissal;
    }
    throw cause;
  }
}
