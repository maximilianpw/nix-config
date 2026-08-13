#!/usr/bin/env node

import { execFile } from "node:child_process";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";
import readline from "node:readline";

const execFileAsync = promisify(execFile);

const YNAB_API_ORIGIN = "https://api.ynab.com";
const YNAB_API_BASE_PATH = "/v1";
const MAX_RESPONSE_BYTES = 8 * 1024 * 1024;
const REQUEST_TIMEOUT_MS = 30_000;
const SUPPORTED_PROTOCOL_VERSIONS = new Set([
  "2024-11-05",
  "2025-03-26",
  "2025-06-18",
]);

export const YNAB_MCP_TOOLS = [
  {
    name: "get_user",
    description: "Get the authenticated YNAB user. Read-only.",
    inputSchema: objectSchema({}),
    annotations: readOnlyAnnotations("Get YNAB user"),
  },
  {
    name: "list_plans",
    description: "List the authenticated user's YNAB plans. Read-only.",
    inputSchema: objectSchema({}),
    annotations: readOnlyAnnotations("List YNAB plans"),
  },
  {
    name: "list_accounts",
    description: "List accounts and balances for one YNAB plan. Read-only.",
    inputSchema: planInputSchema(),
    annotations: readOnlyAnnotations("List YNAB accounts"),
  },
  {
    name: "list_categories",
    description: "List category groups, categories, and balances for one YNAB plan. Read-only.",
    inputSchema: planInputSchema(),
    annotations: readOnlyAnnotations("List YNAB categories"),
  },
  {
    name: "list_months",
    description: "List monthly budget summaries for one YNAB plan. Read-only.",
    inputSchema: planInputSchema(),
    annotations: readOnlyAnnotations("List YNAB months"),
  },
  {
    name: "list_transactions",
    description: "List YNAB transactions on or after an ISO date, optionally filtered by status. Read-only.",
    inputSchema: objectSchema(
      {
        planId: planIdProperty(),
        sinceDate: {
          type: "string",
          format: "date",
          description: "Inclusive ISO 8601 date (YYYY-MM-DD). Required to bound the response.",
        },
        type: {
          type: "string",
          enum: ["uncategorized", "unapproved"],
          description: "Optional YNAB transaction status filter.",
        },
      },
      ["planId", "sinceDate"],
    ),
    annotations: readOnlyAnnotations("List YNAB transactions"),
  },
];

function objectSchema(properties, required = []) {
  return {
    type: "object",
    properties,
    required,
    additionalProperties: false,
  };
}

function planIdProperty() {
  return {
    type: "string",
    description: "YNAB plan UUID returned by list_plans.",
  };
}

function planInputSchema() {
  return objectSchema({ planId: planIdProperty() }, ["planId"]);
}

function readOnlyAnnotations(title) {
  return {
    title,
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: true,
  };
}

export function validatePlanId(value) {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
    throw new YnabMcpError("YNAB MCP invalid plan ID", "invalid_plan_id");
  }
  return value;
}

export function validateIsoDate(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new YnabMcpError("YNAB MCP invalid date", "invalid_date");
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw new YnabMcpError("YNAB MCP invalid date", "invalid_date");
  }
  return value;
}

function assertOnlyKeys(input, allowedKeys) {
  const unexpectedKeys = Object.keys(input).filter((key) => !allowedKeys.has(key));
  if (unexpectedKeys.length > 0) {
    throw new YnabMcpError("YNAB MCP unsupported tool argument", "unsupported_argument");
  }
}

function requireObject(value) {
  if (value === undefined) return {};
  if (value === null || Array.isArray(value) || typeof value !== "object") {
    throw new YnabMcpError("YNAB MCP tool arguments must be an object", "invalid_arguments");
  }
  return value;
}

