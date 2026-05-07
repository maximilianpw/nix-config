{
  pkgs,
  isDarwin,
  isWSL ? false,
  ...
}: let
  zellijClipboardSettings =
    if isDarwin
    then {copy_command = "pbcopy";}
    else if pkgs.stdenv.isLinux && !isWSL
    then {copy_command = "wl-copy";}
    else {};
in {
  programs.zellij = {
    enable = true;
    settings =
      {
        default_shell = "${pkgs.nushell}/bin/nu";
        session_serialization = true;
        serialize_pane_viewport = true;
        scrollback_lines_to_serialize = 10000;
        scroll_buffer_size = 50000;
        simplified_ui = true;
        default_layout = "compact-top";
        theme = "kanagawa";
      }
      // zellijClipboardSettings;
    layouts."compact-top" = ''
      layout {
        pane size=1 borderless=true {
          plugin location="compact-bar"
        }
        pane
      }
    '';
    themes.kanagawa = ''
      themes {
        kanagawa {
          fg 220 215 186
          bg 31 31 40
          black 13 13 20
          red 211 86 93
          green 118 148 106
          yellow 220 165 97
          blue 122 168 159
          magenta 149 127 184
          orange 255 160 102
          cyan 125 196 228
          white 220 215 186
        }
      }
    '';
    extraConfig = ''
      keybinds clear-defaults=true {
        shared_except "tmux" "locked" {
          bind "Ctrl Space" { SwitchToMode "Tmux"; }
        }

        shared_except "normal" "locked" {
          bind "Enter" "Esc" { SwitchToMode "Normal"; }
        }

        tmux {
          bind "Ctrl Space" { SwitchToMode "Normal"; }
          bind "[" { SwitchToMode "Scroll"; }
          bind "c" { NewTab; SwitchToMode "Normal"; }
          bind "," { SwitchToMode "RenameTab"; TabNameInput 0; }
          bind "n" { GoToNextTab; SwitchToMode "Normal"; }
          bind "p" { GoToPreviousTab; SwitchToMode "Normal"; }
          bind "x" { CloseFocus; SwitchToMode "Normal"; }
          bind "z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
          bind "o" { FocusNextPane; SwitchToMode "Normal"; }
          bind "d" { Detach; }
          bind "Space" { NextSwapLayout; SwitchToMode "Normal"; }
          bind "h" "Left" { MoveFocus "Left"; SwitchToMode "Normal"; }
          bind "j" "Down" { MoveFocus "Down"; SwitchToMode "Normal"; }
          bind "k" "Up" { MoveFocus "Up"; SwitchToMode "Normal"; }
          bind "l" "Right" { MoveFocus "Right"; SwitchToMode "Normal"; }
          bind "|" { NewPane "Right"; SwitchToMode "Normal"; }
          bind "%" { NewPane "Right"; SwitchToMode "Normal"; }
          bind "-" { NewPane "Down"; SwitchToMode "Normal"; }
          bind "\"" { NewPane "Down"; SwitchToMode "Normal"; }
          bind "B" { BreakPane; SwitchToMode "Normal"; }
          bind "1" { GoToTab 1; SwitchToMode "Normal"; }
          bind "2" { GoToTab 2; SwitchToMode "Normal"; }
          bind "3" { GoToTab 3; SwitchToMode "Normal"; }
          bind "4" { GoToTab 4; SwitchToMode "Normal"; }
          bind "5" { GoToTab 5; SwitchToMode "Normal"; }
          bind "6" { GoToTab 6; SwitchToMode "Normal"; }
          bind "7" { GoToTab 7; SwitchToMode "Normal"; }
          bind "8" { GoToTab 8; SwitchToMode "Normal"; }
          bind "9" { GoToTab 9; SwitchToMode "Normal"; }
          bind "g" {
            Run "lazygit" {
              floating true
              close_on_exit true
              width "90%"
              height "90%"
            };
            SwitchToMode "Normal";
          }
          bind "G" {
            Run "jjui" {
              floating true
              close_on_exit true
              width "90%"
              height "90%"
            };
            SwitchToMode "Normal";
          }
        }

        scroll {
          bind "Ctrl c" { ScrollToBottom; SwitchToMode "Normal"; }
          bind "Esc" "Enter" { SwitchToMode "Normal"; }
          bind "e" { EditScrollback; SwitchToMode "Normal"; }
          bind "s" { SwitchToMode "EnterSearch"; SearchInput 0; }
          bind "j" "Down" { ScrollDown; }
          bind "k" "Up" { ScrollUp; }
          bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
          bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
          bind "d" { HalfPageScrollDown; }
          bind "u" { HalfPageScrollUp; }
        }

        search {
          bind "Ctrl c" { ScrollToBottom; SwitchToMode "Normal"; }
          bind "Esc" "Enter" { SwitchToMode "Normal"; }
          bind "j" "Down" { ScrollDown; }
          bind "k" "Up" { ScrollUp; }
          bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
          bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
          bind "d" { HalfPageScrollDown; }
          bind "u" { HalfPageScrollUp; }
          bind "n" { Search "down"; }
          bind "p" { Search "up"; }
          bind "c" { SearchToggleOption "CaseSensitivity"; }
          bind "w" { SearchToggleOption "Wrap"; }
          bind "o" { SearchToggleOption "WholeWord"; }
        }

        entersearch {
          bind "Ctrl c" "Esc" { SwitchToMode "Scroll"; }
          bind "Enter" { SwitchToMode "Search"; }
        }

        renametab {
          bind "Ctrl c" { SwitchToMode "Normal"; }
          bind "Esc" { UndoRenameTab; SwitchToMode "Normal"; }
        }
      }
    '';
  };
}
