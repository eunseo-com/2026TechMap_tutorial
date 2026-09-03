#!/usr/bin/env node

import { createReadStream } from "node:fs";
import { readFile, readdir, stat } from "node:fs/promises";
import { createServer } from "node:http";
import path from "node:path";
import process from "node:process";
import AxeBuilder from "@axe-core/playwright";
import { chromium } from "playwright";

const HOSTING_BASE_PATH = "/2026TechMap_tutorial";
const DEFAULT_ROUTE_EXPECTATIONS = {
  "/": {
    h1: "돼지와 함께 두 세계의 경계를 건너기",
    redirectsTo: "/tutorials/scenekittorealitykit/",
  },
  "/documentation/scenekittorealitykit/": {
    h1: "SceneKit에서 RealityKit으로",
  },
  "/documentation/scenekittorealitykit/devicecameradiagnostics/": {
    h1: "실기기 카메라 진단 — 레이아웃, 세션과 준비 상태 분리",
  },
  "/documentation/scenekittorealitykit/migrationworksheet/": {
    h1: "SceneKit에서 RealityKit으로 — 세계관 번역 워크시트",
  },
  "/documentation/scenekittorealitykit/realitykitecs/": {
    h1: "RealityKit 심화 — 관찰, Entity와 cycle의 책임",
  },
  "/documentation/scenekittorealitykit/scenegraphdeepdive/": {
    h1: "SceneKit 심화 — C3 섬의 노드 트리와 입력 경계",
  },
  "/tutorials/scenekittorealitykit/": {
    h1: "돼지와 함께 두 세계의 경계를 건너기",
  },
  "/tutorials/scenekittorealitykit/01-closedworld/": {
    h1: "Chapter 1 — C3의 닫힌 세계",
  },
  "/tutorials/scenekittorealitykit/02-openingthedoor/": {
    h1: "Chapter 2 — 현실로 문 열기",
  },
  "/tutorials/scenekittorealitykit/03-realhideandseek/": {
    h1: "Chapter 3 — 진짜 숨바꼭질",
  },
  "/tutorials/scenekittorealitykit/04-comparison/": {
    h1: "Chapter 4 — 두 세계의 책임 비교하기",
  },
};
const RENDER_PROFILES = [
  { name: "desktop-light", colorScheme: "light", viewport: { width: 1440, height: 900 } },
  { name: "desktop-dark", colorScheme: "dark", viewport: { width: 1440, height: 900 } },
  { name: "mobile-light", colorScheme: "light", viewport: { width: 390, height: 844 } },
  { name: "mobile-dark", colorScheme: "dark", viewport: { width: 390, height: 844 } },
];
const MIME_TYPES = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".ico", "image/x-icon"],
  [".jpeg", "image/jpeg"],
  [".jpg", "image/jpeg"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".woff", "font/woff"],
  [".woff2", "font/woff2"],
]);

function usage() {
  console.error(
    "usage: node scripts/verify-docc-browser.mjs <DocC-archive-path> [route-expectations-json]",
  );
}

async function loadRouteExpectations(expectationsPath) {
  if (!expectationsPath) return DEFAULT_ROUTE_EXPECTATIONS;
  const expectations = JSON.parse(await readFile(path.resolve(expectationsPath), "utf8"));
  if (!expectations || Array.isArray(expectations) || typeof expectations !== "object") {
    throw new Error("route expectations must be a JSON object");
  }
  for (const [route, expectation] of Object.entries(expectations)) {
    if (!route.startsWith("/") || (route !== "/" && !route.endsWith("/"))) {
      throw new Error(`expected route must be canonical and end in '/': ${route}`);
    }
    if (!expectation || typeof expectation !== "object" || typeof expectation.h1 !== "string") {
      throw new Error(`expected route must provide an h1 string: ${route}`);
    }
  }
  return expectations;
}

