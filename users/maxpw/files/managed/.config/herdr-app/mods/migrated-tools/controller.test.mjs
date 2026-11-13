import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import vm from "node:vm";

const plain = (value) => JSON.parse(JSON.stringify(value));
const appHome = "/fixture/herdr-app";
const paths = { bridge: "/fixture/bridge", jj: "/fixture/jj", jjState: "/fixture/jj/state", annotate: "/fixture/annotate", annotations: "/fixture/annotations", requests: "/fixture/requests" };

function element() {
  const builder = new Proxy({}, { get: (_target, name) => name === "when" ? (condition, apply) => condition ? apply(builder) : builder : () => builder });
  return builder;
}

async function load(name = "migrated-tools", options = {}) {
  const state = {
    calls: [],
    tasks: [],
    focus: { space: "s1", tab: "tab1", pane: "p1", terminal: "t1", shown: null, cwd: "/repo" },
    spaces: [{ id: "s1", machine: null, name: "fixture", tabs: [{ id: "tab1", name: "tab" }] }],
    panes: [{ pane: "p1", terminal: "t1", tab: "tab1" }, { pane: "p2", terminal: "t2", tab: "tab1" }],
    terminals: [{ address: "t1", state: "live", foreground: { pid: 123, name: "fish" } }],
    shared: {},
    props: {},
    clipboard: "selected fixture text",
    ...options,
  };
  const record = (name) => (...args) => { state.calls.push([name, ...plain(args)]); };
  const herdr = {
    appHome: () => appHome,
    closeOverlay: record("close"),
    focused: () => state.focus,
    exec: async (...args) => { record("exec")(...args); return { code: 0, stdout: "{}" }; },
    hc: async (args) => { record("hc")(args); return state.hc ? state.hc(args) : { code: 0, stdout: JSON.stringify(args[0] === "run" ? { address: "t-tool", state: "live" } : {}) }; },
    nextCommand: () => state.nextCommand ? state.nextCommand() : new Promise(() => {}),
    notify: record("notify"),
    openOverlay: (...args) => { record("open")(...args); return "o1"; },
    panes: () => state.panes,
    readTextFile: async () => null,
    run: (...args) => { record("run")(...args); state.onRun?.(...args); },
    setShared: (key, value) => { state.shared[key] = plain(value); record("shared")(key, value); },
    shared: (key) => state.shared[key],
    spaces: () => state.spaces,
    terminals: () => state.terminals,
    theme: () => ({}),
    settings: () => ({ font_family: "mono" }),
    writeTextFile: async (...args) => record("write")(...args),
    props: () => state.props,
  };
  const input = { value: () => state.inputValue ?? "", on() {}, focus() {} };
  const modules = {
    "herdr": herdr,
    "gpui-kit": { View: class {}, div: element },
    "gpui-base": { h_flex: element, v_flex: element, Input: { new: element }, InputState: { new: () => input }, Editor: { new: element }, EditorState: { new: () => ({ value: () => "", set_value() {} }) } },
  };
  const context = vm.createContext({});
  const source = await readFile(new URL(`../${name}/main.js`, import.meta.url), "utf8");
  const mod = new vm.SourceTextModule(source, { context });
  await mod.link((name) => {
    const exports = modules[name];
    return new vm.SyntheticModule(Object.keys(exports), function () { for (const [key, value] of Object.entries(exports)) this.setExport(key, value); }, { context });
  });
  await mod.evaluate();
  const instance = new mod.namespace.default();
  const cx = { spawn: (body) => state.tasks.push(body), timer: { every() {}, after() {} }, sleep: async () => state.onSleep?.(), notify() {}, focus_handle: () => ({ focus() {} }), read_from_clipboard: () => state.clipboard, write_to_clipboard: record("clipboard") };
  instance.init?.({}, cx);
  if (name === "migrated-tools") instance.paths = paths;
  return { instance, state, cx, original: () => ({ ...state.focus, machine: state.spaces.find((s) => s.id === state.focus?.space)?.machine || null }) };
}

