#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:?usage: build-readable-guide.sh existing-site-output}"
test -s "$output_path/data/documentation/scenekittorealitykit.json"
guide_archive="$(mktemp -d "${TMPDIR:-/tmp}/techmap-readable-guide.XXXXXX")"
trap 'rm -rf "$guide_archive"' EXIT

xcrun docc convert "$repo_root/Guides/SceneKitToRealityKit.docc" \
  --fallback-display-name SceneKitToRealityKit \
  --fallback-bundle-identifier com.techmap.scenekittorealitykit \
  --hosting-base-path /2026TechMap_tutorial/guide \
  --warnings-as-errors \
  --output-path "$guide_archive"

python3 "$repo_root/tools/tutorial_site/render.py" "$guide_archive" "$output_path" \
  --base-path /2026TechMap_tutorial --docc-subdirectory guide
python3 "$repo_root/tools/tutorial_site/integrate_pages.py" "$output_path"
touch "$output_path/.nojekyll"
