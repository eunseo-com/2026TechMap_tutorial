import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import test from "node:test";

const execFileAsync = promisify(execFile);
const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(testDirectory, "../..");
const verifierPath = path.join(repoRoot, "scripts", "verify-docc-browser.mjs");
const accessibilityFixPath = path.join(repoRoot, "Web", "docc-accessibility-fixes.js");
const temporaryRoots = [];

function accessiblePage(body, head = "", heading = "검증 페이지") {
  return `<!doctype html>
<html lang="ko-KR">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DocC browser verifier fixture</title>
    ${head}
  </head>
  <body>
    <main><h1>${heading}</h1>${body}</main>
  </body>
</html>`;
}

async function fixtureArchive(pages, expectations) {
  const root = await mkdtemp(path.join(os.tmpdir(), "docc-browser-contract-"));
  temporaryRoots.push(root);

  for (const [relativePath, source] of Object.entries(pages)) {
    const target = path.join(root, relativePath);
    await mkdir(path.dirname(target), { recursive: true });
    await writeFile(target, source, "utf8");
  }

  const routeExpectations = expectations ?? Object.fromEntries(
    Object.keys(pages)
      .filter((relativePath) => relativePath.endsWith("index.html"))
      .map((relativePath) => {
        const directory = relativePath.slice(0, -"index.html".length);
        return [`/${directory}`, { h1: "검증 페이지" }];
      }),
  );
  await writeFile(
    path.join(root, ".browser-route-expectations.json"),
    `${JSON.stringify(routeExpectations, null, 2)}\n`,
    "utf8",
  );

  return root;
}

async function runVerifier(archive) {
  try {
    const result = await execFileAsync(
      process.execPath,
      [verifierPath, archive, path.join(archive, ".browser-route-expectations.json")],
      {
      cwd: repoRoot,
      encoding: "utf8",
      timeout: 120_000,
      maxBuffer: 4 * 1024 * 1024,
      },
    );
    return { code: 0, stdout: result.stdout, stderr: result.stderr };
  } catch (error) {
    return {
      code: error.code ?? 1,
      stdout: error.stdout ?? "",
      stderr: error.stderr ?? error.message,
    };
  }
}

test.after(async () => {
  await Promise.all(temporaryRoots.map((root) => rm(root, { recursive: true, force: true })));
});

test("accepts every discovered HTML route at desktop and mobile sizes", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage("<p>홈</p>"),
    "documentation/sample/index.html": accessiblePage("<p>문서</p>"),
  });

  const result = await runVerifier(archive);

  assert.equal(result.code, 0, result.stderr);
  assert.match(
    result.stdout,
    /2 public routes across 2 viewports × 2 color schemes \(8 checks\)/,
  );
});

test("fails when a route renders duplicated content with the wrong h1", async () => {
  const archive = await fixtureArchive(
    {
      "index.html": accessiblePage("<p>홈</p>"),
      "documentation/sample/index.html": accessiblePage("<p>잘못 복제된 문서</p>"),
    },
    {
      "/": { h1: "검증 페이지" },
      "/documentation/sample/": { h1: "고유 문서 제목" },
    },
  );

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /documentation\/sample.*expected h1.*고유 문서 제목.*검증 페이지/i);
});

test("fails when the root page does not redirect to the tutorial overview", async () => {
  const archive = await fixtureArchive(
    {
      "index.html": accessiblePage("<p>잘못된 root</p>", "", "튜토리얼 홈"),
      "tutorials/sample/index.html": accessiblePage("<p>튜토리얼 overview</p>", "", "튜토리얼 홈"),
    },
    {
      "/": { h1: "튜토리얼 홈", redirectsTo: "/tutorials/sample/" },
      "/tutorials/sample/": { h1: "튜토리얼 홈" },
    },
  );

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /root redirect.*tutorials\/sample/i);
});

test("fails for a broken rendered internal route and fragment", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      `<a href="/2026TechMap_tutorial/missing/">깨진 route</a>
       <a href="/2026TechMap_tutorial/documentation/sample/#missing-fragment">깨진 fragment</a>`,
    ),
    "documentation/sample/index.html": accessiblePage("<p id=\"present-fragment\">문서</p>"),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /internal link target.*missing\//i);
  assert.match(result.stderr, /missing fragment.*missing-fragment/i);
});

