#!/usr/bin/env python3
"""Stable Inbox launcher, read-only diagnostics, and an authenticated redirect."""

import argparse
import json
import os
import socket
from pathlib import Path
import subprocess
import sys
import tomllib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, build_opener


class InboxUnavailable(Exception):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def json_file(path):
    with Path(path).open() as source:
        value = json.load(source)
    if not isinstance(value, dict):
        raise ValueError(f"Expected an object in {path.name}")
    return value


def inbox_state(data_dir, expected_host=None):
    """Trust neither a stale registry nor a registry-controlled redirect host."""
    try:
        registry = json_file(data_dir / "inbox/inbox.json")
        port = registry.get("port")
        if type(port) is not int or not 0 < port < 65536:
            raise ValueError("Invalid Inbox port")
        local_url = f"http://127.0.0.1:{port}"
        opener = build_opener(ProxyHandler({}), NoRedirect())
        with opener.open(f"{local_url}/api/inbox/health", timeout=2) as response:
            health = json.loads(response.read(65536))
        if (
            health.get("app") != "plannotator-inbox"
            or health.get("ok") is not True
            or not registry.get("serverSession")
            or health.get("serverSession") != registry["serverSession"]
        ):
            raise ValueError("Inbox registry does not match the running server")
        tailnet_url = (registry.get("tailscale") or {}).get("url")
        if expected_host is not None and tailnet_url not in (
            f"https://{expected_host}:{port}", f"https://{expected_host}:{port}/"
        ):
            raise ValueError("Inbox has no valid owner-guarded Tailscale address")
        return {
            "running": True,
            "version": health.get("version"),
            "local_url": local_url,
            "tailnet_url": tailnet_url,
        }
    except (OSError, ValueError, TypeError, AttributeError) as error:
        raise InboxUnavailable(str(error)) from error


def redirect_handler(data_dir, service_host, inbox_host, allowed_logins):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.respond()

        def do_HEAD(self):
            self.respond(head=True)

        def do_POST(self):
            self.reply(403, b"Agent tools are local-only.\n")

        def reply(self, status, body=b"", location=None, head=False):
            self.send_response(status)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            if location:
                self.send_header("Location", location)
            self.end_headers()
            if not head:
                self.wfile.write(body)

        def respond(self, head=False):
            path = urlsplit(self.path).path
            host = self.headers.get("Host", "").lower()
            # Homelab probes call loopback directly, not through Tailscale Serve.
            local_health = (
                path == "/health"
                and host == f"127.0.0.1:{self.server.server_port}"
                and self.headers.get("Tailscale-User-Login") is None
            )
            if not local_health:
                if host not in (service_host, f"{service_host}:443"):
                    self.reply(403, b"Unexpected host.\n", head=head)
                    return
                if self.headers.get("Tailscale-User-Login", "").lower() not in allowed_logins:
                    self.reply(403, b"This Inbox is restricted to its owner.\n", head=head)
                    return
            if path not in ("/", "/health"):
                self.reply(404, b"Not found.\n", head=head)
                return
            try:
                state = inbox_state(data_dir, inbox_host)
            except InboxUnavailable:
                self.reply(503, b"Inbox unavailable. Run inbox doctor kim.\n", head=head)
                return
            if path == "/health":
                self.reply(200, b"ok\n", head=head)
            else:
                self.reply(303, location=state["tailnet_url"], head=head)

    return Handler


