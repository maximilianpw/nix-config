import * as NodeServices from "@effect/platform-node/NodeServices";
import * as Effect from "effect/Effect";
import * as Exit from "effect/Exit";
import assert from "node:assert/strict";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { decodeDnsInventory, loadDnsInventory } from "./DnsInventory.ts";

const tunnelId = "5b712ae4-3ce4-4499-9cb7-a57cde1c571f";
const decode = (value: unknown) => Effect.runSyncExit(decodeDnsInventory(JSON.stringify(value)));

test("accepts hostnames inside the zone", () => {
  const exit = decode({ zone: "example.com", tunnelId, hostnames: ["a.example.com", "b.example.com"] });
  assert.deepEqual(exit, Exit.succeed({ zone: "example.com", tunnelId, hostnames: ["a.example.com", "b.example.com"] }));
});

test("rejects a hostname outside the zone", () => {
  const exit = decode({ zone: "example.com", tunnelId, hostnames: ["a.example.com", "a.example.org"] });
  assert.ok(Exit.isFailure(exit));
  assert.match(String(exit.cause), /a\.example\.org/);
});

test("rejects a hostname that only shares the zone suffix", () => {
  assert.ok(Exit.isFailure(decode({ zone: "example.com", tunnelId, hostnames: ["badexample.com"] })));
});

test("rejects a malformed tunnel id", () => {
  assert.ok(Exit.isFailure(decode({ zone: "example.com", tunnelId: "not-a-uuid", hostnames: [] })));
});

test("loads the inventory this flake exports", async () => {
  const flakeRoot = fileURLToPath(new URL("../../..", import.meta.url));
  const inventory = await Effect.runPromise(loadDnsInventory(flakeRoot).pipe(Effect.provide(NodeServices.layer)));
  assert.equal(inventory.zone, "maximilian.pw");
  assert.ok(inventory.hostnames.includes("nextcloud.maximilian.pw"));
});
