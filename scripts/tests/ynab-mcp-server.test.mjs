import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { createInterface } from "node:readline";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  YNAB_MCP_TOOLS,
  createYnabApiClient,
  createYnabMcpServer,
  createYnabToolHandlers,
  getYnabMcpTools,
  loadYnabToken,
  readBoundedResponseText,
  validateIsoDate,
  validatePlanId,
} from "../ynab-mcp-server.mjs";

const PLAN_ID = "12345678-1234-4234-8234-123456789abc";

test("exports every official YNAB v1.86.0 endpoint with accurate safety annotations", () => {
  assert.deepEqual(
    YNAB_MCP_TOOLS.map(({ name }) => name),
    [
      "get_user", "list_plans", "get_plan", "get_plan_settings", "list_accounts",
      "create_account", "get_account", "list_categories", "create_category", "get_category",
      "update_category", "get_month_category", "update_month_category", "create_category_group",
      "update_category_group", "list_payees", "create_payee", "get_payee", "update_payee",
      "list_payee_locations", "get_payee_location", "list_payee_locations_by_payee", "list_months",
      "get_month", "list_money_movements", "list_money_movements_by_month",
      "list_money_movement_groups", "list_money_movement_groups_by_month", "list_transactions",
      "create_transactions", "update_transactions", "import_transactions", "get_transaction",
      "update_transaction", "delete_transaction", "list_transactions_by_account",
      "list_transactions_by_category", "list_transactions_by_payee", "list_transactions_by_month",
      "list_scheduled_transactions", "create_scheduled_transaction", "get_scheduled_transaction",
      "update_scheduled_transaction", "delete_scheduled_transaction",
    ],
  );
  assert.equal(YNAB_MCP_TOOLS.filter((tool) => tool.annotations.readOnlyHint).length, 28);
  assert.equal(YNAB_MCP_TOOLS.filter((tool) => !tool.annotations.readOnlyHint).length, 16);
  for (const tool of YNAB_MCP_TOOLS) {
    assert.equal(tool.inputSchema.additionalProperties, false);
  }
  assert.equal(
    YNAB_MCP_TOOLS.find((tool) => tool.name === "delete_transaction").annotations.destructiveHint,
    true,
  );
  assert.deepEqual(
    YNAB_MCP_TOOLS.find((tool) => tool.name === "update_month_category")
      .inputSchema.properties.category.properties,
    {
      budgeted: {
        type: "integer",
        description: "Assigned (budgeted) amount in milliunits format",
        format: "int64",
      },
    },
  );
});

test("hides write tools unless writes are explicitly enabled", () => {
  assert.equal(getYnabMcpTools({ allowWrites: false }).length, 28);
  assert.equal(getYnabMcpTools({ allowWrites: true }).length, 44);
});

test("validates plan IDs and real ISO calendar dates", () => {
  assert.equal(validatePlanId(PLAN_ID), PLAN_ID);
  assert.equal(validateIsoDate("2026-02-28"), "2026-02-28");
  assert.throws(() => validatePlanId("../../transactions"), { code: "invalid_plan_id" });
  assert.throws(() => validateIsoDate("2026-02-30"), { code: "invalid_date" });
});

