import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { appHome, exec, focused, hc, nextCommand, notify, openOverlay, panes, readTextFile, run, setShared, shared, spaces, terminals, theme, writeTextFile } from "herdr";

const backend = () => `${appHome()}/mods/migrated-tools/backend/tools.mjs`;

function result(response) {
  if (response.code !== 0) {
    let message = response.stderr?.trim() || "The migrated tool failed";
    try { message = JSON.parse(message).error.message; } catch {}
    throw new Error(message);
  }
  return response.stdout.trim() ? JSON.parse(response.stdout) : null;
}

function target() {
  const f = focused();
  if (!f) throw new Error("Focus a terminal pane first");
  const s = spaces().find((space) => space.id === f.space);
  const stack = shared("migrated.tool-stack");
  const top = Array.isArray(stack) ? stack.at(-1) : null;
  if (top) {
    const tool = terminals().find((t) => t.address === top.terminal);
    if (!tool || tool.state !== "live" || tool.labels?.["migrated.tool"] !== "1") throw new Error("The tool popup is closing or its core facts are still loading. Close it from its header; after a crash, use Reset tools in the status bar before operating on the underlying pane");
    return { ...f, pane: null, shown: null, terminal: tool.address, cwd: tool.foreground?.cwd || tool.cwd, machine: tool.address.includes("/") ? tool.address.slice(0, tool.address.lastIndexOf("/")) : null };
  }
  const terminal = f.shown || f.terminal;
  const machine = terminal ? (terminal.includes("/") ? terminal.slice(0, terminal.lastIndexOf("/")) : null) : s?.machine ?? null;
  return { ...f, terminal, machine };
}

