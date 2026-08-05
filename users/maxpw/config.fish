#-------------------------------------------------------------------------------
# SSH
#-------------------------------------------------------------------------------
if not test -d $HOME/.ssh
    mkdir -p $HOME/.ssh
    chmod 0700 $HOME/.ssh
end

#-------------------------------------------------------------------------------
# Ghostty Shell Integration
#-------------------------------------------------------------------------------
# Ghostty supports auto-injection but Nix-darwin hard overwrites XDG_DATA_DIRS
# which make it so that we can't use the auto-injection. We have to source
# manually.
if set -q GHOSTTY_RESOURCES_DIR
    set -l ghostty_fish "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
    if test -f "$ghostty_fish"
        source "$ghostty_fish"
    end
end

#-------------------------------------------------------------------------------
# Programs
#-------------------------------------------------------------------------------

# Homebrew
if test -d "/opt/homebrew"
    set -gx HOMEBREW_PREFIX "/opt/homebrew";
    set -gx HOMEBREW_CELLAR "/opt/homebrew/Cellar";
    set -gx HOMEBREW_REPOSITORY "/opt/homebrew";
    set -q PATH; or set PATH ''; set -gx PATH "/opt/homebrew/bin" "/opt/homebrew/sbin" $PATH;
    set -q MANPATH; or set MANPATH ''; set -gx MANPATH "/opt/homebrew/share/man" $MANPATH;
    set -q INFOPATH; or set INFOPATH ''; set -gx INFOPATH "/opt/homebrew/share/info" $INFOPATH;
end

# Add ~/.local/bin
fish_add_path -g "$HOME/.local/bin"


#-------------------------------------------------------------------------------
# Vars
#-------------------------------------------------------------------------------
# Modify our path to include our Go binaries
# Exported variables
if isatty
    set -x GPG_TTY (tty)
end

# Editor
set -gx EDITOR nvim

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
alias rebuild-nix "~/nix-config/scripts/nixos-rebuild.sh"

# JJ PR creation with GitHub CLI
# Usage: jprgh "commit message" [gh pr create args...]
function jprgh
    jj commit -m $argv[1]
    and jj git push -c '@-'
    and set BRANCH "maximilianpw/push-"(jj log -r '@-' --no-graph -T 'change_id.short()')
    and gh pr create --head $BRANCH $argv[2..-1]
end

# JJ PR creation with Graphite CLI
# Usage: jprgt "commit message" [gt submit args...]
function jprgt
    jj commit -m $argv[1]
    and jj git push -c '@-'
    and set BRANCH "maximilianpw/push-"(jj log -r '@-' --no-graph -T 'change_id.short()')
    and git checkout $BRANCH
    and gt track
    and gt submit $argv[2..-1]
    and git checkout -
    and jj git import
end

# Expand three or more dots into the corresponding parent path.
# For example, `......` becomes `../../../../../`.
function __expand_parent_directories
    string repeat -n (math (string length -- $argv[1]) - 1) ../
end

abbr --add parent-directories \
    --position anywhere \
    --regex '^\.\.\.+$' \
    --function __expand_parent_directories
