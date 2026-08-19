# DocC GitHub Pages Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track the Chapter 1 DocC catalog in this repository and publish its static archive to GitHub Pages on `main` changes.

**Architecture:** A DocC catalog under `Tutorials/` is converted by one Bash script into a project-path-aware static archive. A macOS GitHub Actions build job uploads that archive, and a separate deployment job publishes it to GitHub Pages.

**Tech Stack:** DocC, Xcode command-line tools, Bash, GitHub Actions, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-08-19-docc-github-pages-deployment.md`

## Global Constraints

- Preserve all existing repository files.
- Include only Chapter 1 `ClosedWorld` content.
- Do not commit generated DocC archives.
- Use `/2026TechMap_tutorial` as the DocC hosting base path.

---

### Task 1: Add the validated catalog and local static build

**Files:**
- Create: `Tutorials/SceneKitToRealityKit.docc/**`
- Create: `scripts/build-docc-site.sh`
- Modify: `.gitignore`
- Modify: `README.md`

**Interfaces:**
- Consumes: `Tutorials/SceneKitToRealityKit.docc`.
- Produces: a static DocC archive at the first `scripts/build-docc-site.sh` argument, or `build/SceneKitToRealityKit.doccarchive` by default.

- [x] **Step 1: Copy the Chapter 1 DocC catalog**

Copy `SceneKitToRealityKit.tutorial`, `01-ClosedWorld.tutorial`, the eight Swift snippet files, and `closed-world-chapter-icon.png` into `Tutorials/SceneKitToRealityKit.docc`.

- [x] **Step 2: Prove the build-script precondition is missing**

```bash
test -f Tutorials/SceneKitToRealityKit.docc/SceneKitToRealityKit.tutorial
test -f scripts/build-docc-site.sh
```

Expected: the first check passes and the second fails before the script exists.

- [x] **Step 3: Add the minimal DocC build script**

```bash
#!/usr/bin/env bash
set -euo pipefail

output_path="${1:-build/SceneKitToRealityKit.doccarchive}"
mkdir -p "$(dirname "$output_path")"

xcrun docc convert Tutorials/SceneKitToRealityKit.docc \
  --fallback-display-name "씬킷에서 리얼리티킷으로" \
  --fallback-bundle-identifier "com.techmap.scenekittorealitykit" \
  --fallback-bundle-version "1.0" \
  --hosting-base-path /2026TechMap_tutorial \
  --output-path "$output_path"

test -f "$output_path/index.html"
test -f "$output_path/data/tutorials/scenekittorealitykit.json"
```

- [x] **Step 4: Verify the generated archive is path-aware**

```bash
bash scripts/build-docc-site.sh /tmp/SceneKitToRealityKit.github-pages.doccarchive
grep -Fq 'baseUrl = "/2026TechMap_tutorial/"' /tmp/SceneKitToRealityKit.github-pages.doccarchive/index.html
```

Expected: both archive contract files exist and the root HTML contains the repository base path.

- [x] **Step 5: Keep generated output untracked and document the command**

Add `build/` to `.gitignore`, and add the local build command plus published URL convention to `README.md`.

### Task 2: Add GitHub Pages automation

**Files:**
- Create: `.github/workflows/deploy-docc.yml`

**Interfaces:**
- Consumes: `scripts/build-docc-site.sh site`.
- Produces: a GitHub Pages artifact whose root is the generated static archive.

- [x] **Step 1: Add the build and deploy workflow**

```yaml
name: Deploy DocC

on:
  push:
    branches: [main]
    paths:
      - "Tutorials/SceneKitToRealityKit.docc/**"
      - "scripts/build-docc-site.sh"
      - ".github/workflows/deploy-docc.yml"
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - run: bash scripts/build-docc-site.sh site
      - run: test -f site/index.html && test -f site/data/tutorials/scenekittorealitykit.json
      - uses: actions/upload-pages-artifact@v4
        with:
          path: site
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [x] **Step 2: Verify workflow syntax**

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/deploy-docc.yml"); puts "valid"'
```

Expected: `valid`.

### Task 3: Enable Pages and publish

**Files:**
- Modify: `docs/PROJECT_CONTEXT.md`
- Modify: `docs/superpowers/plans/2026-08-19-docc-github-pages-deployment.md`

**Interfaces:**
- Consumes: validated local static archive and the `Deploy DocC` workflow.
- Produces: `https://eunseo-com.github.io/2026TechMap_tutorial/`.

- [x] **Step 1: Record the DocC-first publication decision in project context**

State that the Chapter 1 catalog is source-managed and GitHub Pages publishes the Actions-built static archive; the iOS implementation plan remains otherwise unchanged.

- [x] **Step 2: Commit and push the exact validated source**

```bash
git add .gitignore .github README.md Tutorials scripts docs
git commit -m "Deploy DocC tutorial with GitHub Pages"
git push origin main
```

- [x] **Step 3: Enable the Pages workflow source**

Set this repository's GitHub Pages build type to `workflow`, then confirm a `Deploy DocC` workflow runs from the pushed `main` commit.

- [x] **Step 4: Verify the published tutorial**

```text
https://eunseo-com.github.io/2026TechMap_tutorial/
```

Expected: DocC home page, chapter image, and `01-ClosedWorld` tutorial load without missing static assets.

### Task 4: Route the public root to the tutorial

**Files:**
- Create: `Web/index.html`
- Modify: `scripts/build-docc-site.sh`
- Modify: `.github/workflows/deploy-docc.yml`

**Interfaces:**
- Consumes: the static archive produced by `docc convert`.
- Produces: a root `index.html` that moves visitors to `tutorials/scenekittorealitykit/` while direct DocC tutorial routes remain unchanged.

- [x] **Step 1: Reproduce the root-entry failure**

```bash
bash scripts/build-docc-site.sh /tmp/SceneKitToRealityKit.root-check.doccarchive
grep -Fq 'tutorials/scenekittorealitykit/' /tmp/SceneKitToRealityKit.root-check.doccarchive/index.html
```

Expected: the `rg` command fails because DocC's generic archive root does not identify this tutorials-only catalog's first route.

- [x] **Step 2: Add an accessible root redirect page**

Create `Web/index.html` with a relative meta refresh, JavaScript replacement, and an ordinary fallback link to `./tutorials/scenekittorealitykit/`.

- [x] **Step 3: Replace the generated archive root after DocC conversion**

Add the following after the `docc convert` command in `scripts/build-docc-site.sh`:

```bash
cp Web/index.html "$output_path/index.html"
```

Then assert that the archive root contains `tutorials/scenekittorealitykit/`.

- [x] **Step 4: Include the root page in the deployment trigger and verify locally**

Add `Web/index.html` to the workflow's `push.paths`, then run:

```bash
bash scripts/build-docc-site.sh /tmp/SceneKitToRealityKit.root-check.doccarchive
grep -Fq 'tutorials/scenekittorealitykit/' /tmp/SceneKitToRealityKit.root-check.doccarchive/index.html
```

Expected: the root archive page now routes readers to the tutorial.

- [ ] **Step 5: Commit, deploy, and verify the public root URL**

Push the root-entry fix, then verify that `https://eunseo-com.github.io/2026TechMap_tutorial/` reaches the tutorial start page.