test("serves a rendered directory link without a trailing slash like GitHub Pages", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      '<a href="/2026TechMap_tutorial/documentation/sample">slash 없는 문서 링크</a>',
    ),
    "documentation/sample/index.html": accessiblePage("<p>문서</p>"),
  });

  const result = await runVerifier(archive);

  assert.equal(result.code, 0, result.stderr);
  assert.match(result.stdout, /Validated 1 rendered same-origin internal links/);
  assert.match(result.stdout, /1 no-slash directory redirects/);
});

test("accepts known DocC runtime defects after the accessibility repair runs", async () => {
  const accessibilityFix = await readFile(accessibilityFixPath, "utf8").catch(() => "");
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      `<div class="item" aria-label="예상 시간">분</div>
       <button class="toggle"><span aria-hidden="true">...</span></button>
       <ul><li><input type="checkbox" disabled><p>실기기 대기</p></li></ul>
       <div class="table-wrapper" style="overflow:auto;width:80px"><table style="width:300px"><tr><th>상태</th><th>설명</th></tr><tr><td>대기</td><td>실기기</td></tr></table></div>
       <fieldset class="color-scheme-toggle"><legend>색상 모드</legend><label><input type="radio" value="light"><span class="text">라이트</span></label><label><input type="radio" value="auto" checked><span class="text">자동</span></label></fieldset>
       <a href="/2026TechMap_tutorial/#리소스">리소스</a>
       <section id="resources"><h2>리소스</h2></section>`,
      `<style>body{background:#000;color:#fff}a{color:#fff}.color-scheme-toggle .text{color:#0000ff}.color-scheme-toggle input:checked + .text{color:#fff;background:#0000ff}</style>
       <script defer src="/2026TechMap_tutorial/js/docc-accessibility-fixes.js"></script>`,
    ),
    "js/docc-accessibility-fixes.js": accessibilityFix,
  });

  const result = await runVerifier(archive);

  assert.equal(result.code, 0, result.stderr);
});

test("fails when only the mobile dark profile logs a console error", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      "<p>모바일 콘솔 오류</p>",
      `<script>
        if (window.innerWidth === 390 && matchMedia('(prefers-color-scheme: dark)').matches) {
          console.error('mobile-dark-only boom')
        }
       </script>`,
    ),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /mobile-dark.*console\.error.*mobile-dark-only boom/i);
});

test("fails when only dark profiles request a missing resource", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      "<p>다크 네트워크 오류</p>",
      `<script>
        if (matchMedia('(prefers-color-scheme: dark)').matches) {
          const image = document.createElement('img')
          image.alt = '다크 모드 누락 이미지'
          image.src = 'missing-dark.png'
          document.head.append(image)
        }
       </script>`,
    ),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /dark.*network response 404.*missing-dark\.png/i);
});

test("fails on an axe violation that exists only in dark profiles", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      "<p>다크 모드 접근성 오류</p>",
      `<script>
        if (matchMedia('(prefers-color-scheme: dark)').matches) {
          document.addEventListener('DOMContentLoaded', () => document.body.append(document.createElement('button')))
        }
       </script>`,
    ),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /dark.*axe critical button-name/i);
});

test("fails when rendered JavaScript throws an uncaught page error", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      "<p>페이지 오류</p>",
      "<script>setTimeout(() => { throw new Error('page boom') }, 0)</script>",
    ),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /page error.*page boom/i);
});

test("fails when a rendered page receives an HTTP error", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage('<img src="missing.png" alt="누락된 테스트 이미지">'),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /network response 404.*missing\.png/i);
});

test("fails when a rendered resource request cannot connect", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage(
      '<img src="http://127.0.0.1:9/unreachable.png" alt="연결 실패 테스트 이미지">',
    ),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /network request failed.*unreachable\.png/i);
});

test("fails on serious or critical axe accessibility findings", async () => {
  const archive = await fixtureArchive({
    "index.html": accessiblePage("<button></button>"),
  });

  const result = await runVerifier(archive);

  assert.notEqual(result.code, 0);
  assert.match(result.stderr, /axe (serious|critical).*button-name/i);
});
