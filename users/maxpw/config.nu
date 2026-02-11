# config.nu

$env.VISUAL = "nvim"
$env.EDITOR = "nvim"

$env.config.buffer_editor = "nvim"
$env.config.show_banner = false
$env.config.highlight_resolved_externals = true

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

def jtp [] {
  jj tug
  jj git push
}

def lsg [] {
  ls | sort-by type name -i | grid -c | str trim
}

alias ll = lsg

#-------------------------------------------------------------------------------
# Modules & Integrations
#-------------------------------------------------------------------------------
use std/dirs

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
  $env.MANPATH = $"/opt/homebrew/share/man:($env.MANPATH? | default '')"
  $env.INFOPATH = $"/opt/homebrew/share/info:($env.INFOPATH? | default '')"
}

#-------------------------------------------------------------------------------
# GPG
#-------------------------------------------------------------------------------
if (is-terminal --stdin) {
  $env.GPG_TTY = (tty)
}
