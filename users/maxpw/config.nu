# config.nu

use ($nu.default-config-dir | path join scripts nujj)

$env.VISUAL = "nvim"
$env.EDITOR = "nvim"

$env.config.buffer_editor = "nvim"
$env.config.show_banner = false
$env.config.highlight_resolved_externals = true

#-------------------------------------------------------------------------------
# fzf keybindings
#-------------------------------------------------------------------------------
$env.config.keybindings = ($env.config.keybindings | append [
    {
        name: fzf_history_search
        modifier: control
        keycode: char_r
        mode: [emacs vi_normal vi_insert]
        event: {
            send: executehostcommand
            cmd: "try { commandline edit --replace (history | get command | uniq | str join (char newline) | fzf --scheme=history --tiebreak=index +m --height=40% | str trim) }"
        }
    }
    {
        name: fzf_file_search
        modifier: control
        keycode: char_t
        mode: [emacs vi_normal vi_insert]
        event: {
            send: executehostcommand
            cmd: "try { commandline edit --insert (fzf --height=40% | str trim) }"
        }
    }
])

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
def rebuild-nix [...args: string] {
  ^bash $"($env.HOME)/nix-config/scripts/nixos-rebuild.sh" ...$args
}

def gitprep [message: string] {
  git add .
  git commit -m $message
  git push
}

def jprgh [message: string, ...args: string] {
  jj commit -m $message
  if $env.LAST_EXIT_CODE != 0 { return }

  jj git push -c '@-'
  if $env.LAST_EXIT_CODE != 0 { return }

  let branch = $"maximilianpw/push-(jj log -r '@-' --no-graph -T 'change_id.short()' | str trim)"
  gh pr create --head $branch ...$args
}

def jprgt [message: string, ...args: string] {
  jj commit -m $message
  if $env.LAST_EXIT_CODE != 0 { return }

  jj git push -c '@-'
  if $env.LAST_EXIT_CODE != 0 { return }

  let branch = $"maximilianpw/push-(jj log -r '@-' --no-graph -T 'change_id.short()' | str trim)"

  git checkout $branch
  if $env.LAST_EXIT_CODE != 0 { return }

  gt track
  if $env.LAST_EXIT_CODE != 0 {
    git checkout -
    return
  }

  gt submit ...$args
  let submit_exit = $env.LAST_EXIT_CODE

  git checkout -
  if $env.LAST_EXIT_CODE != 0 { return }

  if $submit_exit != 0 { return }

  jj git import
}

def jtp [] {
  jj tug
  jj git push
}

def --wrapped c [...args: string] {
  with-env {DISABLE_ZOXIDE: "1"} { claude --dangerously-skip-permissions ...$args }
}

def lsg [] {
  ls | sort-by type name -i | grid -c | str trim
}

alias ll = lsg
alias fnix = nix-shell --run nu

#-------------------------------------------------------------------------------
# Modules & Integrations
#-------------------------------------------------------------------------------
use std/dirs

#-------------------------------------------------------------------------------
# SSH Agent (1Password)
#-------------------------------------------------------------------------------
let ssh_dir = ($env.HOME | path join '.ssh')
if not ($ssh_dir | path exists) {
  ^mkdir -p $ssh_dir
  ^chmod 0700 $ssh_dir
}

let op_agent = ($env.HOME | path join '.1password' 'agent.sock')
if ($op_agent | path exists) {
  $env.SSH_AUTH_SOCK = $op_agent
}

#-------------------------------------------------------------------------------
# Programs
#-------------------------------------------------------------------------------
let local_bin = ($env.HOME | path join '.local' 'bin')
if not (($env.PATH? | default []) | any {|path_entry| $path_entry == $local_bin }) {
  $env.PATH = ($env.PATH? | default [] | prepend $local_bin)
}

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
