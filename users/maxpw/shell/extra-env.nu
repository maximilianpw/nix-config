$env.SHELL = "@BASH_INTERACTIVE@"

# Ghostty shell integration - copy to config dir so config.nu can `use` it
let ghostty_dest = ($nu.default-config-dir | path join "ghostty.nu")
if ($env | get -o GHOSTTY_RESOURCES_DIR | is-not-empty) {
  let ghostty_src = ($env.GHOSTTY_RESOURCES_DIR | path join "shell-integration" "nushell" "ghostty.nu")
  if ($ghostty_src | path exists) {
    open $ghostty_src | save -f $ghostty_dest
  } else {
    "# ghostty stub" | save -f $ghostty_dest
  }
} else {
  "# ghostty stub" | save -f $ghostty_dest
}