export function createYnabToolHandlers(apiClient) {
  return new Map([
    ["get_user", async (rawInput) => {
      const input = requireObject(rawInput);
      assertOnlyKeys(input, new Set());
      return apiClient.get(["user"]);
    }],
    ["list_plans", async (rawInput) => {
      const input = requireObject(rawInput);
      assertOnlyKeys(input, new Set());
      return apiClient.get(["plans"]);
    }],
    ["list_accounts", async (rawInput) => {
      const input = requireObject(rawInput);
      assertOnlyKeys(input, new Set(["planId"]));
      return apiClient.get(["plans", validatePlanId(input.planId), "accounts"]);
    }],
    ["list_categories", async (rawInput) => {
      const input = requireObject(rawInput);
      assertOnlyKeys(input, new Set(["planId"]));
      return apiClient.get(["plans", validatePlanId(input.planId), "categories"]);
    }],
    ["list_months", async (rawInput) => {
      const input = requireObject(rawInput);
      assertOnlyKeys(input, new Set(["planId"]));
      return apiClient.get(["plans", validatePlanId(input.planId), "months"]);
    }],
    ["list_transactions", async (rawInput) => {
      const input = requireObject(rawInput);
      assertOnlyKeys(input, new Set(["planId", "sinceDate", "type"]));
      const query = new URLSearchParams({ since_date: validateIsoDate(input.sinceDate) });
      if (input.type !== undefined) {
        if (input.type !== "uncategorized" && input.type !== "unapproved") {
          throw new YnabMcpError("YNAB MCP invalid transaction type", "invalid_transaction_type");
        }
        query.set("type", input.type);
      }
      return apiClient.get(["plans", validatePlanId(input.planId), "transactions"], query);
    }],
  ]);
}

