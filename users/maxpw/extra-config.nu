use ($nu.default-config-dir | path join "ghostty.nu")

def --wrapped claudex [...args: string] {
  with-env {
    CLAUDE_CODE_ALWAYS_ENABLE_EFFORT: "1",
    CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY: "3",
    ENABLE_TOOL_SEARCH: "false",
  } { claude ...$args }
}

def --wrapped climi [...args: string] {
  with-env {
    ANTHROPIC_BASE_URL: "@CLI_PROXY_BASE_URL@",
    ANTHROPIC_AUTH_TOKEN: "@CLI_PROXY_API_KEY@",
    ANTHROPIC_DEFAULT_OPUS_MODEL: "@CLIMI_MODEL@",
    ANTHROPIC_DEFAULT_SONNET_MODEL: "@CLIMI_MODEL@",
    ANTHROPIC_DEFAULT_HAIKU_MODEL: "@CLIMI_MODEL@",
    CLAUDE_CODE_SUBAGENT_MODEL: "@CLIMI_MODEL@",
    CLAUDE_CODE_ALWAYS_ENABLE_EFFORT: "1",
    CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY: "3",
    ENABLE_TOOL_SEARCH: "false",
  } { claude-direct --model "@CLIMI_MODEL@" --effort max ...$args }
}

def --wrapped ccc [...args: string] {
  with-env {DISABLE_ZOXIDE: "1"} { claude --dangerously-skip-permissions ...$args }
}
