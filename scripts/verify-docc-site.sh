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
import hashlib
import html
import json
import re
import shutil
import subprocess
import sys
import tempfile
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
app_screen_images = {
    1: "app-screen-chapter-1-closed-world.png",
    2: "app-screen-chapter-2-scanning.png",
    3: "app-screen-chapter-3-searching.png",
    4: "app-screen-chapter-4-comparison.png",
}
all_visual_images = chapter_images | set(app_screen_images.values())
approved_visuals = {
    "chapter-1-closed-world.png": "9979438c892484fab2db5d6b27bb9f4a538042d3ada3b183e2a559e5194f09c2",
    "chapter-2-opening-reality.png": "026a6d1aa03fea750eb1c745690de5c86f2ceb33318c1521c51ad5cf3334bb2d",
    "chapter-3-real-hide-and-seek.png": "9331925e7efc13cfb84dc4a39bc2553a699784ec9429dbe23242c6559330a020",
    "chapter-4-comparing-worlds.png": "7ef77fcae8d6532a39dc2b2904d17a2d6c6b0c9513c3d8b480fafd2d11f4195d",
    "app-screen-chapter-1-closed-world.png": "62fc0b98e4652cacd0812271afc3ec237b31c38fb9f340864498176b550f2385",
    "app-screen-chapter-2-scanning.png": "fdedf18639979dbdbf3e1730359894bc95d2a59c04c47dd1dd769b2e8217b068",
    "app-screen-chapter-3-searching.png": "3d6b41d7d6ca55ce2b1aee08fe1d01afbef960735e2032ea8826684669a46f7d",
    "app-screen-chapter-4-comparison.png": "e7bd0e4121a9ce33c3a83836f8fcaf7215641e224114d1fe0ce31e57c583559f",
}
app_screen_contracts = {
    1: (
        "선언된 섬 안에서만 보고 선택하기",
        "01-ClosedWorld-02-C3SceneAndInput.swift",
    ),
    2: (
        "실제 스캔을 보여 주고 CTA 뒤에만 입력 열기",
        "02-OpeningReality-03-ScanFeedbackAndGate.swift",
    ),
    3: (
        "가림과 재발견을 서로 다른 두 frame으로 확인하기",
        "03-RealHideAndSeek-03-StableOcclusion.swift",
    ),
    4: (
        "경험을 네 비교 축으로 정렬하기",
        "04-Comparison-01-ComparisonModel.swift",
    ),
}
disclosure = "AI 생성 앱 화면 컨셉 · 실제 앱 실행 화면/실기기 캡처 아님"


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
actual_compiled_images = relative_files(image_root, "*.png")
if actual_compiled_images != all_visual_images:
    missing = sorted(all_visual_images - actual_compiled_images)
    unexpected = sorted(actual_compiled_images - all_visual_images)
    if missing:
        record(f"compiled visual image inventory is missing: {', '.join(missing)}")
    if unexpected:
        record(f"compiled visual image inventory has unexpected entries: {', '.join(unexpected)}")

actual_source_images = relative_files(catalog / "Resources", "*.png")
if actual_source_images != all_visual_images:
    missing = sorted(all_visual_images - actual_source_images)
    unexpected = sorted(actual_source_images - all_visual_images)
    if missing:
        record(f"source visual image inventory is missing: {', '.join(missing)}")
    if unexpected:
        record(f"source visual image inventory has unexpected entries: {', '.join(unexpected)}")

for image_name in sorted(all_visual_images):
    require_nonempty(image_root / image_name, "tutorial visual image")

for source_name in sorted(all_visual_images):
    require_nonempty(catalog / "Resources" / source_name, "source tutorial visual image")

sips = shutil.which("sips")
if sips is None:
    record("full PNG decoder is unavailable: sips")

