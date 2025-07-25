# config.nu
#
# Installed by:
# version = "0.105.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

$env.VISUAL = "nvim"
$env.EDITOR = "nvim"
$env.config.buffer_editor = "nvim"
$env.config.show_banner = false
$env.config.highlight_resolved_externals = true



def rebuild-nix [...args: string] {
  ^bash $"($nu.home-path)/nix-config/scripts/nixos-rebuild.sh" ...$args
}

def gitprep [message: string] {
  git add .
  git commit -m $message
  git push
}

def lsg [] {
  ls | sort-by type name -i | grid -c | str trim
}

alias ga = git add
alias gaa = git add .
alias gst = git status
alias gco = git checkout
alias gcm = git commit -m
alias gp = git push
alias gl = git pull
alias ll = lsg
alias v = nvim

# modules 
use std/dirs

# starship config
mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

# zoxide config
source ~/.zoxide.nu

# direnv config
$env.config = {
  hooks: {
    pre_prompt: [{ ||
      if (which direnv | is-empty) {
        return
      }

      direnv export json | from json | default {} | load-env
      if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
        $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
      }
    }]
  }
}

# Homebrew setup
if ('/opt/homebrew' | path type) == 'dir' {
  $env.HOMEBREW_PREFIX = '/opt/homebrew'
  $env.HOMEBREW_CELLAR = '/opt/homebrew/Cellar'
  $env.HOMEBREW_REPOSITORY = '/opt/homebrew'
  $env.PATH = $env.PATH? | prepend [
    '/opt/homebrew/bin'
    '/opt/homebrew/sbin'
  ]
  $env.MANPATH = $env.MANPATH? | prepend '/opt/homebrew/share/man'
  $env.INFOPATH = $env.INFOPATH? | prepend '/opt/homebrew/share/info'
}

# Ensure we can use the terminal for GPG signing
if (is-terminal --stdin) {
  $env.GPG_TTY = (tty)
}

# Override some commands to use 1password
alias amp = op run -- amp
alias codex = op run -- codex
