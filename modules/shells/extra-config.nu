use ($nu.default-config-dir | path join "ghostty.nu")

def --wrapped claudex [...args: string] {
  with-env {
    CLAUDE_CODE_ALWAYS_ENABLE_EFFORT: "1",
    CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY: "3",
    ENABLE_TOOL_SEARCH: "false",
  } { claude ...$args }
}

def --wrapped ccc [...args: string] {
  with-env {DISABLE_ZOXIDE: "1"} { claude --dangerously-skip-permissions ...$args }
}