test("popup launch uses flat hc JSON and creates only an owned composition terminal", async () => {
  const { instance, state, cx, original } = await load();
  await instance.act("lazygit", original(), cx);
  const args = state.calls.find(([name]) => name === "hc")[1];
  assert.ok(args.includes("--no-parent"));
  assert.ok(args.includes("--rm"));
  assert.ok(!args.some((arg) => arg.startsWith("herdr.space=")));
  const overlay = state.calls.find(([name]) => name === "open")[1];
  assert.equal(overlay.layout.children[1].content.terminal, "t-tool");
  assert.deepEqual(overlay.layout.children[0].content.props, { terminal: "t-tool", title: "lazygit", owned: true });
  assert.equal(overlay.kind, "dialog");
  assert.equal(overlay.modal, true);
  assert.equal(state.calls.some(([name, command]) => name === "run" && command === "pane.focus"), false);
});

test("commands from an owned popup target its terminal, never the stale underlying focused() pane", async () => {
  let calls = 0;
  const { state, cx } = await load("migrated-tools", {
    shared: { "migrated.tool-stack": [{ terminal: "t7", overlay: "o1" }] },
    terminals: [{ address: "t7", state: "live", cwd: "/tool", labels: { "migrated.tool": "1" } }],
    nextCommand: () => ++calls === 1 ? Promise.resolve("close-tab") : Promise.reject(new Error("fixture stream ended")),
  });
  await assert.rejects(state.tasks[1](cx), /fixture stream ended/);
  await state.tasks[2](cx);
  assert.deepEqual(state.calls, [["run", "terminal.kill", { terminal: "t7" }]]);
});

test("stale popup metadata cannot fall back to closing an unrelated user tab", async () => {
  let calls = 0;
  const { state, cx } = await load("migrated-tools", {
    shared: { "migrated.tool-stack": [{ terminal: "t7", overlay: "o1" }] },
    nextCommand: () => ++calls === 1 ? Promise.resolve("close-tab") : Promise.reject(new Error("fixture stream ended")),
  });
  await assert.rejects(state.tasks[1](cx), /fixture stream ended/);
  assert.equal(state.calls.some(([name]) => name === "run"), false);
  assert.ok(state.calls.some(([name, message]) => name === "notify" && message.body.includes("tool popup")));
});

test("remote terminal tools run on the pinned machine and remote cwd", async () => {
  const { instance, state, cx, original } = await load();
  state.spaces[0].machine = "kim";
  state.focus.cwd = "/srv/project";
  await instance.act("jjui", original(), cx);
  const args = state.calls.find(([name]) => name === "hc")[1];
  assert.equal(args[args.indexOf("--on") + 1], "kim");
  assert.equal(args[args.indexOf("--cwd") + 1], "/srv/project");
});

for (const command of ["new-tab", "new-space"]) {
  test(`${command} asks for a name and follows the current directory`, async () => {
    const { instance, state, cx, original } = await load();
    await instance.act(command, original(), cx);
    const prompt = state.calls[0][1];
    assert.equal(prompt.mod, "prompt");
    assert.equal(prompt.props.command.args.folder, "/repo");
    assert.deepEqual(prompt.props.command.args.argv, ["fish", "--login"]);
  });
}

test("remote workspace operations fail instead of executing local repo commands", async () => {
  const { instance, state, cx, original } = await load();
  state.spaces[0].machine = "kim";
  await assert.rejects(instance.act("jj-cleanup", original(), cx), /local-only in this port/);
  assert.deepEqual(state.calls, []);
});

