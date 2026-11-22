import * as Cloudflare from "@alchemy.run/cloudflare";
import * as Alchemy from "alchemy";
import { Stage } from "alchemy/Stage";
import { localState } from "alchemy/State";
import * as Effect from "effect/Effect";
import { fileURLToPath } from "node:url";
import { loadDnsInventory } from "./src/DnsInventory.ts";

const flakeRoot = fileURLToPath(new URL("../..", import.meta.url));

export default Alchemy.Stack(
  "HomelabCloudflare",
  {
    providers: Cloudflare.providers(),
    // Cloudflare.state() would deploy a state-store Worker into the account on
    // the first plan. Local state is enough for one operator; if it is lost,
    // `pnpm run deploy --adopt` re-adopts the existing CNAMEs by name.
    state: localState(),
  },
  Effect.gen(function* () {
    const stage = yield* Stage;
    if (stage !== "production") {
      return yield* Effect.die(
        `HomelabCloudflare manages fixed public hostnames; run it with --stage production, not ${stage}`,
      );
    }

    const inventory = yield* loadDnsInventory(flakeRoot).pipe(Effect.orDie);
    const zone = Cloudflare.Zone.Zone.lookup({ name: inventory.zone });

    for (const hostname of inventory.hostnames) {
      yield* Cloudflare.DNS.Record(hostname, {
        zoneId: zone.zoneId,
        name: hostname,
        type: "CNAME",
        content: `${inventory.tunnelId}.cfargotunnel.com`,
        proxied: true,
      });
    }
  }),
);
