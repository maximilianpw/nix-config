#!/usr/bin/env python3
"""Test Executor's configured Docker healthcheck in disposable isolated containers.

Run from the flake root after building executor-config-regression and its static
shell dependency. Requires Nix, Docker access, and the pinned image already
present locally. Never mounts Executor state, publishes ports, or pulls images.
"""

import json
import subprocess
import time
import uuid


def main():
    config = json.loads(subprocess.check_output([
        "nix", "eval", "--json",
        ".#nixosConfigurations.kim.config.virtualisation.oci-containers.containers.executor",
    ], text=True))
    health = next(option for option in config["extraOptions"]
                  if option.startswith("--health-cmd="))
    shell = next(volume for volume in config["volumes"]
                 if volume.endswith(":/bin/sh:ro"))
    for mode in ("without-shell", "with-static-shell"):
        name = "executor-health-fixture-" + uuid.uuid4().hex[:12]
        args = [
            "docker", "run", "-d", "--pull=never", "--name", name,
            "--network=none", "--read-only", "--tmpfs", "/tmp",
            "--cap-drop=ALL", "--security-opt=no-new-privileges",
            "--entrypoint", "bun", health, "--health-interval=1s",
            "--health-start-period=1s", "--health-retries=1",
        ]
        if mode == "with-static-shell":
            args += ["--volume", shell]
        # A private loopback server first succeeds, then deliberately returns 503.
        args += [config["image"], "-e", (
            "let status=200; Bun.serve({hostname:'127.0.0.1',port:19005,"
            "fetch(){return new Response('fixture',{status})}});"
            "setTimeout(()=>{status=503},5000);"
        ).replace("port:19005", "port:" + config["environment"]["PORT"])]
        try:
            subprocess.run(args, check=True, stdout=subprocess.DEVNULL)
            deadline = time.monotonic() + 20
            healthy = False
            completed = False
            while time.monotonic() < deadline:
                state = json.loads(subprocess.check_output([
                    "docker", "inspect", "--format", "{{json .State.Health}}", name,
                ], text=True))
                if mode == "without-shell" and state.get("Log"):
                    output = state["Log"][-1]["Output"]
                    if "/bin/sh" not in output or "no such file" not in output:
                        raise RuntimeError("Expected missing-shell failure, got: " + output)
                    print("RED: configured healthcheck cannot run without /bin/sh")
                    completed = True
                    break
                if mode == "with-static-shell":
                    if state["Status"] == "healthy" and not healthy:
                        healthy = True
                        print("GREEN: configured check reports healthy for HTTP 200")
                    if healthy and state["Status"] == "unhealthy":
                        if state["Log"][-1]["ExitCode"] != 1:
                            raise RuntimeError("Healthcheck failed without rejecting HTTP 503")
                        print("GREEN: same check rejects HTTP 503")
                        completed = True
                        break
                time.sleep(0.5)
            if not completed:
                raise RuntimeError(mode + ": expected health state was not observed")
        finally:
            # Only the task-created UUID-named fixture is removed, including if
            # docker run created it but failed to start. Never remove any volume.
            subprocess.run(["docker", "rm", "-f", name], check=True,
                           stdout=subprocess.DEVNULL)
    print("Fixtures removed; no production container or volume touched.")


if __name__ == "__main__":
    main()