test("constructs only pinned HTTPS YNAB GET requests", async () => {
  const requests = [];
  const apiClient = createYnabApiClient({
    tokenLoader: async () => "secret-token",
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      return new Response(JSON.stringify({ data: { transactions: [] } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
  });
  const handlers = createYnabToolHandlers(apiClient);

  await handlers.get("list_transactions")({
    planId: PLAN_ID,
    sinceDate: "2026-01-01",
    type: "unapproved",
  });

  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].url.href,
    `https://api.ynab.com/v1/plans/${PLAN_ID}/transactions?since_date=2026-01-01&type=unapproved`,
  );
  assert.equal(requests[0].options.method, "GET");
  assert.equal(requests[0].options.redirect, "error");
  assert.equal(requests[0].options.headers.Authorization, "Bearer secret-token");
});

test("sends JSON mutations only to pinned YNAB paths", async () => {
  const requests = [];
  const apiClient = createYnabApiClient({
    tokenLoader: async () => "secret-token",
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      return new Response(JSON.stringify({ data: { category: { budgeted: 250000 } } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
  });

  await apiClient.request(
    "PATCH",
    ["plans", PLAN_ID, "months", "2026-08-01", "categories", PLAN_ID],
    { body: { category: { budgeted: 250000 } } },
  );

  assert.equal(
    requests[0].url.href,
    `https://api.ynab.com/v1/plans/${PLAN_ID}/months/2026-08-01/categories/${PLAN_ID}`,
  );
  assert.equal(requests[0].options.method, "PATCH");
  assert.equal(requests[0].options.headers["Content-Type"], "application/json");
  assert.equal(requests[0].options.body, JSON.stringify({ category: { budgeted: 250000 } }));
});

test("rejects oversized streaming responses before reading the full body", async () => {
  let cancelled = false;
  const response = {
    body: new ReadableStream({
      pull(controller) {
        controller.enqueue(new Uint8Array(4));
      },
      cancel() {
        cancelled = true;
      },
    }),
  };

  await assert.rejects(() => readBoundedResponseText(response, 7), { code: "response_too_large" });
  assert.equal(cancelled, true);
});

test("rejects unsupported tool arguments before making an API request", async () => {
  let requestCount = 0;
  const handlers = createYnabToolHandlers({
    async request() {
      requestCount += 1;
      return {};
    },
  });

  await assert.rejects(
    () => handlers.get("list_accounts")({ planId: PLAN_ID, writeAccess: true }),
    { code: "unsupported_argument" },
  );
  assert.equal(requestCount, 0);
});

test("keeps mutations disabled by default", async () => {
  let requestCount = 0;
  const handlers = createYnabToolHandlers({
    async request() {
      requestCount += 1;
      return {};
    },
  }, { allowWrites: false });

  await assert.rejects(
    () => handlers.get("update_month_category")({
      planId: PLAN_ID,
      month: "2026-08-01",
      categoryId: PLAN_ID,
      category: { budgeted: 250000 },
    }),
    { code: "writes_disabled" },
  );
  assert.equal(requestCount, 0);
});

test("requires an explicit plan UUID for writes", async () => {
  const handlers = createYnabToolHandlers({
    async request() {
      throw new Error("request should not run");
    },
  }, { allowWrites: true });

  await assert.rejects(
    () => handlers.get("import_transactions")({ planId: "last-used" }),
    { code: "explicit_plan_required" },
  );
});

test("maps an approved monthly budget update to the pinned YNAB endpoint", async () => {
  const requests = [];
  const handlers = createYnabToolHandlers({
    async request(...args) {
      requests.push(args);
      return { data: { category: { budgeted: 250000 } } };
    },
  }, { allowWrites: true });

  await handlers.get("update_month_category")({
    planId: PLAN_ID,
    month: "2026-08-01",
    categoryId: PLAN_ID,
    category: { budgeted: 250000 },
  });

  assert.equal(requests[0][0], "PATCH");
  assert.deepEqual(requests[0][1], ["plans", PLAN_ID, "months", "2026-08-01", "categories", PLAN_ID]);
  assert.deepEqual(requests[0][2].body, { category: { budgeted: 250000 } });
});

test("caches a resolved token without exposing it in API errors", async () => {
  let tokenLoads = 0;
  const apiClient = createYnabApiClient({
    tokenLoader: async () => {
      tokenLoads += 1;
      return "must-not-leak";
    },
    fetchImpl: async () => new Response(
      JSON.stringify({ error: { id: "401", name: "not_authorized", detail: "Nope" } }),
      { status: 401 },
    ),
  });

  await assert.rejects(() => apiClient.get(["user"]), (error) => {
    assert.equal(error.code, "ynab_api_error");
    assert.equal(error.details.status, 401);
    assert.equal(JSON.stringify(error).includes("must-not-leak"), false);
    return true;
  });
  await assert.rejects(() => apiClient.get(["plans"]));
  assert.equal(tokenLoads, 1);
});

test("loads tokens from an absolute private file without invoking op", async () => {
  const commandCalls = [];
  const fileCalls = [];
  const token = await loadYnabToken(
    { YNAB_TOKEN_FILE: "/run/user/1000/ynab-token" },
    async (...args) => commandCalls.push(args),
    async (...args) => {
      fileCalls.push(args);
      return "token-value\n";
    },
  );

  assert.equal(token, "token-value");
  assert.deepEqual(fileCalls, [["/run/user/1000/ynab-token", "utf8"]]);
  assert.deepEqual(commandCalls, []);
  await assert.rejects(
    () => loadYnabToken({ YNAB_TOKEN_FILE: "relative-token" }),
    { code: "invalid_ynab_token_file" },
  );
});

test("resolves tokens through op without invoking a shell", async () => {
  const calls = [];
  const token = await loadYnabToken(
    { YNAB_OP_PATH: "op://Personal/YNAB/token" },
    async (...args) => {
      calls.push(args);
      return { stdout: "token-value\n", stderr: "" };
    },
  );

  assert.equal(token, "token-value");
  assert.equal(calls[0][0], "op");
  assert.deepEqual(calls[0][1], ["read", "op://Personal/YNAB/token"]);
  assert.equal(Object.hasOwn(calls[0][2], "shell"), false);
});

test("returns sanitized MCP tool errors", async () => {
  const server = createYnabMcpServer({
    apiClient: {
      async get() {
        throw new Error("Bearer secret-token");
      },
    },
  });

  const response = await server.handle({
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: { name: "get_user", arguments: {} },
  });

  assert.equal(response.result.isError, true);
  assert.equal(response.result.content[0].text.includes("secret-token"), false);
  assert.match(response.result.content[0].text, /ynab_mcp_request_failed/);
});

test("speaks newline-delimited MCP over stdio without authentication during discovery", async (context) => {
  const child = spawn(process.execPath, [fileURLToPath(new URL("../ynab-mcp-server.mjs", import.meta.url))], {
    env: { PATH: process.env.PATH },
    stdio: ["pipe", "pipe", "pipe"],
  });
  context.after(() => child.kill());

  const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
  const responses = [];
  lines.on("line", (line) => responses.push(JSON.parse(line)));

  child.stdin.write(`${JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: { protocolVersion: "2025-06-18" },
  })}\n`);
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" })}\n`);
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} })}\n`);
  child.stdin.end();

  await once(child, "exit");
  assert.equal(child.exitCode, 0);
  assert.equal(responses.length, 2);
  assert.equal(responses[0].result.protocolVersion, "2025-06-18");
  assert.equal(responses[1].result.tools.length, 28);
  assert.equal(responses[1].result.tools.every((tool) => tool.annotations.readOnlyHint), true);
});
