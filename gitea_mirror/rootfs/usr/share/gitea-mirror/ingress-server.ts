// Serves the application behind Home Assistant's ingress.
//
// The official image starts scripts/runtime-server.ts, which expects every request to carry the
// base path. Ingress removes that path before it forwards a request, so this server takes
// requests as they come and still removes the path where it is present (the application
// calls its own MCP endpoint with it). The application builds all of its links from BASE_URL.
//
// Only Home Assistant's ingress proxy and the container itself may talk to the application: it
// trusts the user headers the proxy adds.
import { createServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";

const INGRESS_PROXY = "172.30.32.2";
const ALLOWED_ADDRESSES = new Set([
  INGRESS_PROXY,
  `::ffff:${INGRESS_PROXY}`,
  "127.0.0.1",
  "::ffff:127.0.0.1",
  "::1",
]);

function normalizeBasePath(basePath: string | undefined): string {
  const trimmed = (basePath ?? "").trim().replace(/\/+$/, "");
  if (!trimmed) {
    return "";
  }
  return trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
}

function withoutBasePath(url: string, basePath: string): string {
  if (!basePath) {
    return url;
  }
  if (url === basePath || url.startsWith(`${basePath}/`) || url.startsWith(`${basePath}?`)) {
    return url.slice(basePath.length) || "/";
  }
  return url;
}

const basePath = normalizeBasePath(process.env.BASE_URL);
const host = process.env.HOST || "0.0.0.0";
const port = Number.parseInt(process.env.PORT || "8099", 10);

process.env.ASTRO_NODE_AUTOSTART = "disabled";
const appDirectory = process.env.APP_DIR || "/app";
const { handler } = await import(`${appDirectory}/dist/server/entry.mjs`);

const server = createServer((request: IncomingMessage, response: ServerResponse) => {
  if (!ALLOWED_ADDRESSES.has(request.socket.remoteAddress ?? "")) {
    response.statusCode = 403;
    response.end("Forbidden");
    return;
  }

  request.url = withoutBasePath(request.url ?? "/", basePath);

  Promise.resolve((handler as (req: IncomingMessage, res: ServerResponse) => unknown)(request, response)).catch((error) => {
    console.error("Unhandled server error:", error);
    if (!response.headersSent) {
      response.statusCode = 500;
      response.end("Internal Server Error");
    } else {
      response.end();
    }
  });
});

server.listen(port, host, () => {
  console.log(`Gitea Mirror listening on http://${host}:${port} (BASE_URL=${basePath || "/"})`);
});