async function discoverPublicRoutes(archivePath) {
  const routes = [];

  async function walk(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
    for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await walk(entryPath);
      } else if (entry.isFile() && entry.name === "index.html") {
        const relativePath = path.relative(archivePath, entryPath).split(path.sep).join("/");
        const route = `/${relativePath.slice(0, -"index.html".length)}`;
        routes.push(route);
      }
    }
  }

  await walk(archivePath);
  return routes.sort((left, right) => {
    if (left === "/") return -1;
    if (right === "/") return 1;
    return left.localeCompare(right);
  });
}

function createStaticServer(archivePath) {
  const archiveRoot = path.resolve(archivePath);
  const archivePrefix = `${archiveRoot}${path.sep}`;

  return createServer(async (request, response) => {
    try {
      if (request.method !== "GET" && request.method !== "HEAD") {
        response.writeHead(405, { Allow: "GET, HEAD" });
        response.end();
        return;
      }

      const requestURL = new URL(request.url ?? "/", "http://127.0.0.1");
      if (
        requestURL.pathname !== HOSTING_BASE_PATH
        && !requestURL.pathname.startsWith(`${HOSTING_BASE_PATH}/`)
      ) {
        response.writeHead(404);
        response.end("Not found");
        return;
      }
      if (requestURL.pathname === HOSTING_BASE_PATH) {
        response.writeHead(301, {
          Location: `${HOSTING_BASE_PATH}/${requestURL.search}`,
        });
        response.end();
        return;
      }

      let relativePath = decodeURIComponent(requestURL.pathname.slice(HOSTING_BASE_PATH.length));
      if (relativePath.endsWith("/")) relativePath += "index.html";
      if (!relativePath) relativePath = "/index.html";

      const candidate = path.resolve(archiveRoot, `.${relativePath}`);
      if (candidate !== archiveRoot && !candidate.startsWith(archivePrefix)) {
        response.writeHead(403);
        response.end("Forbidden");
        return;
      }

      const candidateStat = await stat(candidate).catch(() => undefined);
      if (candidateStat?.isDirectory()) {
        response.writeHead(301, {
          Location: `${requestURL.pathname}/${requestURL.search}`,
        });
        response.end();
        return;
      }
      if (!candidateStat?.isFile()) {
        response.writeHead(404);
        response.end("Not found");
        return;
      }

      response.writeHead(200, {
        "Cache-Control": "no-store",
        "Content-Type": MIME_TYPES.get(path.extname(candidate).toLowerCase()) ?? "application/octet-stream",
      });
      if (request.method === "HEAD") {
        response.end();
      } else {
        createReadStream(candidate).pipe(response);
      }
    } catch (error) {
      response.writeHead(500);
      response.end(error instanceof Error ? error.message : String(error));
    }
  });
}

function routeForPathname(pathname, routeExpectations) {
  if (pathname === HOSTING_BASE_PATH) return "/";
  if (!pathname.startsWith(`${HOSTING_BASE_PATH}/`)) return undefined;

  const publicPath = pathname.slice(HOSTING_BASE_PATH.length);
  if (routeExpectations[publicPath]) return publicPath;
  if (!publicPath.endsWith("/") && routeExpectations[`${publicPath}/`]) return `${publicPath}/`;
  return undefined;
}

function fragmentCandidates(hash) {
  if (!hash || hash === "#") return [];
  const raw = hash.slice(1);
  try {
    return [...new Set([raw, decodeURIComponent(raw)])];
  } catch {
    return [raw];
  }
}

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("static server did not expose a TCP port");
  return `http://127.0.0.1:${address.port}${HOSTING_BASE_PATH}`;
}

