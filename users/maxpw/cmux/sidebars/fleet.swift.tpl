VStack(alignment: .leading, spacing: 10) {
  HStack(spacing: 8) {
    Image(systemName: "network")
      .foregroundColor("#7DD3FC")
    Text("Fleet")
      .font(.headline)
      .bold()
    Spacer()
    if unreadTotal > 0 {
      Text(String(unreadTotal))
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor("#FFFFFF")
        .padding(5)
        .background("#0A84FF")
        .cornerRadius(10)
    }
  }

  Text(selectedTitle)
    .font(.caption)
    .foregroundColor(.secondary)
    .lineLimit(1)

  Divider()

  Section("Machines") {
    Button(action: { cmux("workspace.create", title: "main-pc", initial_command: "/bin/sh -lc 'exec /etc/profiles/per-user/$(/usr/bin/id -un)/bin/fleet ssh main-pc'", focus: true) }) {
      HStack(alignment: .top, spacing: 8) {
        Rectangle()
          .fill("#9ECE6A")
          .frame(width: 4, height: 48)
          .cornerRadius(2)

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Image(systemName: "server.rack")
              .foregroundColor("#9ECE6A")
            Text("main-pc")
              .font(.headline)
              .lineLimit(1)
            Spacer()
            Text("tmux")
              .font(.caption)
              .foregroundColor("#9ECE6A")
          }

          Text("NixOS homelab")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)

          Text("fleet ssh main-pc")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
      .padding(6)
      .cornerRadius(8)
    }
  }

  Divider()

  Section("SSH") {
    ForEach(workspaces) { w in
      if let remote = w.remote {
        Button(action: { cmux("workspace.select", workspace_id: w.id) }) {
          HStack(alignment: .top, spacing: 8) {
            Rectangle()
              .fill(remote.connected ? "#22C55E" : "#A3A3A3")
              .frame(width: 4, height: 46)
              .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Image(systemName: w.pinned ? "pin.fill" : "terminal")
                  .foregroundColor(w.selected ? "#FFFFFF" : .secondary)
                Text(w.title)
                  .font(.headline)
                  .lineLimit(1)
                Spacer()
                if w.unread > 0 {
                  Text(String(w.unread))
                    .font(.caption)
                    .foregroundColor("#FFFFFF")
                    .padding(4)
                    .background("#0A84FF")
                    .cornerRadius(8)
                }
              }

              Text(remote.target)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

              if let message = w.latestMessage {
                Text(message)
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .lineLimit(2)
              }
            }
          }
          .padding(6)
          .cornerRadius(8)
        }
      }
    }
  }

  Divider()

  Section("Active Workspaces") {
    Reorderable(workspaces, move: "workspace.reorder") { w in
      Button(action: { cmux("workspace.select", workspace_id: w.id) }) {
        HStack(alignment: .top, spacing: 8) {
          Rectangle()
            .fill(w.selected ? "#0A84FF" : "#71717A")
            .frame(width: 4, height: 46)
            .cornerRadius(2)

          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Image(systemName: w.pinned ? "pin.fill" : "folder")
                .foregroundColor(w.selected ? "#FFFFFF" : .secondary)
              Text(w.title)
                .font(.headline)
                .lineLimit(1)
              Spacer()
              if w.unread > 0 {
                Text(String(w.unread))
                  .font(.caption)
                  .foregroundColor("#FFFFFF")
                  .padding(4)
                  .background("#0A84FF")
                  .cornerRadius(8)
              }
            }

            if let branch = w.branch {
              Text(branch)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Text(w.directory)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)

            if let message = w.latestMessage {
              Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            }
          }
        }
        .padding(6)
        .cornerRadius(8)
      }
    }
  }
}
.padding(10)