test("JJ popup retains the original backend, scoped adapter and copied journals", async () => {
  const { instance, state, cx, original } = await load();
  await instance.act("jj-cleanup", original(), cx);
  const args = state.calls.find(([name]) => name === "hc")[1];
  assert.ok(args.includes("HERDR_BIN_PATH=/fixture/bridge"));
  assert.ok(args.includes("herdr-jj"));
  assert.equal(args[args.indexOf("--repo") + 1], "/repo");
  assert.equal(args[args.indexOf("--state-dir") + 1], "/fixture/jj/state");
  assert.ok(args.includes("cleanup"));
});

test("capture writes clipboard text privately, not into process argv", async () => {
  const { instance, state, cx, original } = await load();
  await instance.act("annotate-capture", original(), cx);
  const write = state.calls.find(([name]) => name === "write");
  assert.ok(write[1].startsWith("/fixture/requests/pending-"));
  assert.equal(JSON.parse(write[2]).selectedText, state.clipboard);
  const args = state.calls.find(([name]) => name === "hc")[1];
  assert.ok(!args.join(" ").includes(state.clipboard));
  assert.ok(args.includes("/fixture/annotate/src/editor.ts"));
  assert.ok(!args.includes("--on"));
});

test("break-pane waits for park, then keeps the same program as a tab", async () => {
  const { instance, state, cx, original } = await load();
  state.onSleep = () => { state.panes = state.panes.filter((p) => p.pane !== "p1"); };
  state.onRun = (name) => { if (name === "terminal.keep") state.panes.push({ pane: "p-new", terminal: "t1", tab: "new-tab" }); };
  await instance.act("break-pane", original(), cx);
  assert.deepEqual(state.calls, [
    ["shared", "migrated.transfer", { terminal: "t1", pane: "p1", space: "s1", tab: "tab1" }],
    ["run", "terminal.park", { terminal: "t1" }],
    ["run", "terminal.keep", { terminal: "t1", place: "tab" }],
    ["shared", "migrated.transfer", null],
  ]);
  assert.equal(instance.transfer, null);
});

test("break-pane never operates on a last pane or a replaced terminal", async () => {
  const { instance, state, cx, original } = await load();
  state.panes = [state.panes[0]];
  await assert.rejects(instance.act("break-pane", original(), cx), /already has its own tab/);
  state.focus.shown = "t-other";
  await assert.rejects(instance.act("break-pane", original(), cx), /not a replacement/);
  assert.deepEqual(state.calls, []);
});

test("parked terminals remain running if the person changes spaces before keep", async () => {
  const { instance, state, cx, original } = await load();
  const pinned = original();
  state.onSleep = () => { state.panes = []; state.focus.space = "another-space"; };
  await assert.rejects(instance.act("break-pane", pinned, cx), /still running/);
  assert.deepEqual(state.calls, [
    ["shared", "migrated.transfer", { terminal: "t1", pane: "p1", space: "s1", tab: "tab1" }],
    ["run", "terminal.park", { terminal: "t1" }],
    ["hc", ["keep", "t1", "--json"]],
  ]);
  assert.equal(instance.transfer.terminal, "t1");
});

test("commands cannot close another pane's tab while break-pane is in flight", async () => {
  const { instance, state, cx, original } = await load();
  const tasks = [];
  let release;
  cx.spawn = (body) => tasks.push(body);
  state.onSleep = () => new Promise((resolve) => { release = () => { state.panes = state.panes.filter((p) => p.pane !== "p1"); resolve(); }; });
  state.onRun = (name) => { if (name === "terminal.keep") state.panes.push({ pane: "p-new", terminal: "t1", tab: "new-tab" }); };
  const pinned = original();
  instance.requests.push({ command: "break-pane", pinned });
  instance.drain(cx);
  const work = tasks[0](cx);
  instance.requests.push({ command: "close-tab", pinned });
  assert.equal(state.calls.some(([name, command]) => name === "run" && command === "tab.close"), false);
  release();
  await work;
  assert.equal(state.calls.some(([name, command]) => name === "run" && command === "tab.close"), false);
  assert.ok(state.calls.some(([name, n]) => name === "notify" && n.body.includes("original pane moved or closed")));
});