def doctor(home, data_dir, hostname, expected_version, plannotator, inbox_host, bookmark_host=None, redirect_port=None):
    report = {"host": hostname, "expected_version": expected_version, "checks": {}}
    checks = report["checks"]
    try:
        version = subprocess.check_output([plannotator, "--version"], text=True, timeout=10).strip()
        checks["cli"] = {"ok": version == f"plannotator {expected_version}", "version": version}
    except (OSError, subprocess.SubprocessError) as error:
        checks["cli"] = {"ok": False, "error": str(error)}
    try:
        state = inbox_state(data_dir, inbox_host if hostname == "kim" else None)
        checks["inbox"] = {"ok": state["version"] == expected_version, **state}
    except InboxUnavailable as error:
        checks["inbox"] = {"ok": False, "error": str(error)}
    try:
        pi = json_file(home / ".pi/agent/npm/node_modules/@plannotator/pi-extension/package.json")
        checks["pi_extension"] = {"ok": pi.get("version") == expected_version, "version": pi.get("version")}
    except (OSError, ValueError) as error:
        checks["pi_extension"] = {"ok": False, "error": str(error)}
    try:
        plugins = json_file(home / ".claude/plugins/installed_plugins.json")
        installed = plugins.get("plugins", {}).get("plannotator@plannotator", [])
        versions = [entry.get("version") for entry in installed if entry.get("scope") == "user"]
        checks["claude_plugin"] = {"ok": expected_version in versions, "versions": versions}
    except (OSError, ValueError) as error:
        checks["claude_plugin"] = {"ok": False, "error": str(error)}
    try:
        config = json_file(home / ".config/opencode/opencode.json")
        plugins = [item if isinstance(item, str) else item.get("package") for item in config.get("plugins", [])]
        checks["opencode_declaration"] = {"ok": f"@plannotator/opencode@{expected_version}" in plugins}
    except (OSError, ValueError, AttributeError) as error:
        checks["opencode_declaration"] = {"ok": False, "error": str(error)}
    for agent, path, key in (
        ("amp", ".config/amp/settings.json", "amp.mcpServers"),
        ("muse", ".config/muse/settings.json", "mcpServers"),
        ("codex", ".codex/config.toml", "mcp_servers"),
        ("grok", ".grok/config.toml", "mcp_servers"),
    ):
        try:
            if path.endswith(".toml"):
                with (home / path).open("rb") as source:
                    config = tomllib.load(source)
            else:
                config = json_file(home / path)
            server = config.get(key, {}).get("plannotator-inbox", {})
            checks[f"{agent}_declaration"] = {"ok": bool(server.get("command")) and server.get("args") == ["inbox", "mcp"]}
        except (OSError, ValueError, AttributeError) as error:
            checks[f"{agent}_declaration"] = {"ok": False, "error": str(error)}
    if bookmark_host:
        try:
            socket.getaddrinfo(bookmark_host, 443, type=socket.SOCK_STREAM)
            checks["bookmark_dns"] = {"ok": True, "host": bookmark_host}
        except OSError:
            checks["bookmark_dns"] = {"ok": False, "error": "Service DNS is unavailable. Define/approve svc:plannotator in Tailscale."}
    if redirect_port is not None:
        try:
            opener = build_opener(ProxyHandler({}), NoRedirect())
            with opener.open(f"http://127.0.0.1:{redirect_port}/health", timeout=2) as response:
                checks["redirect"] = {"ok": response.status == 200 and response.read(16) == b"ok\n"}
        except OSError as error:
            checks["redirect"] = {"ok": False, "error": str(error)}
    report["ok"] = all(check["ok"] for check in checks.values())
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", default="kim", choices=["kim", "joyce", "local", "doctor", "serve"])
    parser.add_argument("target", nargs="?", default="local", choices=["kim", "joyce", "local"])
    parser.add_argument("--json", action="store_true", help="Machine-readable doctor output")
    args = parser.parse_args()
    home = Path.home()
    data_dir = Path(os.environ.get("PLANNOTATOR_DATA_DIR", home / ".plannotator"))
    hostname = os.environ["INBOX_HOST"]
    plannotator = os.environ["PLANNOTATOR_BIN"]
    kim_url = os.environ["INBOX_KIM_URL"]
    inbox_host = os.environ["INBOX_KIM_HOST"]
    if args.action == "serve":
        allowed = {login.lower() for login in json.loads(os.environ["INBOX_ALLOWED_LOGINS"])}
        if not allowed:
            parser.error("The redirect requires at least one allowed Tailscale login")
        handler = redirect_handler(data_dir, urlsplit(kim_url).hostname, inbox_host, allowed)
        server = ThreadingHTTPServer(("127.0.0.1", int(os.environ["INBOX_REDIRECT_PORT"])), handler)
        server.serve_forever()
        return 0
    if args.action == "doctor":
        if args.target not in ("local", hostname):
            return subprocess.call([os.environ["FLEET_BIN"], "run", args.target, "~/.local/bin/inbox", "doctor", "local", "--json"])
        report = doctor(home, data_dir, hostname, os.environ["INBOX_VERSION"], plannotator, inbox_host,
                        urlsplit(kim_url).hostname,
                        int(os.environ["INBOX_REDIRECT_PORT"]) if hostname == "kim" else None)
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            print(f"Plannotator on {hostname} (expected {report['expected_version']})")
            for name, check in report["checks"].items():
                print(f"  {'OK' if check['ok'] else 'FAIL'} {name}: {json.dumps(check)}")
            print("Checks verify installation, configuration and DNS, not tools loaded in existing sessions or browser access grants.")
            print("Restart agents or /reload Pi after upgrades.")
        return 0 if report["ok"] else 1
    if args.action == "local" or (args.action == "joyce" and hostname == "joyce"):
        return subprocess.call([plannotator, "inbox"])
    if args.action == "joyce":
        parser.error("Joyce's Inbox is local-only. Run 'inbox joyce' on Joyce.")
    print(kim_url, flush=True)
    if sys.platform == "darwin" or os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"):
        return subprocess.call([os.environ["INBOX_OPEN_BIN"], kim_url])
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, KeyError, ValueError) as error:
        print(f"inbox: {error}", file=sys.stderr)
        sys.exit(1)