async function closeServer(server) {
  if (!server.listening) return;
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

async function main() {
  if (process.argv.length < 3 || process.argv.length > 4) {
    usage();
    process.exitCode = 64;
    return;
  }

  const archivePath = path.resolve(process.argv[2]);
  const routeExpectations = await loadRouteExpectations(process.argv[3]);
  const archiveStat = await stat(archivePath).catch(() => undefined);
  if (!archiveStat?.isDirectory()) {
    console.error(`error: DocC archive does not exist: ${archivePath}`);
    process.exitCode = 1;
    return;
  }

  const routes = await discoverPublicRoutes(archivePath);
  if (routes.length === 0) {
    console.error(`error: no public index.html routes found in ${archivePath}`);
    process.exitCode = 1;
    return;
  }

  if (Object.keys(routeExpectations).length === 0) {
    console.error("error: route expectations must not be empty");
    process.exitCode = 1;
    return;
  }
  const expectedRoutes = Object.keys(routeExpectations).sort();
  const missingRoutes = expectedRoutes.filter((route) => !routes.includes(route));
  const unexpectedRoutes = routes.filter((route) => !expectedRoutes.includes(route));
  if (missingRoutes.length > 0 || unexpectedRoutes.length > 0) {
    if (missingRoutes.length > 0) {
      console.error(`error: expected public routes are missing: ${missingRoutes.join(", ")}`);
    }
    if (unexpectedRoutes.length > 0) {
      console.error(`error: unexpected public routes were discovered: ${unexpectedRoutes.join(", ")}`);
    }
    process.exitCode = 1;
    return;
  }

  const server = createStaticServer(archivePath);
  let browser;
  try {
    const baseURL = await listen(server);
    const siteOrigin = new URL(baseURL).origin;
    browser = await chromium.launch({ headless: true });
    const issues = [];
    const allInternalLinks = new Set();

    for (const viewport of RENDER_PROFILES) {
      const renderedIDs = new Map();
      const profileInternalLinks = new Set();
      const context = await browser.newContext({
        colorScheme: viewport.colorScheme,
        viewport: viewport.viewport,
      });
      try {
        for (const route of routes) {
          const page = await context.newPage();
          try {
            page.on("console", (message) => {
              if (["assert", "error", "warning"].includes(message.type())) {
                issues.push(`[${viewport.name}] ${route} console.${message.type()}: ${message.text()}`);
              }
            });
            page.on("pageerror", (error) => {
              issues.push(`[${viewport.name}] ${route} page error: ${error.message}`);
            });
            page.on("requestfailed", (request) => {
              const failure = request.failure();
              issues.push(
                `[${viewport.name}] ${route} network request failed: ${request.url()} (${failure?.errorText ?? "unknown error"})`,
              );
            });
            page.on("response", (response) => {
              if (response.status() >= 400) {
                issues.push(
                  `[${viewport.name}] ${route} network response ${response.status()}: ${response.url()}`,
                );
              }
            });
            await page.goto(`${baseURL}${route}`, { waitUntil: "networkidle", timeout: 30_000 });
            const expectedRedirect = routeExpectations[route].redirectsTo;
            if (expectedRedirect) {
              const renderedPath = new URL(page.url()).pathname;
              const expectedPath = `${HOSTING_BASE_PATH}${expectedRedirect}`;
              if (renderedPath !== expectedPath) {
                issues.push(
                  `[${viewport.name}] ${route} root redirect expected ${expectedPath}, rendered ${renderedPath}`,
                );
              }
            }
            const heading = page.locator("h1").first();
            await heading.waitFor({ state: "visible", timeout: 15_000 });
            const renderedHeading = (await heading.innerText()).trim();
            const expectedHeading = routeExpectations[route].h1;
            if (renderedHeading !== expectedHeading) {
              issues.push(
                `[${viewport.name}] ${route} expected h1 ${JSON.stringify(expectedHeading)}, rendered ${JSON.stringify(renderedHeading)}`,
              );
            }
            const finalRoute = routeForPathname(new URL(page.url()).pathname, routeExpectations);
            if (finalRoute) {
              renderedIDs.set(
                finalRoute,
                new Set(await page.locator("[id]").evaluateAll((elements) => elements.map((element) => element.id))),
              );
            }
            const renderedLinks = await page.locator("a[href]").evaluateAll(
              (elements) => elements.map((element) => element.href),
            );
            for (const href of renderedLinks) {
              const link = new URL(href);
              if (link.origin !== siteOrigin) continue;
              profileInternalLinks.add(link.href);
              allInternalLinks.add(link.href);
              if (
                link.pathname !== HOSTING_BASE_PATH
                && !link.pathname.startsWith(`${HOSTING_BASE_PATH}/`)
              ) {
                issues.push(
                  `[${viewport.name}] ${route} same-origin link escapes the hosting base path: ${link.href}`,
                );
              }
            }
            const accessibility = await new AxeBuilder({ page }).analyze();
            for (const violation of accessibility.violations) {
              if (violation.impact !== "serious" && violation.impact !== "critical") continue;
              const targets = violation.nodes
                .flatMap((node) => node.target)
                .map((target) => String(target))
                .join(", ");
              issues.push(
                `[${viewport.name}] ${route} axe ${violation.impact} ${violation.id}: ${violation.help}`
                + (targets ? ` (${targets})` : ""),
              );
            }
          } finally {
            await page.close();
          }
        }

        for (const href of profileInternalLinks) {
          const link = new URL(href);
          const candidates = fragmentCandidates(link.hash);
          if (candidates.length === 0) continue;
          const targetRoute = routeForPathname(link.pathname, routeExpectations);
          const targetIDs = targetRoute ? renderedIDs.get(targetRoute) : undefined;
          if (!targetIDs || !candidates.some((fragment) => targetIDs.has(fragment))) {
            issues.push(
              `[${viewport.name}] missing fragment ${link.hash} for rendered internal link ${link.href}`,
            );
          }
        }
      } finally {
        await context.close();
      }
    }

    const targetURLs = new Set(
      [...allInternalLinks].map((href) => {
        const target = new URL(href);
        target.hash = "";
        return target.href;
      }),
    );
    let noSlashDirectoryRedirects = 0;
    for (const href of [...targetURLs].sort()) {
      const target = new URL(href);
      if (
        target.pathname !== HOSTING_BASE_PATH
        && !target.pathname.startsWith(`${HOSTING_BASE_PATH}/`)
      ) {
        continue;
      }
      try {
        const response = await fetch(target, { redirect: "follow" });
        if (!response.ok) {
          issues.push(`internal link target returned ${response.status}: ${target.href}`);
        }
        const canonicalRoute = routeForPathname(target.pathname, routeExpectations);
        if (canonicalRoute && !target.pathname.endsWith("/")) {
          noSlashDirectoryRedirects += 1;
          const finalPath = new URL(response.url).pathname;
          const expectedPath = `${HOSTING_BASE_PATH}${canonicalRoute}`;
          if (finalPath !== expectedPath) {
            issues.push(
              `internal no-slash directory link did not redirect to ${expectedPath}: ${target.href}`,
            );
          }
        }
      } catch (error) {
        issues.push(
          `internal link target request failed: ${target.href} (${error instanceof Error ? error.message : String(error)})`,
        );
      }
    }

    if (issues.length > 0) {
      console.error(`Rendered DocC browser verification failed with ${issues.length} issue(s):`);
      for (const issue of issues) console.error(`- ${issue}`);
      process.exitCode = 1;
      return;
    }

    console.log(
      `Rendered DocC browser verification passed: ${routes.length} public routes across 2 viewports × 2 color schemes (${routes.length * RENDER_PROFILES.length} checks)`,
    );
    console.log(
      `Validated ${allInternalLinks.size} rendered same-origin internal links (${noSlashDirectoryRedirects} no-slash directory redirects)`,
    );
  } finally {
    await browser?.close();
    await closeServer(server);
  }
}

main().catch((error) => {
  console.error(`error: ${error instanceof Error ? error.stack ?? error.message : String(error)}`);
  process.exitCode = 1;
});
