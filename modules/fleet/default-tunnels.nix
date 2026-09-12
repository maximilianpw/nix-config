# Host-specific default managed localhost forwards. Home Manager owns the
# option; Darwin hosts install one launchd job per local port.
{
  joyce = [
    {
      host = "kim";
      localPort = 3000;
      remotePort = 3000;
    }
    {
      host = "kim";
      localPort = 5173;
      remotePort = 5173;
    }
  ];
}
