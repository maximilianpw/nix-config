#!/usr/bin/env python3
"""Exercise orb lifecycle jobs against a disposable, stateful Docker fixture."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


def fake_docker(args):
    state_path = Path(os.environ["AMP_ORB_TEST_STATE"])
    state = json.loads(state_path.read_text())
    state["calls"].append(args)
    state_path.write_text(json.dumps(state))
    if os.environ.get("AMP_ORB_TEST_FAIL") == " ".join(args[:2]):
        return 1

    def option(flag):
        return args[args.index(flag) + 1]

    containers = state["containers"]
    command = args[:2]
    if command == ["container", "ls"]:
        selector = option("--filter")
        if selector.startswith("name="):
            pattern = selector.removeprefix("name=")
            for name in containers:
                if re.fullmatch(pattern, "/" + name):
                    print(name)
        else:
            for name, container in containers.items():
                if container["owner"] and container["running"]:
                    print(name)
    elif command == ["container", "inspect"]:
        container = containers[args[-1]]
        if option("--format") == "{{.State.Running}}":
            print(str(container["running"]).lower())
        else:
            print(str(container["owner"]).lower())
    elif command == ["container", "run"]:
        name = option("--name")
        assert name not in containers, "attempted to replace an existing disk"
        containers[name] = {"owner": True, "running": True, "image": args[-3]}
    elif command == ["container", "start"]:
        containers[args[-1]]["running"] = True
    elif command == ["container", "stop"]:
        containers[args[-1]]["running"] = False
    elif command == ["container", "rm"]:
        del containers[args[-1]]
    elif command == ["container", "exec"]:
        assert "--detach" in args
        assert option("--env") == "ORB_TOKEN"
        assert "AMP_ORB_PROVIDER_TOKEN" not in args
        assert args[-3:-1] == ["bash", "-c"]
        assert "flock --nonblock" in args[-1]
        assert "amp orb bootstrap" in args[-1]
    elif command == ["container", "commit"]:
        assert not containers[args[-2]]["running"], "snapshot of running orb"
        state["images"].append(args[-1])
    elif command == ["image", "ls"]:
        tag = option("--filter").removeprefix("reference=")
        if tag in state["images"]:
            print("snapshot-image-id")
    else:
        raise AssertionError(f"Unexpected Docker invocation: {args}")
    state_path.write_text(json.dumps(state))
    return 0


def run_tests():
    script = Path(__file__).resolve().parents[1] / "agents/amp-orb-dispatch.sh"
    with tempfile.TemporaryDirectory(prefix="amp-orb-dispatch-test-") as temp:
        root = Path(temp)
        state_path = root / "state.json"
        docker = root / "docker"
        docker.write_text(
            f"#!{shutil.which('bash')}\nexec "
            + shlex.join([sys.executable, str(Path(__file__).resolve()), "--docker"])
            + ' "$@"\n'
        )
        docker.chmod(0o755)
        env = {
            **os.environ,
            "DOCKER_BIN": str(docker),
            "ORB_STATE_DIRECTORY": str(root),
            "ORB_CPUS": "4",
            "ORB_MEMORY": "8g",
            "ORB_PIDS_LIMIT": "2048",
            "ORB_MAX_RUNNING": "2",
            "ORB_IMAGE": "fixture/orb:latest",
            "ORB_TOKEN": "fixture-short-lived-secret",
            "AMP_ORB_PROVIDER_TOKEN": "fixture-provider-secret",
            "AMP_ORB_TEST_STATE": str(state_path),
        }
        # Do not accidentally inherit real job or server settings.
        for key in ("AMP_URL", "ORB_SNAPSHOT_ID", "AMP_ORB_TEST_FAIL"):
            env.pop(key, None)

        def reset(containers=None):
            state_path.write_text(json.dumps({"containers": containers or {}, "images": [], "calls": []}))

        def state():
            return json.loads(state_path.read_text())

        def job(operation, orb="amp-thread-1", ok=True, **overrides):
            result = subprocess.run(
                ["bash", str(script)],
                env={**env, "ORB_OPERATION": operation, "ORB_ID": orb, **overrides},
                text=True, capture_output=True, timeout=10,
            )
            assert (result.returncode == 0) == ok, (operation, result.stdout, result.stderr)
            assert env["ORB_TOKEN"] not in result.stdout + result.stderr
            assert env["AMP_ORB_PROVIDER_TOKEN"] not in result.stdout + result.stderr
            return result

        def calls(command):
            return [call for call in state()["calls"] if call[:2] == command]

        name = "amp-orb-amp-thread-1"
        reset()
        job("spawn", AMP_URL="https://amp.example.test")
        run = calls(["container", "run"])[0]
        for flag, value in (("--platform", "linux/amd64"), ("--cpus", "4"),
                            ("--memory", "8g"), ("--memory-swap", "8g"), ("--pids-limit", "2048")):
            assert run[run.index(flag) + 1] == value
        assert "--privileged" not in run and "--volume" not in run and "--publish" not in run
        assert "--env" not in run and "--network=host" not in run
        assert "AMP_URL" in calls(["container", "exec"])[0]
        job("spawn")
        assert len(calls(["container", "run"])) == 1
        assert len(calls(["container", "start"])) == 0
        assert all(env["ORB_TOKEN"] not in arg for call in state()["calls"] for arg in call)

        job("pause", ORB_SNAPSHOT_ID="opaque/snapshot:project-1")
        assert not state()["containers"][name]["running"]
        snapshot = state()["images"][0]
        assert snapshot.startswith("amp-orb-provider/snapshot:")
        job("pause", ORB_SNAPSHOT_ID="opaque/snapshot:project-1")
        assert len(calls(["container", "stop"])) == 1
        job("spawn")
        assert state()["containers"][name]["running"]
        assert len(calls(["container", "start"])) == 1
        job("spawn", "amp-thread-2", ORB_SNAPSHOT_ID="opaque/snapshot:project-1")
        assert state()["containers"]["amp-orb-amp-thread-2"]["image"] == snapshot
        job("spawn", "amp-thread-3", ok=False)
        job("spawn")  # Capacity limit does not reject an already running orb.
        job("delete")
        job("delete")
        assert len(calls(["container", "rm"])) == 1
        assert snapshot in state()["images"], "shared snapshots must survive thread deletion"
        job("pause")
        job("spawn", "amp-thread-3", ORB_SNAPSHOT_ID="unknown-snapshot")
        assert state()["containers"]["amp-orb-amp-thread-3"]["image"] == env["ORB_IMAGE"]

        reset({name: {"owner": False, "running": False}})
        for operation in ("spawn", "pause", "delete"):
            job(operation, ok=False)
        assert not calls(["container", "run"]) and not calls(["container", "rm"])

        reset({"amp-orb-amp-threadX1": {"owner": False, "running": True}})
        job("spawn", "amp-thread.1")
        job("delete", "amp-thread.1")
        assert "amp-orb-amp-threadX1" in state()["containers"]

        reset()
        for orb in ("../../host", "--help", "amp-*", "amp-x\nother"):
            job("delete", orb, ok=False)
        job("unsupported", ok=False)
        job("spawn", ok=False, ORB_TOKEN="")
        assert state()["calls"] == []
        job("spawn", ok=False, AMP_ORB_TEST_FAIL="container ls")
        assert not calls(["container", "run"])

        reset({name: {"owner": True, "running": False, "image": env["ORB_IMAGE"]}})
        job("spawn", ok=False, AMP_ORB_TEST_FAIL="container start")
        assert not calls(["container", "run"]) and not calls(["container", "exec"])
        job("delete", ok=False, AMP_ORB_TEST_FAIL="container rm")
        assert name in state()["containers"]
        job("pause", ok=False, ORB_SNAPSHOT_ID="snapshot", AMP_ORB_TEST_FAIL="container commit")
        assert not state()["images"]
        reset({name: {"owner": True, "running": True, "image": env["ORB_IMAGE"]}})
        job("pause", ok=False, ORB_SNAPSHOT_ID="snapshot", AMP_ORB_TEST_FAIL="container stop")
        assert not calls(["container", "commit"])
        reset()
        job("spawn", ok=False, AMP_ORB_TEST_FAIL="container run")
        assert not calls(["container", "exec"])
        job("spawn", ok=False, AMP_ORB_TEST_FAIL="container exec")
        reset()
        job("pause", ORB_TOKEN="", ORB_IMAGE="")
        job("delete", ORB_TOKEN="", ORB_IMAGE="")

        # Run the exact in-container bootstrap command locally with a fake Amp
        # executable to prove repeated spawns cannot make two live connections.
        reset()
        job("spawn")
        bootstrap_command = calls(["container", "exec"])[0][-1]
        amp = root / "amp"
        amp.write_text(
            f"#!{shutil.which('bash')}\n"
            'printf started >> "$HOME/bootstrap-starts"\n'
            'while [[ ! -f "$HOME/release" ]]; do sleep 0.02; done\n'
        )
        amp.chmod(0o755)
        bootstrap_env = {**env, "HOME": str(root), "PATH": str(root) + os.pathsep + env["PATH"]}
        first = subprocess.Popen(["bash", "-c", bootstrap_command], env=bootstrap_env)
        try:
            deadline = time.monotonic() + 5
            while not (root / "bootstrap-starts").exists():
                assert time.monotonic() < deadline, "bootstrap did not start"
                time.sleep(0.02)
            second = subprocess.run(["bash", "-c", bootstrap_command], env=bootstrap_env, timeout=5)
            assert second.returncode == 1
            assert (root / "bootstrap-starts").read_text() == "started"
        finally:
            (root / "release").touch()
            first.wait(timeout=5)
        assert first.returncode == 0
        print("Amp orb dispatch lifecycle tests passed")


if __name__ == "__main__":
    if sys.argv[1:] and sys.argv[1] == "--docker":
        sys.exit(fake_docker(sys.argv[2:]))
    run_tests()
