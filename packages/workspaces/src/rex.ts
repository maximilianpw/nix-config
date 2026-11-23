import { realpathSync } from "node:fs";
import { isAbsolute } from "node:path";
import { z } from "zod";
import { type Commands, parse, parseJson, WorkspaceError } from "./command";
import { containsPath } from "./repository";

export function targetDirectory(
  explicit: string | undefined,
  cwd: string,
): string {
  const path = explicit ?? cwd;
  if (!isAbsolute(path)) {
    throw new WorkspaceError(
      "invalid_input",
      "Repository target is relative. Supply an absolute --repo path.",
    );
  }
  return realpathSync(path);
}

// Every terminal on the server with its foreground directory. A terminal
// whose directory is unknown is listed without one, so cleanup refuses
// rather than assuming the checkout is free.
const listTerminals = `
local terminal = "com.superlogical.terminal"
local listed = {}
for _, session in ipairs(assert(rex.call("session.list")).sessions) do
  local view = rex.call("session.view", { session_id = session.session_id })
  if view == nil then
    rex.session.attach({ session_id = session.session_id })
    view = assert(rex.call("session.view", { session_id = session.session_id }))
  end
  for _, window in ipairs(view.windows) do
    for _, layer in ipairs(window.layers) do
      for _, block in ipairs(layer.blocks) do
        if block.creator_name == terminal then
          local proc = rex.block.call(terminal, "process", {
            session_id = session.session_id,
            block_id = block.block_id,
          })
          listed[#listed + 1] = { cwd = proc and proc.foreground and proc.foreground.cwd }
        end
      end
    end
  end
end
-- An empty Lua table encodes as an object; the reader requires an array.
io.write('{"terminals":', #listed == 0 and "[]" or assert(rex.json.encode(listed)), "}")
`;

const terminalsSchema = z.object({
  terminals: z.array(z.object({ cwd: z.string().nullable().optional() })),
});

// The Rex server is the workspace host: it shows checkouts as sessions
// (the project_open action in ~/.config/rex/projects.lua) and knows which
// terminals still sit inside one.
export class Rex {
  constructor(
    private readonly commands: Commands,
    private readonly cwd: string,
  ) {}

  terminals() {
    return parse(
      terminalsSchema,
      parseJson(
        this.commands.output("rex", ["do", "-e", listTerminals], this.cwd),
      ),
      "Rex terminal list",
    ).terminals;
  }

  assertClosed(path: string): void {
    // An idle agent or shell still owns the directory; require closing/moving it.
    const unsafe = this.terminals().some(
      ({ cwd }) => !cwd || containsPath(path, realpathSync(cwd)),
    );
    if (unsafe) {
      throw new WorkspaceError(
        "unsafe_cleanup",
        "Workspace still has a Rex terminal inside it, or a terminal's directory is unknown. Close or move those terminals, then retry from another checkout.",
      );
    }
  }

  open(path: string): unknown {
    // The workspace owner has already created and validated the checkout.
    return parseJson(
      this.commands.output(
        "rex",
        ["do", "--json", "project_open", `dir=${path}`],
        this.cwd,
      ),
    );
  }
}