with tempfile.TemporaryDirectory(prefix="verify-docc-site-png-decode-") as decode_root:
    for image_name in sorted(all_visual_images):
        source_path = catalog / "Resources" / image_name
        compiled_path = image_root / image_name
        if not source_path.is_file() or not compiled_path.is_file():
            continue

        source_bytes = source_path.read_bytes()
        compiled_bytes = compiled_path.read_bytes()
        source_digest = hashlib.sha256(source_bytes).hexdigest()
        compiled_digest = hashlib.sha256(compiled_bytes).hexdigest()
        approved_digest = approved_visuals[image_name]

        if source_digest != approved_digest:
            record(
                f"source visual image has unapproved SHA-256 for {image_name}: "
                f"expected {approved_digest}, found {source_digest}"
            )
        if compiled_digest != approved_digest:
            record(
                f"compiled visual image has unapproved SHA-256 for {image_name}: "
                f"expected {approved_digest}, found {compiled_digest}"
            )
        if compiled_digest != source_digest:
            record(f"compiled visual image SHA-256 differs from source: {image_name}")
        if compiled_bytes != source_bytes:
            record(f"compiled visual image bytes differ from source: {image_name}")

        if sips is None:
            continue
        for label, path in (("source", source_path), ("compiled", compiled_path)):
            decoded_path = Path(decode_root) / f"{label}-{path.stem}.tiff"
            decoded = subprocess.run(
                [sips, "-s", "format", "tiff", str(path), "--out", str(decoded_path)],
                capture_output=True,
                text=True,
            )
            if decoded.returncode != 0 or not decoded_path.is_file() or decoded_path.stat().st_size == 0:
                detail = decoded.stderr.strip().splitlines()
                suffix = f": {detail[-1]}" if detail else ""
                record(f"full PNG decode failed for {label} visual image {image_name}{suffix}")

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
    if '"current":"현재 {thing}"' in render_source:
        record("DocC render bundle still composes the current-section label from an unresolved nested placeholder")
    if '"current":"현재 섹션"' not in render_source:
        record("DocC render bundle is missing the static Korean current-section label")
    if '"title":"{number}섹션"' not in render_source:
        record("DocC render bundle must preserve numbered Korean section-link labels")
    if 'VUE_APP_DEFAULT_LOCALE??"en-US"' in render_source:
        record("DocC render bundle still defaults the Korean tutorial site to en-US")

chapter_json_paths = (
    (1, archive / "data/tutorials/scenekittorealitykit/01-closedworld.json"),
    (2, archive / "data/tutorials/scenekittorealitykit/02-openingthedoor.json"),
    (3, archive / "data/tutorials/scenekittorealitykit/03-realhideandseek.json"),
    (4, archive / "data/tutorials/scenekittorealitykit/04-comparison.json"),
)
seen_alt = {}


def register_alt(image_name, alt):
    if not isinstance(alt, str) or not alt.strip():
        record(f"missing alt text for tutorial visual image: {image_name}")
        return
    normalized_alt = " ".join(alt.split()).casefold()
    if normalized_alt in seen_alt:
        record(f"duplicate alt text for {seen_alt[normalized_alt]} and {image_name}")
    else:
        seen_alt[normalized_alt] = image_name


def flattened_text(value):
    fragments = []
    if isinstance(value, dict):
        text = value.get("text")
        if isinstance(text, str):
            fragments.append(text)
        for child in value.values():
            fragments.extend(flattened_text(child))
    elif isinstance(value, list):
        for child in value:
            fragments.extend(flattened_text(child))
    return "".join(fragments)


