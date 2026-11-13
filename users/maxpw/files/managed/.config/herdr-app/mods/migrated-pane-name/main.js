import { View, div } from "gpui-kit";
import { h_flex, v_flex, Input, InputState } from "gpui-base";
import { closeOverlay, panes, props, setShared, shared, theme } from "herdr";

export default class PaneName extends View {
  init(_props, cx) {
    this.input = InputState.new({ value: shared("migrated.pane-names")?.[props()?.pane] || "", placeholder: "Pane name (empty restores the program title)" });
    this.input.on("submit", () => this.save());
    this.handle = cx.focus_handle();
    this.input.focus();
  }

  save() {
    const pane = props().pane;
    if (panes().some((p) => p.pane === pane)) {
      const live = new Set(panes().map((p) => p.pane));
      const names = Object.fromEntries(Object.entries(shared("migrated.pane-names") || {}).filter(([id]) => live.has(id)));
      const value = this.input.value().trim().replace(/[\u0000-\u001f\u007f]/g, "").slice(0, 120);
      if (value) names[pane] = value;
      else delete names[pane];
      setShared("migrated.pane-names", names);
    }
    closeOverlay(props().overlay);
  }

  render() {
    const t = theme();
    return v_flex().id("migrated-pane-name").track_focus(this.handle).p(18).gap(14).size_full().bg(t.popover).text_color(t.foreground).text_size(12)
      .on_key_down((e, cx) => { if (e.key === "escape") { cx.stop_propagation(); closeOverlay(props().overlay); } })
      .child(div().text_size(15).font_semibold().child("Rename pane"))
      .child(Input.new(this.input).h(36).px(10).rounded(7).bg(t.background).border_1().border_color(t.accent))
      .child(h_flex().justify_end().gap(12)
        .child(div().id("pane-name-cancel").cursor_pointer().on_click(() => closeOverlay(props().overlay)).child("Cancel"))
        .child(div().id("pane-name-save").cursor_pointer().text_color(t.accent).on_click(() => this.save()).child("Save")));
  }
}
