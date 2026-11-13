import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import vm from "node:vm";

const source = await readFile(new URL("./main.js", import.meta.url), "utf8");
const plain = (value) => JSON.parse(JSON.stringify(value));

async function setup({ remote = false, layout = "main", focus = { space: "s1", tab: "tab1", pane: "p1", cwd: "/work" } } = {}) {
  const calls = [];
  const context = vm.createContext({});
  const record = (name) => (...args) => calls.push([name, ...plain(args)]);
  const modules = {
    "gpui-kit": { View: class {}, div() {} },
    "gpui-base": { h_flex() {}, v_flex() {} },
    herdr: {
      agents: () => [{ address: "t1" }, { address: "kim/t2" }],
      closeOverlay: record("close"),
      focused: () => focus,
      notify: record("notify"),
      openOverlay: record("open"),
      panes: () => [{ pane: "p1", tab: "tab1" }, { pane: "other", tab: "tab2" }, { pane: "p2", tab: "tab1" }],
      props: () => ({ overlay: "overlay-test" }),
      run: record("run"),
      shared: () => layout,
      spaces: () => Array.from({ length: 9 }, (_, i) => ({ id: `s${i + 1}`, machine: remote ? "kim" : null })),
      theme: () => ({}),
    },
  };
  const mod = new vm.SourceTextModule(source, { context });
  await mod.link((name) => {
    const exports = modules[name];
    return new vm.SyntheticModule(Object.keys(exports), function () {
      for (const [key, value] of Object.entries(exports)) this.setExport(key, value);
    }, { context });
  });
  await mod.evaluate();
  const instance = new mod.namespace.default();
  instance.init({}, { focus_handle: () => ({ focus: record("focus") }) });
  calls.length = 0;
  function press(key, modifiers = {}, extra = {}) {
    instance.key({ key, modifiers: { control: false, platform: false, alt: false, shift: false, ...modifiers }, ...extra }, { stop_propagation() {} });
  }
  return { calls, press };
}

for (const [key, command, args] of [
  ["h", "pane.go", { direction: "left" }],
  ["j", "pane.go", { direction: "down" }],
  ["k", "pane.go", { direction: "up" }],
  ["l", "pane.go", { direction: "right" }],
  ["|", "pane.split", { pane: "p1", direction: "right", argv: ["fish", "--login"] }],
  ["-", "pane.split", { pane: "p1", direction: "down", argv: ["fish", "--login"] }],
  ["x", "pane.close", { pane: "p1" }],
  ["z", "pane.zoom", { pane: "p1" }],
  [",", "tab.rename", { id: "tab1" }],
  ["&", "tab.close", { id: "tab1", confirmed: true }],
]) {
  test(`prefix ${key} targets the original pane/tab`, async () => {
    const { calls, press } = await setup();
    press(key);
    assert.deepEqual(calls, [["close", "overlay-test"], ["run", command, args]]);
  });
}

for (const [key, command] of [["n", "tab.next"], ["p", "tab.prev"], ["(", "space.prev"], [")", "space.next"], ["d", "window.close"]]) {
  test(`prefix ${key} dispatches ${command}`, async () => {
    const { calls, press } = await setup();
    press(key);
    assert.deepEqual(calls, [["close", "overlay-test"], ["run", command]]);
  });
}

test("shifted physical keys preserve symbols and resolve inherited collisions", async () => {
  for (const [key, command] of [["7", "tab.close"], ["9", "space.prev"], ["0", "space.next"], ["\\", "pane.split"]]) {
    const { calls, press } = await setup();
    press(key, { shift: true });
    assert.equal(calls[1][1], command);
  }
  const { calls, press } = await setup();
  press("2", { shift: true });
  assert.deepEqual(calls[1], ["run", "space.select", { id: "s2" }]);
});

test("space and tab renames remain interactive; close-space suppresses confirmation", async () => {
  const { calls, press } = await setup();
  press("W", { shift: true });
  assert.deepEqual(calls[1], ["run", "space.rename", { id: "s1" }]);
  calls.length = 0;
  press("d", { shift: true });
  assert.deepEqual(calls[1], ["run", "space.close", { id: "s1", confirmed: true }]);
});

test("new local tabs ask for a name, follow cwd, and use Fish", async () => {
  const { calls, press } = await setup();
  press("c");
  assert.equal(calls[1][0], "open");
  assert.deepEqual(calls[1][1].props.command, { name: "tab.new", args: { argv: ["fish", "--login"], space: "s1", folder: "/work" } });
});