export function createYnabApiClient({ fetchImpl = globalThis.fetch, tokenLoader = loadYnabToken } = {}) {
  if (typeof fetchImpl !== "function") {
    throw new YnabMcpError("YNAB MCP fetch implementation unavailable", "fetch_unavailable");
  }

  let tokenPromise;
  const getToken = async () => {
    tokenPromise ??= Promise.resolve().then(tokenLoader);
    try {
      return await tokenPromise;
    } catch (error) {
      tokenPromise = undefined;
      throw error;
    }
  };

  return {
    async get(pathSegments, query = new URLSearchParams()) {
      const token = await getToken();
      const path = pathSegments.map((segment) => encodeURIComponent(segment)).join("/");
      const url = new URL(`${YNAB_API_BASE_PATH}/${path}`, YNAB_API_ORIGIN);
      url.search = query.toString();

      const response = await fetchImpl(url, {
        method: "GET",
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${token}`,
        },
        redirect: "error",
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });

      const contentLength = Number(response.headers.get("content-length"));
      if (Number.isFinite(contentLength) && contentLength > MAX_RESPONSE_BYTES) {
        throw new YnabMcpError("YNAB MCP response exceeded size limit", "response_too_large");
      }

      const responseText = await readBoundedResponseText(response, MAX_RESPONSE_BYTES);

      let responseBody;
      try {
        responseBody = responseText === "" ? null : JSON.parse(responseText);
      } catch {
        throw new YnabMcpError("YNAB MCP received invalid JSON", "invalid_api_response");
      }

      if (!response.ok) {
        const apiError = responseBody?.error;
        throw new YnabMcpError(
          `YNAB API request failed with HTTP ${response.status}`,
          "ynab_api_error",
          {
            status: response.status,
            apiErrorId: typeof apiError?.id === "string" ? apiError.id : undefined,
            apiErrorName: typeof apiError?.name === "string" ? apiError.name : undefined,
          },
        );
      }

      return responseBody;
    },
  };
}

export async function readBoundedResponseText(response, maxBytes) {
  if (response.body === null) return "";

  const reader = response.body.getReader();
  const chunks = [];
  let totalBytes = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    totalBytes += value.byteLength;
    if (totalBytes > maxBytes) {
      await reader.cancel();
      throw new YnabMcpError("YNAB MCP response exceeded size limit", "response_too_large");
    }
    chunks.push(Buffer.from(value));
  }

  return Buffer.concat(chunks, totalBytes).toString("utf8");
}

export async function loadYnabToken(env = process.env, runCommand = execFileAsync) {
  const opPath = env.YNAB_OP_PATH;
  if (typeof opPath !== "string" || !opPath.startsWith("op://")) {
    throw new YnabMcpError("YNAB MCP requires a 1Password secret reference", "missing_ynab_op_path");
  }

  let stdout;
  try {
    ({ stdout } = await runCommand("op", ["read", opPath], {
      encoding: "utf8",
      maxBuffer: 8 * 1024,
      timeout: 10_000,
      windowsHide: true,
    }));
  } catch {
    throw new YnabMcpError("YNAB MCP could not resolve the token from 1Password", "onepassword_lookup_failed");
  }

  const token = stdout.trim();
  if (token.length === 0 || Buffer.byteLength(token, "utf8") > 4096) {
    throw new YnabMcpError("YNAB MCP received an invalid token from 1Password", "invalid_ynab_token");
  }
  return token;
}

export function createYnabMcpServer({ apiClient = createYnabApiClient() } = {}) {
  const toolHandlers = createYnabToolHandlers(apiClient);

  return {
    async handle(message) {
      if (message === null || Array.isArray(message) || typeof message !== "object" || message.jsonrpc !== "2.0") {
        return jsonRpcError(message?.id ?? null, -32600, "Invalid Request");
      }

      const hasId = Object.hasOwn(message, "id");
      if (!hasId) {
        return null;
      }

      switch (message.method) {
        case "initialize": {
          const requestedVersion = message.params?.protocolVersion;
          const protocolVersion = SUPPORTED_PROTOCOL_VERSIONS.has(requestedVersion)
            ? requestedVersion
            : "2024-11-05";
          return jsonRpcResult(message.id, {
            protocolVersion,
            capabilities: { tools: { listChanged: false } },
            serverInfo: { name: "ynab-readonly", version: "1.0.0" },
            instructions: "Read-only local access to the official YNAB API. No create, update, import, or delete tools exist.",
          });
        }
        case "ping":
          return jsonRpcResult(message.id, {});
        case "tools/list":
          return jsonRpcResult(message.id, { tools: YNAB_MCP_TOOLS });
        case "tools/call": {
          const toolName = message.params?.name;
          const handler = toolHandlers.get(toolName);
          if (!handler) {
            return jsonRpcResult(message.id, toolErrorResult(
              new YnabMcpError("YNAB MCP unknown tool", "unknown_tool"),
            ));
          }
          try {
            const data = await handler(message.params?.arguments);
            return jsonRpcResult(message.id, {
              content: [{ type: "text", text: JSON.stringify(data) }],
              structuredContent: data,
              isError: false,
            });
          } catch (error) {
            return jsonRpcResult(message.id, toolErrorResult(error));
          }
        }
        default:
          return jsonRpcError(message.id, -32601, "Method not found");
      }
    },
  };
}

function toolErrorResult(error) {
  const safeError = error instanceof YnabMcpError
    ? error
    : new YnabMcpError("YNAB MCP request failed", "ynab_mcp_request_failed");
  const body = {
    error: {
      code: safeError.code,
      message: safeError.message,
      ...(safeError.details === undefined ? {} : { details: safeError.details }),
    },
  };
  return {
    content: [{ type: "text", text: JSON.stringify(body) }],
    structuredContent: body,
    isError: true,
  };
}

function jsonRpcResult(id, result) {
  return { jsonrpc: "2.0", id, result };
}

function jsonRpcError(id, code, message) {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

export class YnabMcpError extends Error {
  constructor(message, code, details) {
    super(message);
    this.name = "YnabMcpError";
    this.code = code;
    this.details = details;
  }
}

export async function runYnabMcpStdioServer({ input = process.stdin, output = process.stdout } = {}) {
  const server = createYnabMcpServer();
  const lines = readline.createInterface({ input, crlfDelay: Infinity, terminal: false });

  for await (const line of lines) {
    let request;
    try {
      request = JSON.parse(line);
    } catch {
      output.write(`${JSON.stringify(jsonRpcError(null, -32700, "Parse error"))}\n`);
      continue;
    }

    const response = await server.handle(request);
    if (response !== null) {
      output.write(`${JSON.stringify(response)}\n`);
    }
  }
}

function isMainModule() {
  return process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href;
}

if (isMainModule()) {
  runYnabMcpStdioServer().catch(() => {
    process.stderr.write("YNAB MCP server stopped after an unexpected error\n");
    process.exitCode = 1;
  });
}
