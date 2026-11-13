import { View, div } from "gpui-kit";
import { Editor, EditorState, h_flex, v_flex } from "gpui-base";
import { closeOverlay, hc, props, settings, theme } from "herdr";

export default class Scrollback extends View {
  init(_props, cx) {
    this.loading = true;
    this.message = "Loading terminal output…";
    this.editor = EditorState.new({ value: "", readonly: !props()?.editable, language: "text", font_family: settings().font_family, folding: false });
    this.handle = cx.focus_handle();
    cx.spawn(async (cx) => {
      try {
        if (typeof props()?.terminal !== "string") throw new Error("No terminal was supplied");
        const r = await hc(["read", props().terminal, "--lines", "20000", "--json"]);
        if (r.code !== 0) throw new Error(r.stderr?.trim() || "Core could not read this terminal");
        const snapshot = JSON.parse(r.stdout);
        if (typeof snapshot.text !== "string") throw new Error("Core returned no terminal text");
        this.editor.set_value(snapshot.text);
        this.message = snapshot.complete ? "Snapshot only. Select text and copy normally, or Copy all. Nothing is sent back to the terminal." : "Partial snapshot: this running full-screen program did not expose all of its history.";
      } catch (error) { this.message = error.message; }
      this.loading = false;
      cx.notify();
    });
  }

  render() {
    const t = theme();
    const p = props() ?? {};
    return v_flex().id("migrated-scrollback").track_focus(this.handle).size_full().min_h(0).p(16).gap(12).bg(t.popover).text_size(12).text_color(t.foreground)
      .on_key_down((event, cx) => { if (event.key === "escape") { cx.stop_propagation(); closeOverlay(p.overlay); } })
      .child(h_flex().gap(14).items_center()
        .child(div().flex_1().font_semibold().text_size(15).child(`${p.editable ? "Edit" : "Copy"} scrollback · ${p.terminal || ""}`))
        .child(div().id("scrollback-copy").cursor_pointer().text_color(t.accent).on_click((_e, cx) => cx.write_to_clipboard(this.editor.value())).child("Copy all"))
        .child(div().id("scrollback-close").cursor_pointer().on_click(() => closeOverlay(p.overlay)).child("Close ×")))
      .child(div().text_color(t.muted).child(this.message))
      .child(Editor.new(this.editor).flex_1().min_h(0).border_1().border_color(t.border).rounded(7));
  }
}
