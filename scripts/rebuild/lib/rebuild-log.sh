# shellcheck shell=bash
# Turn captured nh/nom terminal output into a readable log and failure summary.

# nom redraws its status by clearing the line (ESC[2K) and repainting it, so
# only the text after the last clear on each line was ever visible. Lines that
# start with nom's status glyphs are progress frames, not messages.
clean_rebuild_log() {
    awk '
        BEGIN { clear = "\033[2K" }
        {
            line = $0
            while ((i = index(line, clear)) > 0) line = substr(line, i + length(clear))
            gsub(/\033\[[0-9;?]*[A-Za-z]/, "", line)
            sub(/[ \t]+$/, "", line)
            if (line == "" && $0 != "") next
            if (index(line, "⏱") == 1 || index(line, "┏") == 1 || index(line, "┃") == 1 ||
                index(line, "┣") == 1 || index(line, "┗") == 1) next
            print line
        }
    '
}

# Prints the first Nix error with its indented continuation lines; fails when
# the log has none.
first_nix_error() {
    awk '
        !found && /^error:/ { found = 1; print; next }
        !found { next }
        /^$/ { blank++; next }
        /^[ \t]/ {
            for (; blank > 0; blank--) print ""
            print
            if (++n >= 80) exit
            next
        }
        { exit }
        END { exit !found }
    '
}

# Reads the cleaned log of a failed rebuild and explains where it broke.
summarize_rebuild_failure() {
    local log
    log=$(cat)
    if ! first_nix_error <<< "$log"; then
        printf 'No Nix error found; last lines of output:\n'
        tail -n 30 <<< "$log"
    fi
}