export default class MigratedTools extends View {
  init(_props, cx) {
    this.paths = null;
    this.previous = {};
    this.current = {};
    this.error = null;
    this.busyRefresh = false;
    this.requests = [];
    this.draining = false;
    const interrupted = shared("migrated.transfer");
    this.transfer = interrupted && typeof interrupted.terminal === "string" && /^(?:[a-zA-Z0-9][a-zA-Z0-9_.-]*\/)?t[a-z0-9]+$/.test(interrupted.terminal) && typeof interrupted.space === "string" && typeof interrupted.pane === "string" && typeof interrupted.tab === "string" ? interrupted : null;
    if (interrupted && !this.transfer) notify({ title: "Invalid interrupted-transfer record", body: "No terminal was changed. Inspect migrated.transfer in the App's shared state before attempting recovery.", level: "warning" });
    if (this.transfer) cx.spawn(async (cx) => {
      try {
        result(await hc(["keep", this.transfer.terminal, "--json"]));
        notify({ title: "Interrupted break-pane", body: `${this.transfer.terminal} was kept running. Use Recover in the status bar to finish or inspect it.` });
        cx.notify();
      } catch (error) { this.error = error.message; cx.notify(); }
    });
    cx.spawn(async (cx) => {
      try { this.paths = result(await exec("bun", [backend(), "setup"])); await this.refresh(cx); }
      catch (error) { this.error = error.message; cx.notify(); }
    });
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        let pinned;
        try { pinned = target(); } catch (error) { notify({ title: "No migration target", body: error.message, level: "warning" }); continue; }
        this.requests.push({ command, pinned });
        this.drain(cx);
      }
    });
    cx.timer.every(15000, (cx) => {
      if (this.paths) cx.spawn(async (cx) => {
        try { await this.refresh(cx); } catch (error) { this.error = error.message; cx.notify(); }
      });
    });
  }

  drain(cx) {
    if (this.draining) return;
    this.draining = true;
    cx.spawn(async (cx) => {
      try {
        while (this.requests.length) {
          const request = this.requests.shift();
          try { await this.act(request.command, request.pinned, cx); }
          catch (error) { notify({ title: "Migrated tool unavailable", body: error.message, level: "error", timeout: 9000 }); }
        }
      } finally { this.draining = false; }
    });
  }

  async close() {
    if (this.transfer) await exec("hc", ["keep", this.transfer.terminal, "--json"]);
  }

  resetToolTracking() {
    setShared("migrated.tool-stack", []);
    notify({ title: "Stale tool tracking cleared", body: "Existing core programs were not stopped. Inspect hc ls --label migrated.tool=1 before reopening duplicate tools.", level: "warning" });
  }

  clearTransfer() {
    this.transfer = null;
    setShared("migrated.transfer", null);
  }

  async finishTransfer(cx) {
    for (let attempt = 0; attempt < 50; attempt++) {
      if (panes().some((p) => p.terminal === this.transfer.terminal && p.pane !== this.transfer.pane)) { this.clearTransfer(); return; }
      await cx.sleep(100);
    }
    throw new Error(`Terminal ${this.transfer.terminal} is still running; adoption was not confirmed. Use Recover in the status bar after inspecting it.`);
  }

  async launch(title, argv, original, cx, local = false) {
    const args = ["run", "--bg", "--json", "--no-parent", "--outlive-parent", "--no-notify", "--rm", "--label", "migrated.tool=1", "--label", `migrated.title=${title}`];
    if (!local && original.machine) args.push("--on", original.machine);
    const folder = local ? appHome() : original.cwd;
    if (folder) args.push("--cwd", folder);
    args.push("--", "sh", "-c", '"$@"; code=$?; if [ "$code" -ne 0 ]; then printf "\\nTool exited with status %s. Press Enter to close.\\n" "$code"; IFS= read -r answer; fi; exit "$code"', "migrated-tool", ...argv);
    const created = result(await hc(args));
    const address = created?.address;
    if (typeof address !== "string") throw new Error("Core started no identifiable tool terminal; inspect hc ls before trying again");
    // Dialog layout overlays focus their first terminal natively. pane.focus
    // only targets the root chrome/model, not floating overlay terminal blocks.
    openOverlay({ kind: "dialog", modal: true, width: 0.9, height: 0.9, layout: {
      id: "tool-window", type: "column", children: [
        { id: "tool-header", type: "block", size: { px: 34 }, content: { mod: "migrated-terminal", props: { terminal: address, title, owned: true } } },
        { id: "tool-body", type: "block", content: { terminal: address } },
      ],
    } });
  }

  async refresh(cx) {
    if (this.busyRefresh || !this.paths) return;
    this.busyRefresh = true;
    try {
      result(await exec("env", [`HERDR_BIN_PATH=${this.paths.bridge}`, `HERDR_PLUGIN_CONFIG_DIR=${this.paths.jj}`, "herdr-jj", "refresh"], { cwd: appHome() }));
      const raw = await readTextFile(this.paths.metadata);
      const statuses = raw ? JSON.parse(raw) : {};
      const active = new Set(spaces().map((s) => s.id));
      const tokens = Object.fromEntries(Object.entries(statuses).filter(([id, value]) => active.has(id) && value.expires > Date.now()).map(([id, value]) => [id, value.tokens]));
      if (JSON.stringify(tokens) !== JSON.stringify(shared("migrated.vcs") ?? {})) setShared("migrated.vcs", tokens);
      this.error = null;
      cx.notify();
    } finally { this.busyRefresh = false; }
  }

  async navigate(direction, original, cx) {
    if (!original.terminal) return;
    const key = `ctrl+${{ left: "h", down: "j", up: "k", right: "l" }[direction]}`;
    if (!original.pane) { result(await hc(["keys", original.terminal, key, "--json"])); return; }
    const t = terminals().find((terminal) => terminal.address === original.terminal);
    const foreground = t?.foreground;
    if (!foreground) throw new Error("Core foreground facts are still loading; press the navigation key again");
    if (/(^|\/)n?vim(?:diff)?$/.test(foreground?.name || "")) {
      const routed = result(await exec("bun", [backend(), "navigation", original.terminal, String(foreground.pid), direction, original.machine || ""]));
      if (routed.route === "editor") return;
      if (routed.route === "terminal") {
        result(await hc(["keys", original.terminal, `ctrl+${{ left: "h", down: "j", up: "k", right: "l" }[direction]}`, "--json"]));
        if (routed.warning) notify({ title: "Editor navigation", body: routed.warning, level: "warning" });
        return;
      }
    }
    if (focused()?.pane !== original.pane) throw new Error("Focus changed during navigation; press the key again");
    run("pane.go", { direction });
  }

  async breakPane(original, cx) {
    if (!original.pane || !original.terminal || original.shown) throw new Error("Break-pane requires a normal terminal pane, not a replacement or mod pane");
    if (panes().filter((p) => p.tab === original.tab).length < 2) throw new Error("This pane already has its own tab");
    if (focused()?.pane !== original.pane) throw new Error("Focus changed; no pane was moved");
    if (this.transfer) throw new Error("An interrupted pane transfer needs Recover before another break-pane");
    this.transfer = { terminal: original.terminal, pane: original.pane, space: original.space, tab: original.tab };
    setShared("migrated.transfer", this.transfer);
    run("terminal.park", { terminal: original.terminal });
    // park/keep acknowledge asynchronously. Wait for actual model removal,
    // never close the program or replay park after an uncertain result.
    try {
      for (let attempt = 0; attempt < 50; attempt++) {
        await cx.sleep(100);
        if (!panes().some((p) => p.terminal === original.terminal)) {
          if (focused()?.space !== original.space) throw new Error(`Terminal ${original.terminal} is parked and still running. Return to its original space, then use Recover.`);
          run("terminal.keep", { terminal: original.terminal, place: "tab" });
          await this.finishTransfer(cx);
          return;
        }
      }
      throw new Error(`Break-pane did not confirm removal. Inspect terminal ${original.terminal} before trying again.`);
    } catch (error) {
      result(await hc(["keep", original.terminal, "--json"]));
      throw error;
    }
  }

  async act(command, original, cx) {
    if (command === "verify-popup") return this.launch("Migration popup check", ["sh", "-c", 'printf "Migration popup check\\n\\nThis is a task-created terminal, not one of your existing panes.\\nVerification is in progress; please leave this test popup open. I will close it.\\n"; IFS= read -r answer'], original, cx, true);
    if (command === "recover-transfer") {
      if (!this.transfer) return;
      if (panes().some((p) => p.terminal === this.transfer.terminal)) { this.clearTransfer(); return; }
      if (!spaces().some((s) => s.id === this.transfer.space)) throw new Error(`The original space is gone. Terminal ${this.transfer.terminal} is kept running; open it explicitly from the terminal picker.`);
      run("space.select", { id: this.transfer.space });
      run("terminal.keep", { terminal: this.transfer.terminal, place: "tab" });
      return this.finishTransfer(cx);
    }
    const structural = ["new-tab", "new-space", "split-right", "split-down", "close-tab", "close-space", "close-pane", "break-pane"].includes(command);
    if (structural && this.transfer) throw new Error(`Finish or inspect the interrupted transfer of ${this.transfer.terminal} with Recover before changing tabs/panes`);
    if (structural && original.pane && !panes().some((p) => p.pane === original.pane && p.tab === original.tab)) throw new Error("The original pane moved or closed before this command ran; no structural command was replayed");
    if (command === "new-tab" || command === "new-space") {
      const args = original.machine ? {} : { argv: ["fish", "--login"] };
      if (command === "new-tab") args.space = original.space;
      else if (original.machine) args.machine = original.machine;
      if (original.cwd) args.folder = original.cwd;
      openOverlay({ mod: "prompt", kind: "dialog", width: 420, props: {
        title: command === "new-tab" ? "New tab" : "New space",
        command: { name: command === "new-tab" ? "tab.new" : "space.new", args },
      } });
      return;
    }
    if (command === "split-right" || command === "split-down") {
      if (original.pane) run("pane.split", { pane: original.pane, direction: command.slice(6), ...(original.machine ? {} : { argv: ["fish", "--login"] }) });
      return;
    }
    if (command === "close-tab") {
      if (!original.pane) {
        if (terminals().some((t) => t.address === original.terminal && t.labels?.["migrated.tool"] === "1")) run("terminal.kill", { terminal: original.terminal });
        else throw new Error("Focus a normal tab before closing it; composition terminals do not own the underlying tab");
      } else run("tab.close", { id: original.tab, confirmed: true });
      return;
    }
    if (command === "close-space") { run("space.close", { id: original.space, confirmed: true }); return; }
    if (command === "close-pane") {
      if (original.pane) run("pane.close", { pane: original.pane });
      else if (terminals().some((t) => t.address === original.terminal && t.labels?.["migrated.tool"] === "1")) run("terminal.kill", { terminal: original.terminal });
      return;
    }
    if (command.startsWith("go-")) return this.navigate(command.slice(3), original, cx);
    if (command === "last-pane") {
      const previous = this.previous[original.tab];
      if (previous && panes().some((p) => p.pane === previous && p.tab === original.tab)) run("pane.focus", { pane: previous });
      return;
    }
    if (command === "rename-pane") {
      if (!original.pane) throw new Error("Focus a pane to rename it");
      openOverlay({ mod: "migrated-pane-name", kind: "dialog", width: 420, height: 190, props: { pane: original.pane } });
      return;
    }
    if (command === "break-pane") return this.breakPane(original, cx);
    if (command === "copy-mode" || command === "edit-scrollback") {
      if (!original.terminal) throw new Error("Focus a terminal to read its scrollback");
      openOverlay({ mod: "migrated-scrollback", kind: "dialog", width: 0.9, height: 0.9, props: { terminal: original.terminal, editable: command === "edit-scrollback" } });
      return;
    }
    if (command === "lazygit" || command === "jjui") return this.launch(command, [command], original, cx);
    if (command === "kim") {
      const machines = result(await hc(["machine", "ls", "--json"])).machines;
      if (!machines?.some((m) => m.name === "kim" && m.state === "connected" && !m.temporary)) throw new Error("Kim is not an existing connected core machine; no remote setup was changed");
      const existing = spaces().find((s) => s.machine === "kim");
      if (existing) run("space.select", { id: existing.id });
      else run("space.new", { name: "kim", machine: "kim" });
      return;
    }
    if (!this.paths) throw new Error(this.error || "Migration backends are still initializing");
    if (command === "refresh") return this.refresh(cx);
    if (["jj-create", "jj-open", "jj-cleanup"].includes(command)) {
      if (original.machine) throw new Error("JJ workspace management is local-only in this port. Remote support needs a backend and an authenticated bridge to this GUI; no remote setup or data was changed.");
      if (!original.cwd) throw new Error("Focus a repository terminal first");
      return this.launch(command.replace("jj-", "JJ / Git · "), ["env", `HERDR_BIN_PATH=${this.paths.bridge}`, `HERDR_PLUGIN_CONFIG_DIR=${this.paths.jj}`, "herdr-jj", "pane", command.slice(3), "--repo", original.cwd, "--state-dir", this.paths.jjState], original, cx);
    }
    if (command === "annotate-capture") {
      if (original.pane) run("terminal.copy");
      else notify({ title: "Annotating the clipboard", body: "For tool popups, copy the selection before invoking capture. The overlay selection API cannot be targeted directly." });
      await cx.sleep(0);
      const current = target();
      if (current.pane !== original.pane || current.terminal !== original.terminal) throw new Error("Focus changed while copying; capture again from the original terminal");
      const selectedText = cx.read_from_clipboard();
      if (!selectedText?.trim()) throw new Error("Select terminal text or copy it to the clipboard before annotating");
      const space = spaces().find((s) => s.id === original.space);
      const tab = space?.tabs.find((t) => t.id === original.tab);
      const context = { workspace_id: original.space, workspace_label: space?.name, tab_id: original.tab, tab_label: tab?.name, focused_pane_id: original.pane, focused_pane_cwd: original.cwd };
      const pending = `${this.paths.requests}/pending-${Date.now()}-${Math.random().toString(36).slice(2)}.json`;
      await writeTextFile(pending, JSON.stringify({ selectedText, context, capturedAt: new Date().toISOString() }), null);
      result(await exec("chmod", ["600", pending]));
      return this.launch("Annotate selection / clipboard", ["env", `HERDR_PLUGIN_STATE_DIR=${this.paths.annotations}`, `HERDR_ANNOTATE_PENDING=${pending}`, "bun", `${this.paths.annotate}/src/editor.ts`], original, cx, true);
    }
    if (command === "annotate-manage") return this.launch("Annotations", ["env", `HERDR_PLUGIN_STATE_DIR=${this.paths.annotations}`, "bun", `${this.paths.annotate}/src/manager.ts`], original, cx, true);
    if (command === "annotate-copy") {
      const context = result(await exec("bun", [backend(), "annotation-context"]));
      if (context.count) cx.write_to_clipboard(context.text);
      notify({ title: context.count ? "Annotations copied" : "No annotations", body: `${context.count} annotation(s) available.` });
      return;
    }
    if (command === "annotate-open" || command === "annotate-last") return this.launch(command === "annotate-open" ? "Review documents" : "Review agent reply / focused output", ["bun", backend(), "review", command === "annotate-open" ? "documents" : "last", JSON.stringify(original)], original, cx, true);
    throw new Error(`No migrated action: ${command}`);
  }

  render() {
    const f = focused();
    if (f?.pane && this.current[f.tab] !== f.pane) {
      this.previous[f.tab] = this.current[f.tab];
      this.current[f.tab] = f.pane;
    }
    const t = theme();
    const toolStack = shared("migrated.tool-stack");
    const hasTools = Array.isArray(toolStack) && toolStack.length > 0;
    return h_flex().id("migrated-tools").size_full().items_center().justify_end().gap(8).px(10).text_size(10.5)
      .child(div().text_color(this.error ? t.blocked : t.dim).child(this.error ? "Tools: setup needs attention" : hasTools ? "Tool popup" : "Ctrl-Space · tools"))
      .when(hasTools, el => el.child(div().id("migrated-tools-reset-stale").cursor_pointer().text_color(t.blocked).on_click(() => this.resetToolTracking()).child("Reset tools")))
      .when(Boolean(this.transfer), el => el.child(div().id("migrated-tools-recover").cursor_pointer().text_color(t.blocked).on_click(() => run("migrated-tools.recover-transfer")).child("Recover")))
      .child(div().id("migrated-tools-help").cursor_pointer().text_color(t.accent).on_click(() => run("mod.open", { name: "tmux-prefix" })).child("?"));
  }
}
