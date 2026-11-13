import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { appHome, closeOverlay, exec, props, run, setShared, shared, terminals, theme } from "herdr";

export default class MigratedTerminal extends View {
  init() {
    const p = props();
    if (p?.owned === true && typeof p.terminal === "string" && typeof p.overlay === "string") {
      const stack = Array.isArray(shared("migrated.tool-stack")) ? shared("migrated.tool-stack") : [];
      setShared("migrated.tool-stack", [...stack.filter((t) => t.terminal !== p.terminal), { terminal: p.terminal, overlay: p.overlay }]);
    }
  }

  async close() {
    const p = props();
    if (p?.owned !== true || typeof p.terminal !== "string") return;
    const stack = Array.isArray(shared("migrated.tool-stack")) ? shared("migrated.tool-stack") : [];
    if (stack.some((t) => t.terminal === p.terminal)) setShared("migrated.tool-stack", stack.filter((t) => t.terminal !== p.terminal));
    // Queue the exact kill before the 250 ms close budget expires, including quit.
    const tool = terminals().find((t) => t.address === p.terminal);
    if (tool && tool.labels?.["migrated.tool"] !== "1") return;
    if (tool?.state === "live") run("terminal.kill", { terminal: p.terminal });
    if (/^t[a-z0-9]+$/.test(p.terminal)) await exec("bun", [`${appHome()}/mods/migrated-tools/backend/tools.mjs`, "cleanup-tool", p.terminal]);
  }

  render() {
    const t = theme();
    const p = props() ?? {};
    return h_flex().id("migrated-terminal").size_full().px(12).gap(10).items_center().bg(t.chrome).text_size(12)
      .child(div().text_color(t.foreground).font_semibold().child(p.title || "Terminal tool"))
      .child(div().flex_1().truncate().text_color(t.dim).child(p.terminal || ""))
      .child(div().text_color(t.dim).text_size(10.5).child("Closing ends this tool only"))
      .child(div().id("migrated-terminal-close").px(8).py(3).rounded(5).cursor_pointer().text_color(t.foreground)
        .hover((s) => s.bg(t.hover)).on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click((_e, cx) => { cx.stop_propagation(); closeOverlay(p.overlay); }).child("Close ×"));
  }
}
