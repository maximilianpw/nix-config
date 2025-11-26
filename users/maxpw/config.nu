# config.nu

$env.VISUAL = "nvim"
$env.EDITOR = "nvim"

$env.config.buffer_editor = "nvim"
$env.config.show_banner = false
$env.config.highlight_resolved_externals = true

# Direnv hook (merge into existing config, don't replace)
$env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt? | default [] | append { ||
  if (which direnv | is-empty) { return }
  direnv export json | from json | default {} | load-env
  if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
    $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
  }
})

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
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

alias ll = lsg

#-------------------------------------------------------------------------------
# Modules & Integrations
#-------------------------------------------------------------------------------
use std/dirs

# Starship (only generate if missing)
let starship_path = ($nu.data-dir | path join "vendor/autoload/starship.nu")
if not ($starship_path | path exists) {
  mkdir ($starship_path | path dirname)
  starship init nu | save -f $starship_path
}

# Zoxide
source ~/.zoxide.nu

#-------------------------------------------------------------------------------
# Homebrew (macOS)
#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
# GPG
#-------------------------------------------------------------------------------
if (is-terminal --stdin) {
  $env.GPG_TTY = (tty)
}
