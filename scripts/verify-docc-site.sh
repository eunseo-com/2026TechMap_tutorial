#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [archive-path]" >&2
  exit 64
fi

archive_path="${1:-$repo_root/build/SceneKitToRealityKit.doccarchive}"
if [[ "$archive_path" != /* ]]; then
  archive_path="$(pwd)/$archive_path"
fi

python3 - "$repo_root" "$archive_path" <<'PY'
import html
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


repo_root = Path(sys.argv[1]).resolve()
archive = Path(sys.argv[2]).resolve()
catalog = repo_root / "Tutorials" / "SceneKitToRealityKit.docc"
errors = []


def record(message):
    errors.append(message)


def require_nonempty(path, label):
    if not path.is_file():
        record(f"missing {label}: {path.relative_to(archive) if archive in path.parents else path}")
        return False
    if path.stat().st_size == 0:
        record(f"empty {label}: {path.relative_to(archive) if archive in path.parents else path}")
        return False
    return True


if not archive.is_dir():
    print(f"error: DocC archive does not exist: {archive}", file=sys.stderr)
    sys.exit(1)

if not catalog.is_dir():
    print(f"error: DocC catalog does not exist: {catalog}", file=sys.stderr)
    sys.exit(1)

documentation_json = {
    "scenekittorealitykit.json",
    "scenekittorealitykit/devicecameradiagnostics.json",
    "scenekittorealitykit/migrationworksheet.json",
    "scenekittorealitykit/realitykitecs.json",
    "scenekittorealitykit/scenegraphdeepdive.json",
}
tutorial_json = {
    "scenekittorealitykit.json",
    "scenekittorealitykit/01-closedworld.json",
    "scenekittorealitykit/02-openingthedoor.json",
    "scenekittorealitykit/03-realhideandseek.json",
    "scenekittorealitykit/04-comparison.json",
}
documentation_html = {
    "scenekittorealitykit/index.html",
    "scenekittorealitykit/devicecameradiagnostics/index.html",
    "scenekittorealitykit/migrationworksheet/index.html",
    "scenekittorealitykit/realitykitecs/index.html",
    "scenekittorealitykit/scenegraphdeepdive/index.html",
}
tutorial_html = {
    "scenekittorealitykit/index.html",
    "scenekittorealitykit/01-closedworld/index.html",
    "scenekittorealitykit/02-openingthedoor/index.html",
    "scenekittorealitykit/03-realhideandseek/index.html",
    "scenekittorealitykit/04-comparison/index.html",
}
chapter_images = {
    "chapter-1-closed-world.png",
    "chapter-2-opening-reality.png",
    "chapter-3-real-hide-and-seek.png",
    "chapter-4-comparing-worlds.png",
}


def relative_files(root, pattern):
    if not root.is_dir():
        return set()
    return {path.relative_to(root).as_posix() for path in root.rglob(pattern) if path.is_file()}


actual_documentation_json = relative_files(archive / "data" / "documentation", "*.json")
actual_tutorial_json = relative_files(archive / "data" / "tutorials", "*.json")
actual_documentation_html = relative_files(archive / "documentation", "index.html")
actual_tutorial_html = relative_files(archive / "tutorials", "index.html")

for label, actual, expected in (
    ("documentation JSON inventory", actual_documentation_json, documentation_json),
    ("tutorial JSON inventory", actual_tutorial_json, tutorial_json),
    ("documentation route inventory", actual_documentation_html, documentation_html),
    ("tutorial route inventory", actual_tutorial_html, tutorial_html),
):
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    if missing:
        record(f"{label} is missing: {', '.join(missing)}")
    if unexpected:
        record(f"{label} has unexpected entries: {', '.join(unexpected)}")

required_route_files = [archive / "index.html"]
required_route_files.extend(archive / "documentation" / path for path in documentation_html)
required_route_files.extend(archive / "tutorials" / path for path in tutorial_html)
for path in required_route_files:
    require_nonempty(path, "HTML route")

image_root = archive / "images" / "com.techmap.scenekittorealitykit"
for image_name in sorted(chapter_images):
    require_nonempty(image_root / image_name, "chapter image")

for source_name in sorted(chapter_images):
    require_nonempty(catalog / "Resources" / source_name, "source chapter image")

for namespace_root in (
    archive / "data" / "documentation",
    archive / "data" / "tutorials",
    archive / "documentation",
    archive / "tutorials",
):
    if not namespace_root.exists():
        continue
    for path in sorted(namespace_root.rglob("*")):
        for component in path.relative_to(namespace_root).parts:
            candidate = component.rsplit(".", 1)[0]
            if re.fullmatch(r"-+", candidate):
                record(f"all-hyphen namespace is not allowed: {path.relative_to(archive)}")

placeholder_pattern = re.compile(r"\{(?:count|number)\}")
source_extensions = {".md", ".tutorial", ".swift"}
for path in sorted(catalog.rglob("*")):
    if not path.is_file() or path.suffix not in source_extensions:
        continue
    content = path.read_text(encoding="utf-8")
    if placeholder_pattern.search(content):
        record(f"unresolved localization placeholder in source: {path.relative_to(repo_root)}")

for path in sorted((archive / "data").rglob("*.json")) + sorted(archive.rglob("*.html")):
    content = path.read_text(encoding="utf-8", errors="replace")
    if placeholder_pattern.search(content):
        record(f"unresolved localization placeholder in archive: {path.relative_to(archive)}")

known_doc_targets = {path.stem for path in catalog.rglob("*.tutorial")}
known_doc_targets.update(path.stem for path in catalog.rglob("*.md"))
doc_link_pattern = re.compile(r"doc:([A-Za-z0-9][A-Za-z0-9._-]*)")
for path in sorted(catalog.rglob("*")):
    if not path.is_file() or path.suffix not in {".md", ".tutorial"}:
        continue
    content = path.read_text(encoding="utf-8")
    for match in doc_link_pattern.finditer(content):
        target = match.group(1)
        if target not in known_doc_targets:
            record(f"unresolved doc link {target!r} in {path.relative_to(repo_root)}")

parsed_json = {}
for relative_path in sorted(documentation_json):
    path = archive / "data" / "documentation" / relative_path
    if not require_nonempty(path, "documentation JSON"):
        continue
    try:
        parsed_json[path] = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        record(f"invalid JSON in {path.relative_to(archive)}: {error}")

for relative_path in sorted(tutorial_json):
    path = archive / "data" / "tutorials" / relative_path
    if not require_nonempty(path, "tutorial JSON"):
        continue
    try:
        parsed_json[path] = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        record(f"invalid JSON in {path.relative_to(archive)}: {error}")


def walk_json(value, location):
    if isinstance(value, dict):
        if value.get("type") == "reference" and value.get("isActive") is False:
            record(f"inactive compiled documentation reference in {location}")
        if value.get("type") == "link" and str(value.get("destination", "")).startswith("doc:"):
            record(f"unresolved compiled doc link in {location}: {value['destination']}")
        for child in value.values():
            walk_json(child, location)
    elif isinstance(value, list):
        for child in value:
            walk_json(child, location)


for path, data in parsed_json.items():
    walk_json(data, path.relative_to(archive))

render_bundles = sorted((archive / "js").glob("index.*.js"))
if len(render_bundles) != 1:
    record(f"expected one DocC render index bundle, found {len(render_bundles)}")
else:
    render_source = render_bundles[0].read_text(encoding="utf-8", errors="replace")
    if "minute | minutes | {count} minutes" in render_source:
        record("DocC render bundle still contains the broken tutorial-duration aria-label template")
    if "분 | 분 | {count}분" in render_source:
        record("DocC render bundle still contains the broken Korean tutorial-duration aria-label template")
    if 'VUE_APP_DEFAULT_LOCALE??"en-US"' in render_source:
        record("DocC render bundle still defaults the Korean tutorial site to en-US")

chapter_json_paths = (
    (1, archive / "data/tutorials/scenekittorealitykit/01-closedworld.json"),
    (2, archive / "data/tutorials/scenekittorealitykit/02-openingthedoor.json"),
    (3, archive / "data/tutorials/scenekittorealitykit/03-realhideandseek.json"),
    (4, archive / "data/tutorials/scenekittorealitykit/04-comparison.json"),
)
for chapter_number, path in chapter_json_paths:
    data = parsed_json.get(path)
    if data is None:
        continue
    title = data.get("metadata", {}).get("title", "")
    if not title.startswith(f"Chapter {chapter_number}"):
        record(f"chapter title needs stable prefix 'Chapter {chapter_number}': {path.relative_to(archive)}")

overview_json_path = archive / "data" / "tutorials" / "scenekittorealitykit.json"
overview = parsed_json.get(overview_json_path)
if overview is not None:
    serialized_overview = json.dumps(overview, ensure_ascii=False)
    if '"Get started"' in serialized_overview or '"View more"' in serialized_overview:
        record("tutorial overview still contains untranslated compiler action titles")
    if '"시작하기"' not in serialized_overview or '"더 보기"' not in serialized_overview:
        record("tutorial overview is missing the Korean compiler action titles")

    image_references = {
        key: value
        for key, value in overview.get("references", {}).items()
        if isinstance(value, dict) and value.get("type") == "image"
    }
    actual_image_names = set(image_references)
    if actual_image_names != chapter_images:
        missing = sorted(chapter_images - actual_image_names)
        unexpected = sorted(actual_image_names - chapter_images)
        if missing:
            record(f"tutorial overview is missing chapter image references: {', '.join(missing)}")
        if unexpected:
            record(f"tutorial overview has unexpected image references: {', '.join(unexpected)}")

    seen_alt = {}
    for image_name in sorted(chapter_images):
        reference = image_references.get(image_name, {})
        alt = reference.get("alt")
        if not isinstance(alt, str) or not alt.strip():
            record(f"missing alt text for chapter image: {image_name}")
            continue
        normalized_alt = " ".join(alt.split()).casefold()
        if normalized_alt in seen_alt:
            record(f"duplicate alt text for {seen_alt[normalized_alt]} and {image_name}")
        else:
            seen_alt[normalized_alt] = image_name

        variants = reference.get("variants", [])
        urls = [item.get("url") for item in variants if isinstance(item, dict)]
        if not urls:
            record(f"chapter image has no compiled asset URL: {image_name}")
        for url in urls:
            if not isinstance(url, str) or not url.startswith("/images/"):
                record(f"invalid compiled chapter image URL for {image_name}: {url!r}")
                continue
            require_nonempty(archive / unquote(url.lstrip("/")), "compiled image asset")

theme_settings = archive / "theme-settings.json"
if require_nonempty(theme_settings, "theme settings"):
    try:
        json.loads(theme_settings.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        record(f"invalid theme-settings.json: {error}")

html_attribute_pattern = re.compile(r"(?:src|href)=\"([^\"]+)\"")
html_lang_pattern = re.compile(r"<html\b[^>]*\blang=\"ko-KR\"", re.IGNORECASE)
base_path = "/2026TechMap_tutorial/"
for path in sorted(archive.rglob("*.html")):
    content = path.read_text(encoding="utf-8", errors="replace")
    if not html_lang_pattern.search(content):
        record(f"HTML locale must be ko-KR: {path.relative_to(archive)}")
    for raw_url in html_attribute_pattern.findall(content):
        url = html.unescape(raw_url)
        if url.startswith(("https://", "http://", "mailto:", "#", "data:")):
            continue
        if url.startswith(base_path):
            local = url[len(base_path):]
            target = archive / unquote(urlsplit(local).path)
        elif url.startswith("/"):
            record(f"local HTML asset escapes hosting base path in {path.relative_to(archive)}: {url}")
            continue
        else:
            target = path.parent / unquote(urlsplit(url).path)
        if not urlsplit(url).path:
            continue
        target = target.resolve()
        try:
            target.relative_to(archive)
        except ValueError:
            record(f"local HTML asset escapes archive in {path.relative_to(archive)}: {url}")
            continue
        if target.is_dir() or urlsplit(url).path.endswith("/"):
            target = target / "index.html"
        if not target.is_file():
            record(f"missing HTML-linked asset in {path.relative_to(archive)}: {url}")

css_url_pattern = re.compile(r"url\(\s*['\"]?([^)'\"]+)['\"]?\s*\)")
for path in sorted((archive / "css").glob("*.css")):
    content = path.read_text(encoding="utf-8", errors="replace")
    for raw_url in css_url_pattern.findall(content):
        if raw_url.startswith(("data:", "https://", "http://", "#")):
            continue
        target = (path.parent / unquote(urlsplit(raw_url).path)).resolve()
        try:
            target.relative_to(archive)
        except ValueError:
            record(f"CSS asset escapes archive in {path.relative_to(archive)}: {raw_url}")
            continue
        if not target.is_file():
            record(f"missing CSS-linked asset in {path.relative_to(archive)}: {raw_url}")

root_index = archive / "index.html"
if root_index.is_file():
    root_content = root_index.read_text(encoding="utf-8", errors="replace")
    if "./tutorials/scenekittorealitykit/" not in root_content:
        record("root index does not route to ./tutorials/scenekittorealitykit/")

if errors:
    for message in sorted(set(errors)):
        print(f"error: {message}", file=sys.stderr)
    sys.exit(1)

print(f"Verified DocC site: {archive}")
print("Routes: 5 documentation + 5 tutorial; chapter images: 4; locale: ko-KR")
print("Links, placeholders, alt text, route assets, and theme assets are resolved")
PY
