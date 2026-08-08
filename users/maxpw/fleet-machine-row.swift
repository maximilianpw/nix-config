Button(action: { cmux("workspace.create", title: @NAME@, initial_command: @COMMAND@, focus: true) }) {
  HStack(alignment: .top, spacing: 8) {
    Rectangle()
      .fill(@ACCENT@)
      .frame(width: 4, height: 48)
      .cornerRadius(2)

    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        Image(systemName: @ICON@)
          .foregroundColor(@ACCENT@)
        Text(@NAME@)
          .font(.headline)
          .lineLimit(1)
        Spacer()
        Text("tmux")
          .font(.caption)
          .foregroundColor(@ACCENT@)
      }

      Text(@ROLE_LABEL@)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)

      Text(@FLEET_COMMAND@)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
  }
  .padding(6)
  .cornerRadius(8)
}