for chapter_number, path in chapter_json_paths:
    data = parsed_json.get(path)
    if data is None:
        continue
    serialized_chapter = json.dumps(data, ensure_ascii=False)
    if '"Get started"' in serialized_chapter or '"View more"' in serialized_chapter:
        record(f"Chapter {chapter_number} still contains an untranslated compiler action title")
    title = data.get("metadata", {}).get("title", "")
    if not title.startswith(f"Chapter {chapter_number}"):
        record(f"chapter title needs stable prefix 'Chapter {chapter_number}': {path.relative_to(archive)}")

    expected_app_screen = app_screen_images[chapter_number]
    expected_task_title, expected_code = app_screen_contracts[chapter_number]
    task_sections = [section for section in data.get("sections", []) if section.get("kind") == "tasks"]
    if len(task_sections) != 1:
        record(f"Chapter {chapter_number} must compile exactly one tasks section")
        target_tasks = []
    else:
        target_tasks = [
            task
            for task in task_sections[0].get("tasks", [])
            if task.get("title") == expected_task_title
        ]
    if len(target_tasks) != 1:
        record(
            f"Chapter {chapter_number} must compile exactly one target task {expected_task_title!r}; "
            f"found {len(target_tasks)}"
        )
    else:
        target_task = target_tasks[0]
        content_sections = target_task.get("contentSection", [])
        content_and_media_sections = [
            section
            for section in content_sections
            if section.get("kind") == "contentAndMedia"
        ]
        matching_content = [
            section
            for section in content_and_media_sections
            if section.get("media") == expected_app_screen
        ]
        if len(content_and_media_sections) != 1 or len(matching_content) != 1:
            record(
                f"Chapter {chapter_number} target task must compile one contentAndMedia block "
                f"for {expected_app_screen}"
            )
        else:
            content_and_media = matching_content[0]
            if content_and_media.get("mediaPosition") != "trailing":
                record(f"Chapter {chapter_number} app-screen media position must be trailing")
            if disclosure not in flattened_text(content_and_media.get("content", [])):
                record(f"Chapter {chapter_number} target contentAndMedia is missing the AI disclosure")

        steps = target_task.get("stepsSection", [])
        if (
            len(steps) != 1
            or steps[0].get("type") != "step"
            or steps[0].get("code") != expected_code
            or steps[0].get("media") is not None
        ):
            record(
                f"Chapter {chapter_number} target task must put related code {expected_code} "
                "in its sole media-free step"
            )

    image_references = {
        key: value
        for key, value in data.get("references", {}).items()
        if isinstance(value, dict) and value.get("type") == "image"
    }
    if set(image_references) != {expected_app_screen}:
        record(
            f"Chapter {chapter_number} must compile exactly its app-screen image "
            f"{expected_app_screen}; found {', '.join(sorted(image_references)) or 'none'}"
        )
    app_screen_reference = image_references.get(expected_app_screen, {})
    alt = app_screen_reference.get("alt")
    register_alt(expected_app_screen, alt)
    if isinstance(alt, str) and "AI 생성" not in alt:
        record(f"Chapter {chapter_number} app-screen alt must identify the AI-generated concept")
    variants = app_screen_reference.get("variants", [])
    if not variants:
        record(f"app-screen image has no compiled asset URL: {expected_app_screen}")
    for variant in variants:
        url = variant.get("url") if isinstance(variant, dict) else None
        if not isinstance(url, str) or not url.startswith("/images/"):
            record(f"invalid compiled app-screen image URL for {expected_app_screen}: {url!r}")
            continue
        require_nonempty(archive / unquote(url.lstrip("/")), "compiled app-screen image asset")

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

    for image_name in sorted(chapter_images):
        reference = image_references.get(image_name, {})
        alt = reference.get("alt")
        register_alt(image_name, alt)

        variants = reference.get("variants", [])
        urls = [item.get("url") for item in variants if isinstance(item, dict)]
        if not urls:
            record(f"chapter image has no compiled asset URL: {image_name}")
        for url in urls:
            if not isinstance(url, str) or not url.startswith("/images/"):
                record(f"invalid compiled chapter image URL for {image_name}: {url!r}")
                continue
            require_nonempty(archive / unquote(url.lstrip("/")), "compiled image asset")

    expected_overview_chapters = [
        (
            "Chapter 1 — Closed World",
            "chapter-1-closed-world.png",
            "doc://com.techmap.scenekittorealitykit/tutorials/SceneKitToRealityKit/01-ClosedWorld",
        ),
        (
            "Chapter 2 — Opening Reality",
            "chapter-2-opening-reality.png",
            "doc://com.techmap.scenekittorealitykit/tutorials/SceneKitToRealityKit/02-OpeningTheDoor",
        ),
        (
            "Chapter 3 — Real Hide and Seek",
            "chapter-3-real-hide-and-seek.png",
            "doc://com.techmap.scenekittorealitykit/tutorials/SceneKitToRealityKit/03-RealHideAndSeek",
        ),
        (
            "Chapter 4 — Comparing Worlds",
            "chapter-4-comparing-worlds.png",
            "doc://com.techmap.scenekittorealitykit/tutorials/SceneKitToRealityKit/04-Comparison",
        ),
    ]
    volumes = [section for section in overview.get("sections", []) if section.get("kind") == "volume"]
    if len(volumes) != 1:
        record("tutorial overview must compile exactly one volume section")
    else:
        compiled_mapping = []
        for chapter in volumes[0].get("chapters", []):
            tutorials = chapter.get("tutorials", [])
            compiled_mapping.append(
                (
                    chapter.get("name"),
                    chapter.get("image"),
                    tutorials[0] if len(tutorials) == 1 else None,
                )
            )
        if compiled_mapping != expected_overview_chapters:
            record(f"tutorial overview chapter/hero/tutorial mapping is incorrect: {compiled_mapping!r}")

if len(seen_alt) != len(all_visual_images):
    record(f"expected eight unique visual alt texts, found {len(seen_alt)}")

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
print("Routes: 5 documentation + 5 tutorial; visual images: 8; locale: ko-KR")
print("Visual SHA-256 pins, full PNG decoding, and source/compiled byte identity are verified")
print("Links, placeholders, alt text, route assets, and theme assets are resolved")
PY
