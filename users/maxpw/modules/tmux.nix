{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    shell = "${pkgs.nushell}/bin/nu";
    terminal = "tmux-256color";
    prefix = "C-Space";
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

      set -g renumber-windows on

      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      bind c new-window -c "#{pane_current_path}"

      # Resize panes (prefix + arrow, repeatable)
      bind -r Up    resize-pane -U 3
      bind -r Down  resize-pane -D 3
      bind -r Left  resize-pane -L 3
      bind -r Right resize-pane -R 3

      # Swap windows with Shift+arrow
      bind -n S-Left  swap-window -t -1\; select-window -t -1
      bind -n S-Right swap-window -t +1\; select-window -t +1

      # Window switching with Alt+number
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9

      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi C-v send-keys -X rectangle-toggle

      bind p display-popup -E -w 80% -h 80% -d "#{pane_current_path}"
      bind g display-popup -E -w 90% -h 90% -d "#{pane_current_path}" lazygit
      bind G display-popup -E -w 90% -h 90% -d "#{pane_current_path}" jjui
      bind s display-popup -E "tmux list-sessions | fzf --reverse | cut -d: -f1 | xargs tmux switch-client -t"

      # Join/break panes
      bind j choose-window "join-pane -h -s '%%'"
      bind B break-pane

      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"
      bind b set-option status
      bind x kill-pane

      # Status bar
      set -g status-position top
      set -g status-interval 2
      set -g status-justify left
      set -g status-style "bg=default,fg=#c0caf5"

      set -g status-left-length 30
      set -g status-left "#[fg=#1a1b26,bg=#7aa2f7,bold]  #S #[fg=#7aa2f7,bg=default,nobold] "

      set -g status-right-length 60
      set -g status-right "#[fg=#565f89] %a %d %b #[fg=#7aa2f7,bold] %H:%M "

      set -g window-status-format "#[fg=#565f89]  #I #W "
      set -g window-status-current-format "#[fg=#1a1b26,bg=#7aa2f7,bold]  #I #W #[fg=#7aa2f7,bg=default,nobold]"
      set -g window-status-separator ""

      set -g pane-border-style "fg=#292e42"
      set -g pane-active-border-style "fg=#7aa2f7"

      set -g message-style "fg=#7aa2f7,bg=#1a1b26"
    '';
  };
}
