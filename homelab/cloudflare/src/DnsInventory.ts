import * as Data from "effect/Data";
import * as Effect from "effect/Effect";
import * as ChildProcess from "effect/process/ChildProcess";
import { ChildProcessSpawner } from "effect/process/ChildProcessSpawner";
import * as Schema from "effect/Schema";
import * as Stream from "effect/Stream";

export const DnsInventory = Schema.Struct({
  zone: Schema.String.check(Schema.isPattern(/^[a-z0-9-]+(\.[a-z0-9-]+)+$/)),
  tunnelId: Schema.String.check(Schema.isUUID()),
  hostnames: Schema.Array(Schema.String),
}).check(
  Schema.makeFilter(({ zone, hostnames }) => {
    const outside = hostnames.filter((hostname) => !hostname.endsWith(`.${zone}`));
    return outside.length === 0 ? undefined : `hostnames outside zone ${zone}: ${outside.join(", ")}`;
  }),
);
export type DnsInventory = typeof DnsInventory.Type;

export const decodeDnsInventory = Schema.decodeUnknownEffect(Schema.fromJsonString(DnsInventory));

export class NixEvalFailed extends Data.TaggedError("NixEvalFailed")<{
  readonly installable: string;
  readonly exitCode: number;
}> {}

export const loadDnsInventory = Effect.fn("loadDnsInventory")(function* (flakeRoot: string) {
  const spawner = yield* ChildProcessSpawner;
  const installable = `${flakeRoot}#lib.cloudflareDns`;
  const json = yield* Effect.scoped(
    Effect.gen(function* () {
      const handle = yield* spawner.spawn(
        ChildProcess.make("nix", ["eval", "--json", installable], {
          stdin: "ignore",
          stdout: "pipe",
          stderr: "inherit",
        }),
      );
      const [stdout, exitCode] = yield* Effect.all(
        [handle.stdout.pipe(Stream.decodeText(), Stream.mkString), handle.exitCode],
        { concurrency: "unbounded" },
      );
      if (exitCode !== 0) return yield* new NixEvalFailed({ installable, exitCode });
      return stdout;
    }),
  );
  return yield* decodeDnsInventory(json);
});
