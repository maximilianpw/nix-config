# tmux configuration
{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    shell = "${pkgs.nushell}/bin/nu";
    terminal = "tmux-256color";
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    mouse = true;
    keyMode = "vi";
    sensibleOnTop = true;

    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      yank
      tmux-thumbs
      tmux-fzf
      sessionist
      open
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '10'
        '';
      }
    ];

    extraConfig = ''
      # True color and undercurl support
      set -as terminal-features ",xterm-256color:RGB"
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Focus events for vim autoread
      set -g focus-events on

      # Split panes with | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # New window in current path
      bind c new-window -c "#{pane_current_path}"

      # Resize panes with Alt+arrow (no prefix needed)
      bind -n M-Up    resize-pane -U 3
      bind -n M-Down  resize-pane -D 3
      bind -n M-Left  resize-pane -L 3
      bind -n M-Right resize-pane -R 3

      # Swap windows left/right with Shift+arrow
      bind -n S-Left  swap-window -t -1\; select-window -t -1
      bind -n S-Right swap-window -t +1\; select-window -t +1

      # Quick window switching with Alt+number
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9

      # Vi copy mode bindings
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # Toggle status bar
      bind b set-option status

      # Kill pane without confirm
      bind x kill-pane

      # ── Status bar ──────────────────────────────────────────────
      set -g status-position top
      set -g status-interval 2
      set -g status-justify left
      set -g status-style "bg=default,fg=#c0caf5"

      # Left: session name
      set -g status-left-length 30
      set -g status-left "#[fg=#1a1b26,bg=#7aa2f7,bold]  #S #[fg=#7aa2f7,bg=default,nobold] "

      # Right: date + time
      set -g status-right-length 60
      set -g status-right "#[fg=#565f89] %a %d %b #[fg=#7aa2f7,bold] %H:%M "

      # Window tabs
      set -g window-status-format "#[fg=#565f89]  #I #W "
      set -g window-status-current-format "#[fg=#1a1b26,bg=#7aa2f7,bold]  #I #W #[fg=#7aa2f7,bg=default,nobold]"
      set -g window-status-separator ""

      # Pane borders
      set -g pane-border-style "fg=#292e42"
      set -g pane-active-border-style "fg=#7aa2f7"

      # Message style
      set -g message-style "fg=#7aa2f7,bg=#1a1b26"
    '';
  };
}
