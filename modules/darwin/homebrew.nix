# macOS GUI apps and the few CLIs whose signed Homebrew builds matter (1Password
# CLI, GnuPG with pinentry-mac). Self-contained notarized apps may instead move
# to modules/home/darwin-apps.nix; follow its non-zapping handover.
_: {
  homebrew = {
    enable = true;

    taps = [
      "maximilianpw/tap"
    ];

    brews = [
      "maximilianpw/tap/rmus"
      "ffmpeg"
      "gnupg"
      "jsonlint"
      "pinentry-mac"
      "zsh"
      "mole"
      "pscale"
    ];

    casks = [
      "colemak-dh"
      "bitwarden"
      "1password"
      # Use 1Password's signed Homebrew CLI so desktop-app authentication works.
      "1password-cli"
      "hyperkey"
      "rectangle"
      "vicinae"
      "whatsapp"
      "chatgpt"
      "legcord"
      "notion"
      "slack"
      "proton-mail"
      "fastmail"
      "ghostty"
      "aws-vpn-client"
      "orbstack"
      "claude"
      "helium-browser"
      "yaak"
      "studio-3t-community"
      "cursor"
      "mullvad-vpn"
      "termius"
      "linear"
      "anomaly-hex"
      "granola"
      "freelens"
      "nextcloud"
      "plex"
      "tldraw"
      "grok-bot"
      # Upstream-signed build; llm-agents builds it from source with an ad-hoc
      # signature, which resets macOS permission grants on every update.
      "herdr-app"
    ];

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      # Temporary: ChatGPT's current cask download returns 404. Restore once fixed upstream.
      upgrade = false;
      # Homebrew now requires an explicit confirmation flag when `brew bundle`
      # is run with cleanup during nix-darwin activation.
      extraFlags = ["--force-cleanup"];
    };
  };
}
