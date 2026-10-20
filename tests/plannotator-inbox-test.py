#!/usr/bin/env python3
"""Exercise the redirect and diagnostics using only disposable local servers."""

import contextlib
import http.client
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("inbox", os.environ["PLANNOTATOR_INBOX_SCRIPT"])
inbox = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inbox)


class InboxTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.data = self.home / ".plannotator"
        self.health = {"ok": True, "app": "plannotator-inbox", "serverSession": "fixture-session", "version": "0.28.23"}
        test = self

        class Native(BaseHTTPRequestHandler):
            def do_GET(self):
                if test.health == "redirect":
                    self.send_response(302)
                    self.send_header("Location", "http://127.0.0.1:1/forbidden")
                    self.end_headers()
                    return
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(test.health).encode())

            def log_message(self, *_):
                pass

        self.native = self.start_server(Native)
        self.registry = {
            "port": self.native.server_port,
            "serverSession": "fixture-session",
            "tailscale": {"url": f"https://kim.example.ts.net:{self.native.server_port}/"},
        }
        self.write_registry()
        handler = inbox.redirect_handler(self.data, "plannotator.example.ts.net", "kim.example.ts.net", {"owner@example.com"})
        self.redirect = self.start_server(handler)

    def start_server(self, handler):
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(thread.join, 2)
        self.addCleanup(server.shutdown)
        return server

    def write_json(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def write_registry(self):
        self.write_json(self.data / "inbox/inbox.json", self.registry)

    def request(self, path="/", login="owner@example.com", host="plannotator.example.ts.net", method="GET"):
        headers = {"Host": host}
        if login is not None:
            headers["Tailscale-User-Login"] = login
        connection = http.client.HTTPConnection("127.0.0.1", self.redirect.server_port, timeout=3)
        connection.request(method, path, headers=headers)
        response = connection.getresponse()
        result = response.status, dict(response.getheaders()), response.read()
        connection.close()
        return result

    def test_owner_redirect_and_head(self):
        status, headers, _ = self.request()
        self.assertEqual(status, 303)
        self.assertEqual(headers["Location"], self.registry["tailscale"]["url"])
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(self.request(method="HEAD")[2], b"")

    def test_identity_and_host_fail_closed(self):
        for login in (None, "stranger@example.com", ""):
            self.assertEqual(self.request(login=login)[0], 403)
        self.assertEqual(self.request(host="attacker.example")[0], 403)
        self.assertEqual(self.request(host=f"127.0.0.1:{self.redirect.server_port}")[0], 403)

    def test_never_proxies_agent_tools(self):
        self.assertEqual(self.request("/mcp")[0], 404)
        self.assertEqual(self.request("/mcp", method="POST")[0], 403)
        self.assertEqual(self.request("/api/inbox/control/stop", method="POST")[0], 403)

    def test_health_is_local_or_authenticated(self):
        self.assertEqual(self.request("/health", login=None, host=f"127.0.0.1:{self.redirect.server_port}")[0], 200)
        self.assertEqual(self.request("/health", login=None)[0], 403)
        self.assertEqual(self.request("/health")[0], 200)

    def test_rejects_arbitrary_redirect_targets(self):
        port = self.native.server_port
        for url in (
            f"https://evil.example:{port}/",
            f"http://kim.example.ts.net:{port}/",
            f"https://kim.example.ts.net:{port}/mcp",
            f"https://user:secret@kim.example.ts.net:{port}/",
            f"https://kim.example.ts.net:{port}/?next=evil",
            f"https://kim.example.ts.net:{port}/#fragment",
            f"https://kim.example.ts.net:{port}/\r\nInjected: header",
            "https://kim.example.ts.net:1/",
            "https://kim.example.ts.net:invalid/",
            None,
        ):
            with self.subTest(url=url):
                self.registry["tailscale"]["url"] = url
                self.write_registry()
                status, headers, _ = self.request()
                self.assertEqual(status, 503)
                self.assertNotIn("Location", headers)

    def test_stale_registry_and_health_redirect_are_unavailable(self):
        self.health["serverSession"] = "other-process"
        self.assertEqual(self.request()[0], 503)
        self.health = "redirect"
        self.assertEqual(self.request()[0], 503)
        self.registry["port"] = True
        self.write_registry()
        self.assertEqual(self.request()[0], 503)

    def test_doctor_versions_and_no_secret_output(self):
        self.write_json(self.home / ".pi/agent/npm/node_modules/@plannotator/pi-extension/package.json", {"version": "0.28.23"})
        self.write_json(self.home / ".claude/plugins/installed_plugins.json", {"plugins": {"plannotator@plannotator": [{"scope": "user", "version": "0.28.23"}]}})
        self.write_json(self.home / ".config/opencode/opencode.json", {"plugins": [{"package": "@plannotator/opencode@0.28.23"}]})
        server = {"command": "plannotator", "args": ["inbox", "mcp"], "env": {"SECRET": "do-not-print"}}
        for path, key in ((".config/amp/settings.json", "amp.mcpServers"), (".config/muse/settings.json", "mcpServers")):
            self.write_json(self.home / path, {key: {"plannotator-inbox": server}})
        for path in (".codex/config.toml", ".grok/config.toml"):
            file = self.home / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('[mcp_servers.plannotator-inbox]\ncommand="plannotator"\nargs=["inbox","mcp"]\n')
        resolve = inbox.socket.getaddrinfo
        with patch.object(inbox.subprocess, "check_output", return_value="plannotator 0.28.23\n"), patch.object(inbox.socket, "getaddrinfo", side_effect=lambda host, port, *a, **kw: [] if host == "plannotator.example.ts.net" else resolve(host, port, *a, **kw)):
            report = inbox.doctor(self.home, self.data, "kim", "0.28.23", "fixture", "kim.example.ts.net", "plannotator.example.ts.net", self.redirect.server_port)
        self.assertTrue(report["ok"])
        self.assertNotIn("do-not-print", json.dumps(report))
        self.assertNotIn("fixture-session", json.dumps(report))
        self.write_json(self.home / ".pi/agent/npm/node_modules/@plannotator/pi-extension/package.json", {"version": "old"})
        with patch.object(inbox.subprocess, "check_output", return_value="plannotator 0.28.23\n"):
            report = inbox.doctor(self.home, self.data, "kim", "0.28.23", "fixture", "kim.example.ts.net")
        self.assertFalse(report["ok"])
        self.assertFalse(report["checks"]["pi_extension"]["ok"])
        with patch.object(inbox.subprocess, "check_output", return_value="plannotator 0.28.23\n"), patch.object(inbox.socket, "getaddrinfo", side_effect=OSError("fixture DNS unavailable")):
            report = inbox.doctor(self.home, self.data, "kim", "0.28.23", "fixture", "kim.example.ts.net", "plannotator.example.ts.net")
        self.assertFalse(report["checks"]["bookmark_dns"]["ok"])

    def test_headless_launcher_and_remote_doctor(self):
        env = {"INBOX_HOST": "kim", "PLANNOTATOR_BIN": "fixture", "INBOX_KIM_URL": "https://plannotator.example.ts.net", "INBOX_KIM_HOST": "kim.example.ts.net", "FLEET_BIN": "fleet"}
        with patch.dict(os.environ, env, clear=True), patch.object(inbox.sys, "platform", "linux"), patch.object(inbox.sys, "argv", ["inbox"]), patch.object(inbox.subprocess, "call") as call, contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(inbox.main(), 0)
            call.assert_not_called()
            self.assertEqual(output.getvalue().strip(), env["INBOX_KIM_URL"])
        with patch.dict(os.environ, env, clear=True), patch.object(inbox.sys, "argv", ["inbox", "doctor", "joyce"]), patch.object(inbox.subprocess, "call", return_value=0) as call:
            self.assertEqual(inbox.main(), 0)
            call.assert_called_once_with(["fleet", "run", "joyce", "~/.local/bin/inbox", "doctor", "local", "--json"])


if __name__ == "__main__":
    unittest.main()