test("closing a focused tool never closes the underlying user tab", async () => {
  const { instance, state, cx, original } = await load();
  state.focus.pane = null;
  state.terminals[0].labels = { "migrated.tool": "1" };
  await instance.act("close-tab", original(), cx);
  assert.deepEqual(state.calls, [["run", "terminal.kill", { terminal: "t1" }]]);
});

test("layout close preserves an interrupted transfer without killing it", async () => {
  const { instance, state } = await load();
  instance.transfer = { terminal: "t1", pane: "p1", space: "s1", tab: "tab1" };
  await instance.close();
  assert.deepEqual(state.calls, [["exec", "hc", ["keep", "t1", "--json"]]]);
});

test("resetting stale popup tracking never kills or replays a program", async () => {
  const { instance, state } = await load();
  state.shared["migrated.tool-stack"] = [{ terminal: "t-old", overlay: "old-overlay" }];
  instance.resetToolTracking();
  assert.deepEqual(state.shared["migrated.tool-stack"], []);
  assert.equal(state.calls.some(([name]) => name === "run" || name === "hc"), false);
});

test("last-pane tracks focus per tab rather than selecting another tab's pane", async () => {
  const { instance, state, cx, original } = await load();
  instance.render();
  state.focus.pane = "p2";
  instance.render();
  await instance.act("last-pane", original(), cx);
  assert.deepEqual(state.calls, [["run", "pane.focus", { pane: "p1" }]]);
});

test("pane alias saves sanitize control characters and preserve live other names", async () => {
  const { instance, state } = await load("migrated-pane-name", { props: { pane: "p1", overlay: "o1" }, inputValue: "  fixture\u001b name  ", shared: { "migrated.pane-names": { p2: "other", vanished: "stale" } } });
  instance.save();
  assert.deepEqual(state.shared["migrated.pane-names"], { p1: "fixture name", p2: "other" });
  assert.deepEqual(state.calls.at(-1), ["close", "o1"]);
});

test("a disappeared pane cannot be renamed accidentally", async () => {
  const { instance, state } = await load("migrated-pane-name", { props: { pane: "missing", overlay: "o1" }, inputValue: "name" });
  instance.save();
  assert.deepEqual(state.calls, [["close", "o1"]]);
});

test("tool header registers an exact overlay id and removes it on close", async () => {
  const { instance, state } = await load("migrated-terminal", { props: { terminal: "t7", owned: true, overlay: "owned-overlay" }, terminals: [{ address: "t7", state: "finished", labels: { "migrated.tool": "1" } }] });
  assert.deepEqual(state.shared["migrated.tool-stack"], [{ terminal: "t7", overlay: "owned-overlay" }]);
  await instance.close();
  assert.deepEqual(state.shared["migrated.tool-stack"], []);
});

for (const [label, props, live, kills] of [
  ["owned live tool", { terminal: "tool", owned: true }, [{ address: "tool", state: "live", labels: { "migrated.tool": "1" } }], true],
  ["unowned user terminal", { terminal: "user", owned: false }, [{ address: "user", state: "live" }], false],
  ["already finished tool", { terminal: "tool", owned: true }, [{ address: "tool", state: "finished", labels: { "migrated.tool": "1" } }], false],
  ["ownership label mismatch", { terminal: "tool", owned: true }, [{ address: "tool", state: "live" }], false],
]) {
  test(`overlay close cleanup: ${label}`, async () => {
    const { instance, state } = await load("migrated-terminal", { props, terminals: live });
    await instance.close();
    const cleanup = props.owned && live[0]?.labels?.["migrated.tool"] === "1" ? [["exec", "bun", [`${appHome}/mods/migrated-tools/backend/tools.mjs`, "cleanup-tool", "tool"]]] : [];
    assert.deepEqual(state.calls, [...(kills ? [["run", "terminal.kill", { terminal: "tool" }]] : []), ...cleanup]);
  });
}
