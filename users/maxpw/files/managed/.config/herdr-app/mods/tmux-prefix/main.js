import { View, div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { agents, closeOverlay, focused, notify, openOverlay, panes, props, run, shared, spaces, theme } from "herdr";

const BINDINGS = [
  ["?", "Prefix help", "help"],
  ["shift-s", "Settings", "app.settings"],
  ["d", "Detach window (terminals keep running)", "window.close"],
  ["r", "Config reloads automatically", "reload"],
  ["/", "Go to a tab, space or agent", "picker"],
  ["w", "Choose a space", "picker"],
  ["shift-n", "New space (ask for name)", "new-space"],
  ["shift-w", "Rename space", "space.rename"],
  ["shift-d", "Close space without confirmation", "space.close"],
  ["(", "Previous space", "space.prev"],
  [")", "Next space", "space.next"],
  ["alt-[", "Previous agent", "agent.prev"],
  ["alt-]", "Next agent", "agent.next"],
  ["c", "New tab (ask for name)", "new-tab"],
  ["p", "Previous tab", "tab.prev"],
  ["n", "Next tab", "tab.next"],
  [",", "Rename tab", "tab.rename"],
  ["&", "Close tab without confirmation", "tab.close"],
  ["|", "Split right", "split-right"],
  ["-", "Split down", "split-down"],
  ["x", "Close pane", "pane.close"],
  ["z", "Zoom pane", "pane.zoom"],
  ["h", "Focus left", "go-left"],
  ["j", "Focus down", "go-down"],
  ["k", "Focus up", "go-up"],
  ["l", "Focus right", "go-right"],
  ["tab", "Next pane", "cycle-next"],
  ["shift-tab", "Previous pane", "cycle-prev"],
  ["b", "Toggle sidebar", "sidebar"],
  ["[", "Copy scrollback snapshot", "migrated:copy-mode"],
  ["e", "Edit a scrollback snapshot", "migrated:edit-scrollback"],
  ["shift-p", "Rename pane", "migrated:rename-pane"],
  [";", "Last pane in this tab", "migrated:last-pane"],
  ["g", "lazygit popup", "migrated:lazygit"],
  ["shift-g", "jjui popup", "migrated:jjui"],
  ["shift-b", "Break pane into a new tab (keep program)", "migrated:break-pane"],
  ["alt-k", "Open / select Kim", "migrated:kim"],
  ["shift-t", "Create JJ / Git workspace", "migrated:jj-create"],
  ["t", "Open JJ / Git workspace", "migrated:jj-open"],
  ["alt-t", "Archive JJ workspace (never delete)", "migrated:jj-cleanup"],
  ["alt-r", "Refresh last-snapshot VCS status", "migrated:refresh"],
  ["a", "Annotate terminal selection / clipboard", "migrated:annotate-capture"],
  ["shift-a", "Copy saved annotations as context", "migrated:annotate-copy"],
  ["m", "Manage annotations / archives", "migrated:annotate-manage"],
  ["o", "Review documents in this folder", "migrated:annotate-open"],
  ["shift-o", "Review focused agent reply / output", "migrated:annotate-last"],
  ["shift-r", "Resize: needs an upstream pane-resize API", "blocked-resize"],
];

// Shift-7 (&) and Shift-9 (() already close tabs / select the previous space.
const SPACE_KEYS = { "!": 1, "@": 2, "#": 3, "$": 4, "%": 5, "^": 6, "*": 8 };
const SHIFTED = { "1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&", "8": "*", "9": "(", "0": ")", "/": "?", "\\": "|" };

function prefixChord(event) {
  const m = event.modifiers;
  const key = event.key.toLowerCase();
  if (m.control || m.platform || m.alt) return [m.control && "ctrl", m.platform && "cmd", m.alt && "alt", m.shift && "shift", key].filter(Boolean).join("-");
  if (m.shift && SHIFTED[key]) return SHIFTED[key];
  if (m.shift && /^[a-z]$/.test(key)) return `shift-${key}`;
  if (m.shift && key === "tab") return "shift-tab";
  return event.key_char && !/[\u0000-\u001f\u007f]/.test(event.key_char) ? event.key_char : key;
}

export default class TmuxPrefix extends View {
  init(_props, cx) {
    this.context = focused();
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  dismiss() {
    closeOverlay(props().overlay);
  }

  key(event, cx) {
    cx.stop_propagation();
    if (event.is_held) return;
    const chord = prefixChord(event);
    if (chord === "escape" || chord === "ctrl-space") return this.dismiss();
    const binding = BINDINGS.find(([key]) => key === chord);
    if (binding) return this.execute(binding[2]);
    if (SPACE_KEYS[chord]) return this.selectSpace(SPACE_KEYS[chord]);
    const match = /^alt-([1-9])$/.exec(chord);
    if (match) {
      const agent = agents()[Number(match[1]) - 1];
      this.dismiss();
      if (agent) run("agent.focus", { terminal: agent.address });
      return;
    }
    this.dismiss();
    notify({ title: "Prefix shortcut unavailable", body: `${chord}: no migrated action. See migration-notes.md in the Herdr App config folder.`, level: "warning" });
  }

  selectSpace(index) {
    const space = spaces()[index - 1];
    this.dismiss();
    if (space) run("space.select", { id: space.id });
  }

  execute(action) {
    if (action === "help") return;
    const f = this.context;
    const space = spaces().find((s) => s.id === f?.space);
    const structural = { "new-tab": "new-tab", "new-space": "new-space", "split-right": "split-right", "split-down": "split-down", "tab.close": "close-tab", "space.close": "close-space", "pane.close": "close-pane" }[action];
    if (structural && shared("layout") === "migrated") {
      this.dismiss();
      return void run(`migrated-tools.${structural}`);
    }
    if (action === "new-tab" || action === "new-space") {
      this.dismiss();
      // The old shell wrapper depends on HERDR_WORKSPACE_ID. Remote spaces
      // instead use their own core's shell; local prefix-created shells use Fish.
      const args = space?.machine ? { machine: space.machine } : { argv: ["fish", "--login"] };
      if (action === "new-tab") delete args.machine;
      if (action === "new-tab" && f?.space) args.space = f.space;
      if (f?.cwd) args.folder = f.cwd;
      openOverlay({ mod: "prompt", kind: "dialog", width: 420, props: {
        title: action === "new-tab" ? "New tab" : "New space",
        command: { name: action === "new-tab" ? "tab.new" : "space.new", args },
      } });
      return;
    }
    this.dismiss();
    if (action.startsWith("migrated:")) {
      if (shared("layout") !== "migrated") return void notify({ title: "Select the migrated layout", body: "The ported tools run in the personal migrated layout; switch to it in Settings or the layout picker.", level: "warning" });
      return void run(`migrated-tools.${action.slice(9)}`);
    }
    if (action === "blocked-resize") return void notify({ title: "Pane resizing needs an upstream API", body: "This App version has no pane-resize command. The shared core layout document was not modified directly.", level: "warning" });
    if (action === "reload") return void notify({ title: "Config reloads automatically", body: "Save keys, settings or mods to apply changes. No restart needed." });
    if (action === "picker") return void run("mod.open", { name: "picker" });
    if (action === "sidebar") return void run("layout.toggle", { id: "sidebar" });
    if (action === "space.rename" || action === "space.close") {
      if (f?.space) run(action, { id: f.space, ...(action === "space.close" ? { confirmed: true } : {}) });
      return;
    }
    if (action === "tab.rename" || action === "tab.close") {
      if (f?.tab) run(action, { id: f.tab, ...(action === "tab.close" ? { confirmed: true } : {}) });
      return;
    }
    if (action.startsWith("split-")) {
      if (f?.pane) run("pane.split", { pane: f.pane, direction: action.slice(6), ...(space?.machine ? {} : { argv: ["fish", "--login"] }) });
      return;
    }
    if (action === "pane.close" || action === "pane.zoom") {
      if (f?.pane) run(action, { pane: f.pane });
      return;
    }
    if (action.startsWith("cycle-")) {
      const list = panes().filter((p) => p.tab === f?.tab);
      const at = list.findIndex((p) => p.pane === f?.pane);
      if (at >= 0) run("pane.focus", { pane: list[(at + (action === "cycle-next" ? 1 : list.length - 1)) % list.length].pane });
      return;
    }
    if (action.startsWith("go-")) {
      if (f?.pane) run("pane.go", { direction: action.slice(3) });
      return;
    }
    run(action);
  }

  render() {
    const t = theme();
    const row = (key, label) => h_flex().gap(14).py(3)
      .child(div().w(90).flex_none().text_color(t.accent).child(key))
      .child(div().text_color(t.foreground).child(label));
    return v_flex().id("tmux-prefix").track_focus(this.handle)
      .on_key_down((event, cx) => this.key(event, cx))
      .size_full().min_h(0).p(18).gap(10).bg(t.popover).text_size(12)
      .child(h_flex().justify_between().items_center()
        .child(div().text_size(16).font_semibold().text_color(t.foreground).child("Ctrl-Space"))
        .child(div().text_color(t.dim).child("Esc to cancel")))
      .child(div().text_color(t.muted).child("Release the prefix, then press a key. Shift-letter = uppercase."))
      .child(v_flex().flex_1().min_h(0).overflow_y_scrollbar()
        .children(BINDINGS.map(([key, label]) => row(key, label)))
        .child(row("Shift 1–6,8", "Select space; use native Ctrl-7 / Ctrl-9 for the conflicts"))
        .child(row("Alt 1–9", "Focus agent")))
      .child(div().text_color(t.dim).child("Ported tools run in the migrated layout. Three-cell resizing still needs an upstream API. Alt-1…9 selects tabs."));
  }
}
