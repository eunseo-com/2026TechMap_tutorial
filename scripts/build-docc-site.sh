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

cp Web/index.html "$output_path/index.html"

test -f "$output_path/index.html"
test -f "$output_path/data/tutorials/scenekittorealitykit.json"
rg --fixed-strings 'tutorials/scenekittorealitykit/' "$output_path/index.html"
