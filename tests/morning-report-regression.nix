# The morning report is a trial of unattended, read-only work: it is gated on
# `longRunningAgents && homelab profile`, which today selects only Kim, and it
# must stay a oneshot timer. Cuno proves hosts outside the predicate get nothing.
{
  cuno,
  kim,
  lib,
  pkgs,
}: let
  expect = import ./lib/expect.nix {inherit lib;};
  service = kim.systemd.user.services.morning-report;
  timer = kim.systemd.user.timers.morning-report;
  isMorningReport = package: lib.getName package == "morning-report";
  morningReport = lib.findFirst isMorningReport null kim.home.packages;
in
  assert expect.all "Kim installs the morning report as a oneshot user service with a daily timer" [
    (morningReport != null)
    (kim.systemd.user.services ? morning-report)
    (kim.systemd.user.timers ? morning-report)
    (service.Service.Type == "oneshot")
    (lib.all (command: lib.hasSuffix "/bin/morning-report" command) (lib.toList service.Service.ExecStart))
    (timer.Timer.OnCalendar == "*-*-* 07:00:00")
    (timer.Timer.RandomizedDelaySec == "5m")
    (timer.Timer.Persistent == true)
    (timer.Install.WantedBy == ["timers.target"])
  ];
  assert expect.all "Hosts without long-running homelab agents must not schedule the morning report" [
    (!(cuno.systemd.user.services ? morning-report))
    (!(cuno.systemd.user.timers ? morning-report))
    (!(lib.any isMorningReport cuno.home.packages))
  ];
  # Building the wrapper runs writeShellApplication's ShellCheck; the argument
  # rejection proves the wrapper reaches the script without writing anything.
    pkgs.runCommand "morning-report-regression" {nativeBuildInputs = [morningReport];} ''
      if morning-report unexpected-argument 2>stderr; then
        echo "morning-report must reject positional arguments" >&2
        exit 1
      fi
      grep -q "accepts no arguments" stderr
      touch "$out"
    ''