test("remote tabs and splits use the remote core's shell, not local Fish", async () => {
  const { calls, press } = await setup({ remote: true });
  press("c");
  assert.deepEqual(calls[1][1].props.command, { name: "tab.new", args: { space: "s1", folder: "/work" } });
  calls.length = 0;
  press("|");
  assert.deepEqual(calls[1], ["run", "pane.split", { pane: "p1", direction: "right" }]);
});

test("new remote spaces retain the machine and ask for a name", async () => {
  const { calls, press } = await setup({ remote: true });
  press("n", { shift: true });
  assert.deepEqual(calls[1][1].props.command, { name: "space.new", args: { machine: "kim", folder: "/work" } });
});

test("pane cycles wrap and never enter another tab", async () => {
  const { calls, press } = await setup({ focus: { space: "s1", tab: "tab1", pane: "p2" } });
  press("tab");
  assert.deepEqual(calls[1], ["run", "pane.focus", { pane: "p1" }]);
  calls.length = 0;
  press("tab", { shift: true });
  assert.deepEqual(calls[1], ["run", "pane.focus", { pane: "p1" }]);
});

test("tab key remains a named key even when its control character is supplied", async () => {
  const { calls, press } = await setup();
  press("tab", {}, { key_char: "\t" });
  assert.deepEqual(calls[1], ["run", "pane.focus", { pane: "p2" }]);
});

test("agent selection uses terminal addresses, including remote addresses", async () => {
  const { calls, press } = await setup();
  press("2", { alt: true });
  assert.deepEqual(calls[1], ["run", "agent.focus", { terminal: "kim/t2" }]);
  calls.length = 0;
  press("9", { alt: true });
  assert.deepEqual(calls, [["close", "overlay-test"]]);
});

test("no focused pane does not close, split, navigate, or zoom an arbitrary pane", async () => {
  for (const key of ["x", "z", "h", "|", "tab", ",", "&"]) {
    const { calls, press } = await setup({ focus: null });
    press(key);
    assert.deepEqual(calls, [["close", "overlay-test"]]);
  }
});

test("unbound chords warn instead of invoking arbitrary commands", async () => {
  const { calls, press } = await setup();
  press("f");
  assert.equal(calls[1][0], "notify");
  assert.equal(calls[1][1].level, "warning");
});

for (const [key, modifiers, action] of [
  ["t", {}, "jj-open"], ["t", { shift: true }, "jj-create"], ["t", { alt: true }, "jj-cleanup"],
  ["r", { alt: true }, "refresh"], ["g", {}, "lazygit"], ["g", { shift: true }, "jjui"],
  ["[", {}, "copy-mode"], ["e", {}, "edit-scrollback"], ["p", { shift: true }, "rename-pane"],
  [";", {}, "last-pane"], ["b", { shift: true }, "break-pane"], ["k", { alt: true }, "kim"],
  ["a", {}, "annotate-capture"], ["a", { shift: true }, "annotate-copy"], ["m", {}, "annotate-manage"],
  ["o", {}, "annotate-open"], ["o", { shift: true }, "annotate-last"],
]) {
  test(`ported prefix action ${action} reaches the resident controller`, async () => {
    const { calls, press } = await setup({ layout: "migrated" });
    press(key, modifiers);
    assert.deepEqual(calls, [["close", "overlay-test"], ["run", `migrated-tools.${action}`]]);
  });
}

test("migrated layout routes structural prefix actions through the serialized controller", async () => {
  const { calls, press } = await setup({ layout: "migrated" });
  press("&");
  assert.deepEqual(calls, [["close", "overlay-test"], ["run", "migrated-tools.close-tab"]]);
});

test("resize stays explicitly blocked without writing core layout documents", async () => {
  const { calls, press } = await setup();
  press("r", { shift: true });
  assert.equal(calls[1][0], "notify");
  assert.equal(calls[1][1].title, "Pane resizing needs an upstream API");
});

test("escape and repeated prefix cancel; held keys and help do not act", async () => {
  for (const [key, modifiers] of [["escape", {}], ["space", { control: true }]]) {
    const { calls, press } = await setup();
    press(key, modifiers);
    assert.deepEqual(calls, [["close", "overlay-test"]]);
  }
  const { calls, press } = await setup();
  press("x", {}, { is_held: true });
  press("?");
  assert.deepEqual(calls, []);
});
