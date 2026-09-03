#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
catalog_path="$repo_root/Tutorials/SceneKitToRealityKit.docc"
root_index_path="$repo_root/Web/index.html"
accessibility_fix_path="$repo_root/Web/docc-accessibility-fixes.js"

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [output-path]" >&2
  exit 64
fi

output_path="${1:-$repo_root/build/SceneKitToRealityKit.doccarchive}"
if [[ "$output_path" != /* ]]; then
  output_path="$(pwd)/$output_path"
fi

mkdir -p "$(dirname "$output_path")"
output_parent="$(cd "$(dirname "$output_path")" && pwd)"
output_name="$(basename "$output_path")"
if [[ -z "$output_name" || "$output_name" == "." || "$output_name" == ".." || "$output_name" == "/" ]]; then
  echo "error: output path must name a dedicated DocC archive directory" >&2
  exit 64
fi
if [[ "$output_parent" == "/" ]]; then
  output_path="/$output_name"
else
  output_path="$output_parent/$output_name"
fi
temporary_root="$(cd "${TMPDIR:-/tmp}" && pwd)"
case "$output_path" in
  "/"|"/tmp"|"/private/tmp"|"$temporary_root"|"$repo_root")
    echo "error: refusing broad DocC output path: $output_path" >&2
    exit 64
    ;;
esac
if [[ -L "$output_path" ]]; then
  echo "error: refusing symlink DocC output path: $output_path" >&2
  exit 64
fi

diagnostics_log="$(mktemp "${TMPDIR:-/tmp}/scenekit-realitykit-docc.XXXXXX")"
cleanup() {
  rm -f "$diagnostics_log"
}
trap cleanup EXIT

set +e
xcrun docc convert "$catalog_path" \
  --fallback-display-name "SceneKitToRealityKit" \
  --fallback-bundle-identifier "com.techmap.scenekittorealitykit" \
  --fallback-bundle-version "1.0" \
  --hosting-base-path /2026TechMap_tutorial \
  --output-path "$output_path" 2>&1 | tee "$diagnostics_log"
pipeline_status=("${PIPESTATUS[@]}")
docc_status="${pipeline_status[0]}"
tee_status="${pipeline_status[1]}"
set -e

if [[ "$tee_status" -ne 0 ]]; then
  echo "error: failed to preserve DocC diagnostics (tee exit $tee_status)" >&2
  exit "$tee_status"
fi

if [[ "$docc_status" -ne 0 ]]; then
  echo "error: DocC conversion failed with exit code $docc_status" >&2
  exit "$docc_status"
fi

if grep -Eiq '(^|[[:space:]])(warning|error):' "$diagnostics_log"; then
  echo "error: DocC emitted warning or error diagnostics" >&2
  grep -Ei '(^|[[:space:]])(warning|error):' "$diagnostics_log" >&2
  exit 1
fi

cp "$root_index_path" "$output_path/index.html"
cp "$accessibility_fix_path" "$output_path/js/docc-accessibility-fixes.js"
printf '%s\n' '{}' > "$output_path/theme-settings.json"

find "$output_path" -type f -name '*.html' \
  -exec perl -pi -e 's/<html lang="[^"]*"/<html lang="ko-KR"/g' {} +
find "$output_path" -type f -name '*.html' \
  -exec perl -0pi -e 's#</body>#<script defer src="/2026TechMap_tutorial/js/docc-accessibility-fixes.js"></script>\n</body># unless /docc-accessibility-fixes\.js/' {} +

# Swift-DocC Render 6.2 ships an English plural choice string that is placed
# verbatim into tutorial-card aria-labels. Keep the visible duration intact,
# but prevent VoiceOver from reading "{count}" as literal text.
find "$output_path/js" -type f -name 'index.*.js' \
  -exec perl -pi -e 's/VUE_APP_DEFAULT_LOCALE\?\?"en-US"/VUE_APP_DEFAULT_LOCALE??"ko-KR"/g; s/minute \| minutes \| \{count\} minutes/minutes/g; s/분 \| 분 \| \{count\}분/분/g; s/"current":"현재 \{thing\}"/"current":"현재 섹션"/g' {} +

# These compiler-provided tutorial action titles are emitted into overview and
# chapter render JSON instead of going through the runtime locale table.
find "$output_path/data/tutorials" -type f -name '*.json' \
  -exec perl -pi -e 's/"Get started"/"시작하기"/g; s/"View more"/"더 보기"/g' {} +

documentation_json=(
  "data/documentation/scenekittorealitykit.json"
  "data/documentation/scenekittorealitykit/devicecameradiagnostics.json"
  "data/documentation/scenekittorealitykit/migrationworksheet.json"
  "data/documentation/scenekittorealitykit/realitykitecs.json"
  "data/documentation/scenekittorealitykit/scenegraphdeepdive.json"
)

tutorial_json=(
  "data/tutorials/scenekittorealitykit.json"
  "data/tutorials/scenekittorealitykit/01-closedworld.json"
  "data/tutorials/scenekittorealitykit/02-openingthedoor.json"
  "data/tutorials/scenekittorealitykit/03-realhideandseek.json"
  "data/tutorials/scenekittorealitykit/04-comparison.json"
)

route_html=(
  "documentation/scenekittorealitykit/index.html"
  "documentation/scenekittorealitykit/devicecameradiagnostics/index.html"
  "documentation/scenekittorealitykit/migrationworksheet/index.html"
  "documentation/scenekittorealitykit/realitykitecs/index.html"
  "documentation/scenekittorealitykit/scenegraphdeepdive/index.html"
  "tutorials/scenekittorealitykit/index.html"
  "tutorials/scenekittorealitykit/01-closedworld/index.html"
  "tutorials/scenekittorealitykit/02-openingthedoor/index.html"
  "tutorials/scenekittorealitykit/03-realhideandseek/index.html"
  "tutorials/scenekittorealitykit/04-comparison/index.html"
)

visual_images=(
  "images/com.techmap.scenekittorealitykit/chapter-1-closed-world.png"
  "images/com.techmap.scenekittorealitykit/chapter-2-opening-reality.png"
  "images/com.techmap.scenekittorealitykit/chapter-3-real-hide-and-seek.png"
  "images/com.techmap.scenekittorealitykit/chapter-4-comparing-worlds.png"
  "images/com.techmap.scenekittorealitykit/app-screen-chapter-1-closed-world.png"
  "images/com.techmap.scenekittorealitykit/app-screen-chapter-2-scanning.png"
  "images/com.techmap.scenekittorealitykit/app-screen-chapter-3-searching.png"
  "images/com.techmap.scenekittorealitykit/app-screen-chapter-4-comparison.png"
)

required_files=(
  "index.html"
  "js/docc-accessibility-fixes.js"
  "theme-settings.json"
  "${documentation_json[@]}"
  "${tutorial_json[@]}"
  "${route_html[@]}"
  "${visual_images[@]}"
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -s "$output_path/$relative_path" ]]; then
    echo "error: missing or empty DocC output: $relative_path" >&2
    exit 1
  fi
done

documentation_count="$(find "$output_path/data/documentation" -type f -name '*.json' | wc -l | tr -d '[:space:]')"
tutorial_count="$(find "$output_path/data/tutorials" -type f -name '*.json' | wc -l | tr -d '[:space:]')"

if [[ "$documentation_count" != "5" ]]; then
  echo "error: expected 5 documentation JSON files, found $documentation_count" >&2
  exit 1
fi

if [[ "$tutorial_count" != "5" ]]; then
  echo "error: expected 5 tutorial JSON files, found $tutorial_count" >&2
  exit 1
fi

if ! grep -Fq 'tutorials/scenekittorealitykit/' "$output_path/index.html"; then
  echo "error: root index does not route to the tutorial overview" >&2
  exit 1
fi

invalid_language_html="$(find "$output_path" -type f -name '*.html' \
  ! -exec grep -Fq '<html lang="ko-KR"' {} \; -print -quit)"
if [[ -n "$invalid_language_html" ]]; then
  echo "error: generated HTML must declare lang=\"ko-KR\": $invalid_language_html" >&2
  exit 1
fi

echo "Built DocC site: $output_path"
echo "Verified build inventory: 5 documentation JSON, 5 tutorial JSON, 8 visual images"
