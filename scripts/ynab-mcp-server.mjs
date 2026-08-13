#!/usr/bin/env node

import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { isAbsolute } from "node:path";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";
import readline from "node:readline";

const execFileAsync = promisify(execFile);

const YNAB_API_ORIGIN = "https://api.ynab.com";
const YNAB_API_BASE_PATH = "/v1";
const MAX_RESPONSE_BYTES = 8 * 1024 * 1024;
const MAX_REQUEST_BYTES = 1024 * 1024;
const REQUEST_TIMEOUT_MS = 30_000;
const ALLOWED_METHODS = new Set(["GET", "POST", "PUT", "PATCH", "DELETE"]);
const SUPPORTED_PROTOCOL_VERSIONS = new Set([
  "2024-11-05",
  "2025-03-26",
  "2025-06-18",
]);

const operationCatalog = JSON.parse(
  await readFile(new URL("./ynab-mcp-operations.json", import.meta.url), "utf8"),
);
const YNAB_OPERATIONS = operationCatalog.operations;

export const YNAB_MCP_TOOLS = YNAB_OPERATIONS.map((operation) => ({
  name: operation.name,
  description: `${operation.description} ${operation.readOnly ? "Read-only." : "Writes to YNAB and requires explicit approval."}`,
  inputSchema: operation.inputSchema,
  annotations: {
    title: operation.summary,
    readOnlyHint: operation.readOnly,
    destructiveHint: operation.destructive,
    idempotentHint: operation.idempotent,
    openWorldHint: true,
  },
}));

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validatePlanId(value) {
  if (value !== "default" && value !== "last-used" && (typeof value !== "string" || !UUID_PATTERN.test(value))) {
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

function validateResourceId(value) {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new YnabMcpError("YNAB MCP invalid resource ID", "invalid_resource_id");
  }
  return value;
}

function validateMonth(value) {
  if (value === "current") return value;
  if (validateIsoDate(value).slice(8) !== "01") {
    throw new YnabMcpError("YNAB MCP month must use the first day", "invalid_month");
  }
  return value;
}

function validateParameter(parameter, value) {
  if (parameter.apiName === "plan_id") return validatePlanId(value);
  if (parameter.apiName === "month") return validateMonth(value);
  if (parameter.apiName.endsWith("_id")) return validateResourceId(value);
  if (parameter.apiName === "since_date" || parameter.apiName === "until_date") return validateIsoDate(value);
  if (parameter.apiName === "last_knowledge_of_server") {
    if (!Number.isSafeInteger(value) || value < 0) {
      throw new YnabMcpError("YNAB MCP invalid server knowledge", "invalid_server_knowledge");
    }
    return String(value);
  }
  if (parameter.apiName === "include_accounts") {
    if (typeof value !== "boolean") {
      throw new YnabMcpError("YNAB MCP invalid boolean parameter", "invalid_boolean");
    }
    return String(value);
  }
  if (parameter.apiName === "type") {
    if (value !== "uncategorized" && value !== "unapproved") {
      throw new YnabMcpError("YNAB MCP invalid transaction type", "invalid_transaction_type");
    }
    return value;
  }
  throw new YnabMcpError("YNAB MCP unsupported endpoint parameter", "unsupported_parameter");
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

function buildOperationRequest(operation, rawInput) {
  const input = requireObject(rawInput);
  const allowedKeys = new Set(Object.keys(operation.inputSchema.properties));
  assertOnlyKeys(input, allowedKeys);
  for (const requiredKey of operation.inputSchema.required) {
    if (!Object.hasOwn(input, requiredKey)) {
      throw new YnabMcpError("YNAB MCP missing required tool argument", "missing_argument");
    }
  }

  if (!operation.readOnly && (input.planId === "default" || input.planId === "last-used")) {
    throw new YnabMcpError("YNAB MCP writes require an explicit plan UUID", "explicit_plan_required");
  }

  const pathValues = new Map();
  const query = new URLSearchParams();
  for (const parameter of operation.parameters) {
    if (input[parameter.inputName] === undefined) continue;
    const value = validateParameter(parameter, input[parameter.inputName]);
    if (parameter.location === "path") pathValues.set(parameter.apiName, value);
    if (parameter.location === "query") query.set(parameter.apiName, value);
  }

  const pathSegments = operation.path.split("/").filter(Boolean).map((segment) => {
    const match = /^\{([^}]+)\}$/.exec(segment);
    return match ? pathValues.get(match[1]) : segment;
  });
  if (pathSegments.some((segment) => typeof segment !== "string")) {
    throw new YnabMcpError("YNAB MCP missing path argument", "missing_argument");
  }

  const body = operation.bodyKeys.length === 0
    ? undefined
    : Object.fromEntries(operation.bodyKeys.filter((key) => Object.hasOwn(input, key)).map((key) => [key, input[key]]));
  if (operation.name === "create_transactions" && (Object.hasOwn(body, "transaction") === Object.hasOwn(body, "transactions"))) {
    throw new YnabMcpError("YNAB MCP requires exactly one transaction payload", "invalid_transaction_payload");
  }
  if (body !== undefined && Buffer.byteLength(JSON.stringify(body), "utf8") > MAX_REQUEST_BYTES) {
    throw new YnabMcpError("YNAB MCP request exceeded size limit", "request_too_large");
  }
  return { pathSegments, query, body };
}

export function createYnabToolHandlers(apiClient, { allowWrites = process.env.YNAB_ALLOW_WRITES === "1" } = {}) {
  return new Map(YNAB_OPERATIONS.map((operation) => [operation.name, async (rawInput) => {
    if (!operation.readOnly && !allowWrites) {
      throw new YnabMcpError("YNAB MCP write tools are disabled", "writes_disabled");
    }
    const request = buildOperationRequest(operation, rawInput);
    return apiClient.request(operation.method, request.pathSegments, request);
  }]));
}

export function getYnabMcpTools({ allowWrites = process.env.YNAB_ALLOW_WRITES === "1" } = {}) {
  return allowWrites ? YNAB_MCP_TOOLS : YNAB_MCP_TOOLS.filter((tool) => tool.annotations.readOnlyHint);
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

  const request = async (method, pathSegments, { query = new URLSearchParams(), body } = {}) => {
    if (!ALLOWED_METHODS.has(method)) {
      throw new YnabMcpError("YNAB MCP unsupported HTTP method", "unsupported_method");
    }
    const token = await getToken();
    const path = pathSegments.map((segment) => encodeURIComponent(segment)).join("/");
    const url = new URL(`${YNAB_API_BASE_PATH}/${path}`, YNAB_API_ORIGIN);
    url.search = query.toString();
    const serializedBody = body === undefined ? undefined : JSON.stringify(body);
    if (serializedBody !== undefined && Buffer.byteLength(serializedBody, "utf8") > MAX_REQUEST_BYTES) {
      throw new YnabMcpError("YNAB MCP request exceeded size limit", "request_too_large");
    }

    const response = await fetchImpl(url, {
      method,
      headers: {
        Accept: "application/json",
        Authorization: `Bearer ${token}`,
        ...(serializedBody === undefined ? {} : { "Content-Type": "application/json" }),
      },
      ...(serializedBody === undefined ? {} : { body: serializedBody }),
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
  };

  return {
    request,
    get: (pathSegments, query = new URLSearchParams()) => request("GET", pathSegments, { query }),
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

export async function loadYnabToken(env = process.env, runCommand = execFileAsync, readTokenFile = readFile) {
  const tokenFile = env.YNAB_TOKEN_FILE;
  if (typeof tokenFile === "string" && tokenFile.length > 0) {
    if (!isAbsolute(tokenFile)) {
      throw new YnabMcpError("YNAB MCP token file path must be absolute", "invalid_ynab_token_file");
    }

    let contents;
    try {
      contents = await readTokenFile(tokenFile, "utf8");
    } catch {
      throw new YnabMcpError("YNAB MCP could not read the token file", "token_file_read_failed");
    }
    return validateYnabToken(contents, "token file");
  }

  const opPath = env.YNAB_OP_PATH;
  if (typeof opPath !== "string" || !opPath.startsWith("op://")) {
    throw new YnabMcpError("YNAB MCP requires YNAB_TOKEN_FILE or a 1Password secret reference", "missing_ynab_credentials");
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

  return validateYnabToken(stdout, "1Password");
}

function validateYnabToken(value, source) {
  const token = value.trim();
  if (token.length === 0 || Buffer.byteLength(token, "utf8") > 4096) {
    throw new YnabMcpError(`YNAB MCP received an invalid token from ${source}`, "invalid_ynab_token");
  }
  return token;
}

export function createYnabMcpServer({
  apiClient = createYnabApiClient(),
  allowWrites = process.env.YNAB_ALLOW_WRITES === "1",
} = {}) {
  const toolHandlers = createYnabToolHandlers(apiClient, { allowWrites });

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
            serverInfo: { name: "ynab-local", version: "2.0.0" },
            instructions: allowWrites
              ? "Local access to all official YNAB API v1.86.0 endpoints. Mutations require client approval."
              : "Local access to all official YNAB API v1.86.0 endpoints. Write tools are disabled unless YNAB_ALLOW_WRITES=1.",
          });
        }
        case "ping":
          return jsonRpcResult(message.id, {});
        case "tools/list":
          return jsonRpcResult(message.id, { tools: getYnabMcpTools({ allowWrites }) });
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
