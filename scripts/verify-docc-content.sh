#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG_REL="Tutorials/SceneKitToRealityKit.docc"
CATALOG="$REPO_ROOT/$CATALOG_REL"
TUTORIAL_DIR="$CATALOG/Tutorials"
SNIPPET_DIR="$TUTORIAL_DIR/Resources"
OVERVIEW="$CATALOG/SceneKitToRealityKit.tutorial"
TECHNOLOGY_ROOT_ARTICLE="$CATALOG/SceneKitToRealityKit.md"
PROJECT_FILE="$REPO_ROOT/PiggyEscape/Project.swift"
APP_LOCAL_CATALOG="$REPO_ROOT/PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc"

ERROR_COUNT=0
FORBIDDEN_MATCH_COUNT=0
TYPECHECK_PASS_COUNT=0
TYPECHECK_EXPECTED_COUNT=12

TEMP_ROOT="${TMPDIR:-/tmp}"
if ! VERIFY_TEMP_DIR="$(mktemp -d "$TEMP_ROOT/verify-docc-content.XXXXXX")"; then
    printf 'ERROR: could not create a temporary verification directory\n' >&2
    exit 2
fi
trap 'rm -rf "$VERIFY_TEMP_DIR"' EXIT

fail() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
    printf 'ERROR: %s\n' "$*" >&2
}

count_fixed() {
    local file="$1"
    local literal="$2"

    if [[ ! -f "$file" ]]; then
        printf '0\n'
        return
    fi

    (grep -F -o -- "$literal" "$file" 2>/dev/null || true) \
        | wc -l \
        | tr -d '[:space:]'
}

count_regex() {
    local file="$1"
    local pattern="$2"

    if [[ ! -f "$file" ]]; then
        printf '0\n'
        return
    fi

    (grep -E -o -- "$pattern" "$file" 2>/dev/null || true) \
        | wc -l \
        | tr -d '[:space:]'
}

require_file() {
    local file="$1"
    local label="$2"

    if [[ ! -f "$file" ]]; then
        fail "$label is missing: ${file#"$REPO_ROOT/"}"
        return 1
    fi
    return 0
}

require_fixed_count() {
    local file="$1"
    local literal="$2"
    local expected="$3"
    local label="$4"
    local actual

    actual="$(count_fixed "$file" "$literal")"
    if [[ "$actual" != "$expected" ]]; then
        fail "$label: expected $expected occurrence(s) of '$literal', found $actual"
    fi
}

require_regex_count() {
    local file="$1"
    local pattern="$2"
    local expected="$3"
    local label="$4"
    local actual

    actual="$(count_regex "$file" "$pattern")"
    if [[ "$actual" != "$expected" ]]; then
        fail "$label: expected $expected occurrence(s), found $actual"
    fi
}

require_regex() {
    local file="$1"
    local pattern="$2"
    local label="$3"

    if [[ ! -f "$file" ]] || ! grep -E -q -- "$pattern" "$file" 2>/dev/null; then
        fail "$label"
    fi
}

require_token_order() {
    local file="$1"
    local label="$2"
    shift 2

    if [[ ! -f "$file" ]]; then
        fail "$label: source file is missing"
        return
    fi

    if ! perl -0777 -e '
        my $file = shift @ARGV;
        open my $handle, "<", $file or exit 2;
        local $/;
        my $source = <$handle>;
        my $cursor = -1;
        for my $token (@ARGV) {
            my $position = index($source, $token);
            exit 1 if $position < 0 || $position <= $cursor;
            $cursor = $position;
        }
        exit 0;
    ' "$file" "$@"; then
        fail "$label"
    fi
}

extract_directive_body() {
    local file="$1"
    local directive="$2"

    perl -0777 -e '
        my ($file, $directive) = @ARGV;
        open my $handle, "<", $file or exit 2;
        local $/;
        my $source = <$handle>;
        my $pattern = qr/\@\Q$directive\E\b(?:\s*\([^)]*\))?\s*\{/;
        exit 3 unless $source =~ /$pattern/g;

        my $body_start = pos($source);
        my $cursor = $body_start;
        my $depth = 1;
        while ($cursor < length($source) && $depth > 0) {
            my $character = substr($source, $cursor, 1);
            $depth += 1 if $character eq "{";
            $depth -= 1 if $character eq "}";
            $cursor += 1;
        }
        exit 4 unless $depth == 0;

        my $body_length = $cursor - $body_start - 1;
        print substr($source, $body_start, $body_length);
    ' "$file" "$directive"
}

write_expected_inventory() {
    local destination="$1"
    shift
    printf '%s\n' "$@" | LC_ALL=C sort > "$destination"
}

compare_inventory() {
    local label="$1"
    local expected_file="$2"
    local actual_file="$3"
    local path

    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        fail "$label is missing expected file: $path"
    done < <(comm -23 "$expected_file" "$actual_file")

    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        fail "$label contains unexpected file: $path"
    done < <(comm -13 "$expected_file" "$actual_file")
}

forbid_catalog_regex() {
    local label="$1"
    local pattern="$2"
    local output_file="$VERIFY_TEMP_DIR/forbidden-$ERROR_COUNT.log"
    local match_count

    if [[ "${#SEMANTIC_FILES[@]}" -eq 0 ]]; then
        return
    fi

    grep -E -n -H -- "$pattern" "${SEMANTIC_FILES[@]}" > "$output_file" 2>/dev/null || true
    if [[ ! -s "$output_file" ]]; then
        return
    fi

    match_count="$(wc -l < "$output_file" | tr -d '[:space:]')"
    FORBIDDEN_MATCH_COUNT=$((FORBIDDEN_MATCH_COUNT + match_count))
    fail "$label ($match_count match(es))"
    sed "s#^$REPO_ROOT/##" "$output_file" >&2
}

verify_each_step() {
    local file="$1"
    local expected_steps="$2"
    local label="$3"
    local step_index code_count run_count recovery_count
    local parsed_count=0

    if [[ ! -f "$file" ]]; then
        return
    fi

    while IFS=$'\t' read -r step_index code_count run_count recovery_count; do
        [[ -n "$step_index" ]] || continue
        parsed_count=$((parsed_count + 1))
        if [[ "$code_count" != "1" ]]; then
            fail "$label step $step_index must contain exactly one @Code, found $code_count"
        fi
        if [[ "$run_count" != "1" ]]; then
            fail "$label step $step_index must contain exactly one '실행 확인:', found $run_count"
        fi
        if [[ "$recovery_count" != "1" ]]; then
            fail "$label step $step_index must contain exactly one '실패·복구:', found $recovery_count"
        fi
    done < <(perl -0777 -ne '
        my $source = $_;
        my $step = 0;
        while ($source =~ /\@Step\b[ \t\r\n]*\{/g) {
            $step += 1;
            my $body_start = pos($source);
            my $cursor = $body_start;
            my $depth = 1;
            while ($cursor < length($source) && $depth > 0) {
                my $character = substr($source, $cursor, 1);
                $depth += 1 if $character eq "{";
                $depth -= 1 if $character eq "}";
                $cursor += 1;
            }
            my $body_length = $cursor - $body_start - 1;
            $body_length = 0 if $body_length < 0;
            my $body = substr($source, $body_start, $body_length);
            my $code = () = $body =~ /\@Code\s*\(/g;
            my $run = () = $body =~ /실행 확인:/g;
            my $recovery = () = $body =~ /실패·복구:/g;
            print "$step\t$code\t$run\t$recovery\n";
            pos($source) = $cursor;
        }
    ' "$file")

    if [[ "$parsed_count" != "$expected_steps" ]]; then
        fail "$label: expected $expected_steps @Step block(s), parsed $parsed_count"
    fi
}

EXPECTED_TUTORIALS_FILE="$VERIFY_TEMP_DIR/expected-tutorials.txt"
ACTUAL_TUTORIALS_FILE="$VERIFY_TEMP_DIR/actual-tutorials.txt"
EXPECTED_ARTICLES_FILE="$VERIFY_TEMP_DIR/expected-articles.txt"
ACTUAL_ARTICLES_FILE="$VERIFY_TEMP_DIR/actual-articles.txt"
EXPECTED_SNIPPETS_FILE="$VERIFY_TEMP_DIR/expected-snippets.txt"
ACTUAL_SNIPPETS_FILE="$VERIFY_TEMP_DIR/actual-snippets.txt"
EXPECTED_SNIPPET_NAMES_FILE="$VERIFY_TEMP_DIR/expected-snippet-names.txt"
EXPECTED_IMAGES_FILE="$VERIFY_TEMP_DIR/expected-images.txt"
ACTUAL_IMAGES_FILE="$VERIFY_TEMP_DIR/actual-images.txt"

write_expected_inventory "$EXPECTED_TUTORIALS_FILE" \
    "SceneKitToRealityKit.tutorial" \
    "Tutorials/01-ClosedWorld.tutorial" \
    "Tutorials/02-OpeningTheDoor.tutorial" \
    "Tutorials/03-RealHideAndSeek.tutorial" \
    "Tutorials/04-Comparison.tutorial"

write_expected_inventory "$EXPECTED_ARTICLES_FILE" \
    "Articles/DeviceCameraDiagnostics.md" \
    "Articles/MigrationWorksheet.md" \
    "Articles/RealityKitECS.md" \
    "Articles/SceneGraphDeepDive.md" \
    "SceneKitToRealityKit.md"

CANONICAL_SNIPPETS=(
    "01-ClosedWorld-01-ExperienceState.swift"
    "01-ClosedWorld-02-C3SceneAndInput.swift"
    "01-ClosedWorld-03-AutoDiscovery.swift"
    "02-OpeningReality-01-CameraAuthorization.swift"
    "02-OpeningReality-02-SessionReadiness.swift"
    "02-OpeningReality-03-ScanFeedbackAndGate.swift"
    "03-RealHideAndSeek-01-ScaleAndFloorPlan.swift"
    "03-RealHideAndSeek-02-ViewSpaceSamples.swift"
    "03-RealHideAndSeek-03-StableOcclusion.swift"
    "03-RealHideAndSeek-04-CycleRecovery.swift"
    "04-Comparison-01-ComparisonModel.swift"
    "04-Comparison-02-ReplayRouting.swift"
)

CHAPTER_HERO_IMAGES=(
    "chapter-1-closed-world.png"
    "chapter-2-opening-reality.png"
    "chapter-3-real-hide-and-seek.png"
    "chapter-4-comparing-worlds.png"
)

APP_SCREEN_IMAGES=(
    "app-screen-chapter-1-closed-world.png"
    "app-screen-chapter-2-scanning.png"
    "app-screen-chapter-3-searching.png"
    "app-screen-chapter-4-comparison.png"
)

write_expected_inventory "$EXPECTED_IMAGES_FILE" \
    "${CHAPTER_HERO_IMAGES[@]}" \
    "${APP_SCREEN_IMAGES[@]}"

: > "$EXPECTED_SNIPPETS_FILE"
: > "$EXPECTED_SNIPPET_NAMES_FILE"
for snippet_name in "${CANONICAL_SNIPPETS[@]}"; do
    printf 'Tutorials/Resources/%s\n' "$snippet_name" >> "$EXPECTED_SNIPPETS_FILE"
    printf '%s\n' "$snippet_name" >> "$EXPECTED_SNIPPET_NAMES_FILE"
done
LC_ALL=C sort -o "$EXPECTED_SNIPPETS_FILE" "$EXPECTED_SNIPPETS_FILE"
LC_ALL=C sort -o "$EXPECTED_SNIPPET_NAMES_FILE" "$EXPECTED_SNIPPET_NAMES_FILE"

if [[ ! -d "$CATALOG" ]]; then
    fail "root DocC catalog is missing: $CATALOG_REL"
    : > "$ACTUAL_TUTORIALS_FILE"
    : > "$ACTUAL_ARTICLES_FILE"
    : > "$ACTUAL_SNIPPETS_FILE"
    : > "$ACTUAL_IMAGES_FILE"
else
    (
        cd "$CATALOG" || exit 1
        find . -type f -name '*.tutorial' -print \
            | sed 's#^\./##' \
            | LC_ALL=C sort
    ) > "$ACTUAL_TUTORIALS_FILE"
    (
        cd "$CATALOG" || exit 1
        find . -type f -name '*.md' -print \
            | sed 's#^\./##' \
            | LC_ALL=C sort
    ) > "$ACTUAL_ARTICLES_FILE"
    (
        cd "$CATALOG" || exit 1
        find . -type f -name '*.swift' -print \
            | sed 's#^\./##' \
            | LC_ALL=C sort
    ) > "$ACTUAL_SNIPPETS_FILE"
    (
        cd "$CATALOG/Resources" || exit 1
        find . -maxdepth 1 -type f -name '*.png' -print \
            | sed 's#^\./##' \
            | LC_ALL=C sort
    ) > "$ACTUAL_IMAGES_FILE"
fi

if [[ -d "$APP_LOCAL_CATALOG" ]]; then
    fail "app-local duplicate DocC catalog still exists: PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc"
fi

compare_inventory "DocC tutorial inventory" "$EXPECTED_TUTORIALS_FILE" "$ACTUAL_TUTORIALS_FILE"
compare_inventory "DocC article inventory" "$EXPECTED_ARTICLES_FILE" "$ACTUAL_ARTICLES_FILE"
compare_inventory "DocC snippet inventory" "$EXPECTED_SNIPPETS_FILE" "$ACTUAL_SNIPPETS_FILE"
compare_inventory "DocC visual asset inventory" "$EXPECTED_IMAGES_FILE" "$ACTUAL_IMAGES_FILE"

if ! python3 - "$CATALOG/Resources" <<'PY'
import hashlib
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
expected = {
    "chapter-1-closed-world.png": (
        (1536, 1024),
        "9979438c892484fab2db5d6b27bb9f4a538042d3ada3b183e2a559e5194f09c2",
    ),
    "chapter-2-opening-reality.png": (
        (1536, 1024),
        "026a6d1aa03fea750eb1c745690de5c86f2ceb33318c1521c51ad5cf3334bb2d",
    ),
    "chapter-3-real-hide-and-seek.png": (
        (1536, 1024),
        "9331925e7efc13cfb84dc4a39bc2553a699784ec9429dbe23242c6559330a020",
    ),
    "chapter-4-comparing-worlds.png": (
        (1536, 1024),
        "7ef77fcae8d6532a39dc2b2904d17a2d6c6b0c9513c3d8b480fafd2d11f4195d",
    ),
    "app-screen-chapter-1-closed-world.png": (
        (1024, 1536),
        "62fc0b98e4652cacd0812271afc3ec237b31c38fb9f340864498176b550f2385",
    ),
    "app-screen-chapter-2-scanning.png": (
        (1024, 1536),
        "fdedf18639979dbdbf3e1730359894bc95d2a59c04c47dd1dd769b2e8217b068",
    ),
    "app-screen-chapter-3-searching.png": (
        (1024, 1536),
        "3d6b41d7d6ca55ce2b1aee08fe1d01afbef960735e2032ea8826684669a46f7d",
    ),
    "app-screen-chapter-4-comparison.png": (
        (1024, 1536),
        "e7bd0e4121a9ce33c3a83836f8fcaf7215641e224114d1fe0ce31e57c583559f",
    ),
}
errors = []
digests = {}
sips = shutil.which("sips")

if sips is None:
    errors.append("full PNG decoder is unavailable: sips")

with tempfile.TemporaryDirectory(prefix="verify-docc-png-decode-") as decode_root:
    for name, (expected_size, approved_digest) in expected.items():
        path = root / name
        if not path.is_file():
            errors.append(f"missing PNG: {name}")
            continue
        data = path.read_bytes()
        if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            errors.append(f"invalid PNG header: {name}")
            continue
        actual_size = struct.unpack(">II", data[16:24])
        if actual_size != expected_size:
            errors.append(f"wrong dimensions for {name}: expected {expected_size}, found {actual_size}")
        digest = hashlib.sha256(data).hexdigest()
        if digest != approved_digest:
            errors.append(
                f"unapproved SHA-256 for {name}: expected {approved_digest}, found {digest}"
            )
        if digest in digests:
            errors.append(f"duplicate image bytes: {digests[digest]} and {name}")
        else:
            digests[digest] = name

        if sips is not None:
            decoded_path = Path(decode_root) / f"{path.stem}.tiff"
            decoded = subprocess.run(
                [sips, "-s", "format", "tiff", str(path), "--out", str(decoded_path)],
                capture_output=True,
                text=True,
            )
            if decoded.returncode != 0 or not decoded_path.is_file() or decoded_path.stat().st_size == 0:
                detail = decoded.stderr.strip().splitlines()
                suffix = f": {detail[-1]}" if detail else ""
                errors.append(f"full PNG decode failed for {name}{suffix}")

for error in errors:
    print(error, file=sys.stderr)
sys.exit(1 if errors else 0)
PY
then
    fail "DocC visual assets must match the eight approved SHA-256 pins and pass full PNG decoding"
fi

APP_SOURCES_EXPECTED="$VERIFY_TEMP_DIR/app-sources-expected.txt"
APP_SOURCES_ACTUAL="$VERIFY_TEMP_DIR/app-sources-actual.txt"
printf '%s\n' 'PiggyEscape/Sources/**' > "$APP_SOURCES_EXPECTED"
: > "$APP_SOURCES_ACTUAL"
if require_file "$PROJECT_FILE" "Tuist project manifest"; then
    perl -0777 -ne '
        if (/\.target\s*\(\s*name:\s*"PiggyEscape".*?sources:\s*\[([^\]]*)\]/s) {
            my $sources = $1;
            while ($sources =~ /"([^"]+)"/g) {
                print "$1\n";
            }
        }
    ' "$PROJECT_FILE" | LC_ALL=C sort > "$APP_SOURCES_ACTUAL"
    if [[ ! -s "$APP_SOURCES_ACTUAL" ]]; then
        fail "could not extract the PiggyEscape app target sources from PiggyEscape/Project.swift"
    else
        compare_inventory "PiggyEscape app source glob" "$APP_SOURCES_EXPECTED" "$APP_SOURCES_ACTUAL"
    fi
fi

TUTORIAL_FILES=(
    "$TUTORIAL_DIR/01-ClosedWorld.tutorial"
    "$TUTORIAL_DIR/02-OpeningTheDoor.tutorial"
    "$TUTORIAL_DIR/03-RealHideAndSeek.tutorial"
    "$TUTORIAL_DIR/04-Comparison.tutorial"
)
ARTICLE_FILES=(
    "$CATALOG/Articles/SceneGraphDeepDive.md"
    "$CATALOG/Articles/RealityKitECS.md"
    "$CATALOG/Articles/DeviceCameraDiagnostics.md"
    "$CATALOG/Articles/MigrationWorksheet.md"
    "$TECHNOLOGY_ROOT_ARTICLE"
)
SEMANTIC_FILES=()
for source_file in "$OVERVIEW" "${TUTORIAL_FILES[@]}" "${ARTICLE_FILES[@]}"; do
    if [[ -f "$source_file" ]]; then
        SEMANTIC_FILES+=("$source_file")
    fi
done
if [[ -d "$SNIPPET_DIR" ]]; then
    while IFS= read -r source_file; do
        SEMANTIC_FILES+=("$source_file")
    done < <(find "$SNIPPET_DIR" -type f -name '*.swift' -print | LC_ALL=C sort)
fi

require_file "$OVERVIEW" "DocC overview"
for source_file in "${TUTORIAL_FILES[@]}" "${ARTICLE_FILES[@]}"; do
    require_file "$source_file" "canonical DocC source"
done

if [[ -f "$TECHNOLOGY_ROOT_ARTICLE" ]]; then
    require_fixed_count "$TECHNOLOGY_ROOT_ARTICLE" '@TechnologyRoot' 1 "technology-root article metadata"
    require_regex_count "$TECHNOLOGY_ROOT_ARTICLE" '^##[[:space:]]+Topics[[:space:]]*$' 1 "technology-root article Topics section"

    ROOT_TOPICS_BODY="$VERIFY_TEMP_DIR/technology-root-topics-body.txt"
    EXPECTED_ROOT_TOPIC_IDS="$VERIFY_TEMP_DIR/expected-root-topic-ids.txt"
    ACTUAL_ROOT_TOPIC_IDS="$VERIFY_TEMP_DIR/actual-root-topic-ids.txt"
    write_expected_inventory "$EXPECTED_ROOT_TOPIC_IDS" \
        DeviceCameraDiagnostics \
        MigrationWorksheet \
        RealityKitECS \
        SceneGraphDeepDive

    if perl -0777 -e '
        my $file = shift @ARGV;
        open my $handle, "<", $file or exit 2;
        local $/;
        my $source = <$handle>;
        exit 3 unless $source =~ /^##[ \t]+Topics[ \t]*\r?\n(.*?)(?=^##[ \t]+|\z)/ms;
        print $1;
    ' "$TECHNOLOGY_ROOT_ARTICLE" > "$ROOT_TOPICS_BODY"; then
        perl -ne '
            while (/^[ \t]*-[ \t]*<doc:([A-Za-z0-9][A-Za-z0-9_-]*)>/g) {
                print "$1\n";
            }
        ' "$ROOT_TOPICS_BODY" > "$ACTUAL_ROOT_TOPIC_IDS"

        root_topic_count="$(wc -l < "$ACTUAL_ROOT_TOPIC_IDS" | tr -d '[:space:]')"
        if [[ "$root_topic_count" != "4" ]]; then
            fail "technology-root ## Topics must contain exactly four article links, found $root_topic_count"
        fi
        LC_ALL=C sort -u -o "$ACTUAL_ROOT_TOPIC_IDS" "$ACTUAL_ROOT_TOPIC_IDS"
        compare_inventory "technology-root ## Topics article link" "$EXPECTED_ROOT_TOPIC_IDS" "$ACTUAL_ROOT_TOPIC_IDS"
    else
        fail "technology-root article contains no parseable ## Topics section"
    fi
fi

technology_root_count=0
if [[ "${#SEMANTIC_FILES[@]}" -gt 0 ]]; then
    technology_root_count="$(
        (grep -F -h -o '@TechnologyRoot' "${SEMANTIC_FILES[@]}" 2>/dev/null || true) \
            | wc -l \
            | tr -d '[:space:]'
    )"
fi
if [[ "$technology_root_count" != "1" ]]; then
    fail "DocC semantic sources must contain exactly one @TechnologyRoot in SceneKitToRealityKit.md, found $technology_root_count"
fi
for ordinary_article in \
    "$CATALOG/Articles/SceneGraphDeepDive.md" \
    "$CATALOG/Articles/RealityKitECS.md" \
    "$CATALOG/Articles/DeviceCameraDiagnostics.md" \
    "$CATALOG/Articles/MigrationWorksheet.md"; do
    if [[ -f "$ordinary_article" ]]; then
        require_fixed_count "$ordinary_article" '@TechnologyRoot' 0 "ordinary article must not declare @TechnologyRoot"
    fi
done

if [[ -f "$OVERVIEW" ]]; then
    require_fixed_count "$OVERVIEW" '@Chapter(name:' 4 "overview chapter count"
    require_fixed_count "$OVERVIEW" '@TutorialReference(tutorial:' 4 "overview tutorial-reference count"
    require_token_order "$OVERVIEW" "overview chapter names and tutorial references must use the exact stable mapping and order" \
        '@Chapter(name: "Chapter 1 — Closed World")' \
        '@TutorialReference(tutorial: "doc:01-ClosedWorld")' \
        '@Chapter(name: "Chapter 2 — Opening Reality")' \
        '@TutorialReference(tutorial: "doc:02-OpeningTheDoor")' \
        '@Chapter(name: "Chapter 3 — Real Hide and Seek")' \
        '@TutorialReference(tutorial: "doc:03-RealHideAndSeek")' \
        '@Chapter(name: "Chapter 4 — Comparing Worlds")' \
        '@TutorialReference(tutorial: "doc:04-Comparison")'

    require_regex_count "$OVERVIEW" '@Documentation[[:space:]]*\([[:space:]]*destination:' 1 "overview @Resources documentation block count"
    require_regex_count "$OVERVIEW" '@Documentation[[:space:]]*\([[:space:]]*destination:[[:space:]]*"/documentation/scenekittorealitykit/scenegraphdeepdive"[[:space:]]*\)' 1 "overview documentation destination"

    OVERVIEW_RESOURCES_BODY="$VERIFY_TEMP_DIR/overview-resources-body.txt"
    OVERVIEW_DOCUMENTATION_BODY="$VERIFY_TEMP_DIR/overview-documentation-body.txt"
    EXPECTED_RESOURCE_LINK_IDS="$VERIFY_TEMP_DIR/expected-resource-link-ids.txt"
    ACTUAL_RESOURCE_LINK_IDS="$VERIFY_TEMP_DIR/actual-resource-link-ids.txt"

    write_expected_inventory "$EXPECTED_RESOURCE_LINK_IDS" \
        DeviceCameraDiagnostics \
        MigrationWorksheet \
        RealityKitECS \
        SceneGraphDeepDive

    if extract_directive_body "$OVERVIEW" Resources > "$OVERVIEW_RESOURCES_BODY"; then
        require_regex_count "$OVERVIEW_RESOURCES_BODY" '@Documentation[[:space:]]*\(' 1 "overview @Resources must contain exactly one @Documentation block"

        if extract_directive_body "$OVERVIEW_RESOURCES_BODY" Documentation > "$OVERVIEW_DOCUMENTATION_BODY"; then
            perl -ne '
                while (/^[ \t]*-[ \t]*\[[^]]+\]\(doc:([A-Za-z0-9][A-Za-z0-9_-]*)\)/g) {
                    print "$1\n";
                }
            ' "$OVERVIEW_DOCUMENTATION_BODY" > "$ACTUAL_RESOURCE_LINK_IDS"

            resource_link_count="$(wc -l < "$ACTUAL_RESOURCE_LINK_IDS" | tr -d '[:space:]')"
            if [[ "$resource_link_count" != "4" ]]; then
                fail "overview @Documentation must contain exactly four article list-item links, found $resource_link_count"
            fi
            LC_ALL=C sort -u -o "$ACTUAL_RESOURCE_LINK_IDS" "$ACTUAL_RESOURCE_LINK_IDS"
            compare_inventory "overview @Documentation article link" "$EXPECTED_RESOURCE_LINK_IDS" "$ACTUAL_RESOURCE_LINK_IDS"
        else
            fail "overview @Resources contains no parseable @Documentation body"
        fi
    else
        fail "overview contains no parseable @Resources body"
    fi
fi

RAW_CODE_REFS="$VERIFY_TEMP_DIR/raw-code-refs.txt"
ACTUAL_CODE_REF_NAMES="$VERIFY_TEMP_DIR/actual-code-ref-names.txt"
: > "$RAW_CODE_REFS"
if [[ "${#TUTORIAL_FILES[@]}" -gt 0 ]]; then
    perl -0777 -ne '
        while (/\@Code\s*\([^)]*\bfile\s*:\s*"([^"]+)"/sg) {
            print "$1\n";
        }
    ' "${TUTORIAL_FILES[@]}" > "$RAW_CODE_REFS"
fi
LC_ALL=C sort -u "$RAW_CODE_REFS" > "$ACTUAL_CODE_REF_NAMES"
compare_inventory "tutorial @Code reference set" "$EXPECTED_SNIPPET_NAMES_FILE" "$ACTUAL_CODE_REF_NAMES"

raw_code_ref_count="$(wc -l < "$RAW_CODE_REFS" | tr -d '[:space:]')"
if [[ "$raw_code_ref_count" != "12" ]]; then
    fail "tutorials must contain exactly 12 @Code file references, found $raw_code_ref_count"
fi
while IFS= read -r code_ref; do
    [[ -n "$code_ref" ]] || continue
    if [[ "$code_ref" == */* ]] || [[ ! -f "$SNIPPET_DIR/$code_ref" ]]; then
        fail "@Code references a missing or non-canonical snippet: $code_ref"
    fi
done < "$RAW_CODE_REFS"

EXPECTED_DOC_IDS="$VERIFY_TEMP_DIR/expected-doc-ids.txt"
ACTUAL_DOC_IDS="$VERIFY_TEMP_DIR/actual-doc-ids.txt"
write_expected_inventory "$EXPECTED_DOC_IDS" \
    "01-ClosedWorld" \
    "02-OpeningTheDoor" \
    "03-RealHideAndSeek" \
    "04-Comparison" \
    "DeviceCameraDiagnostics" \
    "MigrationWorksheet" \
    "RealityKitECS" \
    "SceneKitToRealityKit" \
    "SceneGraphDeepDive"
: > "$ACTUAL_DOC_IDS"
if [[ "${#SEMANTIC_FILES[@]}" -gt 0 ]]; then
    perl -ne 'while (/\bdoc:([A-Za-z0-9][A-Za-z0-9_-]*)/g) { print "$1\n" }' \
        "${SEMANTIC_FILES[@]}" \
        | LC_ALL=C sort -u > "$ACTUAL_DOC_IDS"
fi
while IFS= read -r doc_id; do
    [[ -n "$doc_id" ]] || continue
    if ! grep -F -x -q -- "$doc_id" "$EXPECTED_DOC_IDS"; then
        fail "DocC source references a non-canonical doc ID: doc:$doc_id"
    fi
done < "$ACTUAL_DOC_IDS"

CH1="${TUTORIAL_FILES[0]}"
CH2="${TUTORIAL_FILES[1]}"
CH3="${TUTORIAL_FILES[2]}"
CH4="${TUTORIAL_FILES[3]}"

if ! python3 - "$OVERVIEW" "$CH1" "$CH2" "$CH3" "$CH4" <<'PY'
import re
import sys
from pathlib import Path

overview_path, *chapter_paths = map(Path, sys.argv[1:])
disclosure = "AI 생성 앱 화면 컨셉 · 실제 앱 실행 화면/실기기 캡처 아님"
expected_heroes = (
    "chapter-1-closed-world",
    "chapter-2-opening-reality",
    "chapter-3-real-hide-and-seek",
    "chapter-4-comparing-worlds",
)
expected_chapters = (
    (
        "선언된 섬 안에서만 보고 선택하기",
        "app-screen-chapter-1-closed-world",
        "01-ClosedWorld-02-C3SceneAndInput.swift",
    ),
    (
        "실제 스캔을 보여 주고 CTA 뒤에만 입력 열기",
        "app-screen-chapter-2-scanning",
        "02-OpeningReality-03-ScanFeedbackAndGate.swift",
    ),
    (
        "가림과 재발견을 서로 다른 두 frame으로 확인하기",
        "app-screen-chapter-3-searching",
        "03-RealHideAndSeek-03-StableOcclusion.swift",
    ),
    (
        "경험을 네 비교 축으로 정렬하기",
        "app-screen-chapter-4-comparison",
        "04-Comparison-01-ComparisonModel.swift",
    ),
)
errors = []


def balanced_body(source, start, label):
    cursor = start
    depth = 1
    while cursor < len(source) and depth:
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
        cursor += 1
    if depth:
        errors.append(f"unterminated {label}")
        return "", start
    return source[start : cursor - 1], cursor


def section_body(source, title, chapter_number):
    matches = list(
        re.finditer(
            rf'@Section\s*\(\s*title\s*:\s*"{re.escape(title)}"\s*\)\s*\{{',
            source,
        )
    )
    if len(matches) != 1:
        errors.append(
            f"Chapter {chapter_number} must contain exactly one target section {title!r}; found {len(matches)}"
        )
        return ""
    return balanced_body(source, matches[0].end(), f"Chapter {chapter_number} target section")[0]


image_pattern = re.compile(
    r'@Image\s*\(\s*source\s*:\s*([A-Za-z0-9._-]+)\s*,\s*alt\s*:\s*"([^"]+)"\s*\)',
    re.DOTALL,
)
all_images = []

if overview_path.is_file():
    overview_source = overview_path.read_text(encoding="utf-8")
    overview_images = image_pattern.findall(overview_source)
    all_images.extend(overview_images)
    actual_heroes = tuple(source for source, _ in overview_images)
    if actual_heroes != expected_heroes:
        errors.append(
            "overview hero images must match the four ordered chapter mappings; "
            f"found {actual_heroes!r}"
        )
else:
    errors.append(f"missing overview source: {overview_path}")

for chapter_number, (path, expected) in enumerate(zip(chapter_paths, expected_chapters), start=1):
    title, expected_image, related_code = expected
    if not path.is_file():
        errors.append(f"missing Chapter {chapter_number} source: {path}")
        continue
    source = path.read_text(encoding="utf-8")
    body = section_body(source, title, chapter_number)
    if not body:
        continue

    content_matches = list(re.finditer(r'@ContentAndMedia\b(?:\s*\([^)]*\))?\s*\{', body))
    if len(content_matches) != 1:
        errors.append(
            f"Chapter {chapter_number} target section must contain exactly one @ContentAndMedia; "
            f"found {len(content_matches)}"
        )
        continue

    content_match = content_matches[0]
    content_body, content_end = balanced_body(
        body,
        content_match.end(),
        f"Chapter {chapter_number} @ContentAndMedia",
    )
    if content_body.count(disclosure) != 1:
        errors.append(
            f"Chapter {chapter_number} @ContentAndMedia must contain exactly one explicit AI disclosure"
        )

    images = image_pattern.findall(content_body)
    if len(images) != 1:
        errors.append(
            f"Chapter {chapter_number} @ContentAndMedia must contain exactly one image; found {len(images)}"
        )
    else:
        image_source, image_alt = images[0]
        all_images.append((image_source, image_alt))
        if image_source != expected_image:
            errors.append(
                f"Chapter {chapter_number} app-screen image must be {expected_image}; found {image_source}"
            )
        if "AI 생성" not in image_alt:
            errors.append(f"Chapter {chapter_number} app-screen alt must identify the AI-generated concept")

    disclosure_position = content_body.find(disclosure)
    image_position = content_body.find("@Image")
    if disclosure_position < 0 or image_position < 0 or disclosure_position >= image_position:
        errors.append(f"Chapter {chapter_number} must place the disclosure before its app-screen image")

    code_match = re.search(
        rf'@Code\s*\([^)]*\bfile\s*:\s*"{re.escape(related_code)}"',
        body,
        re.DOTALL,
    )
    if code_match is None:
        errors.append(f"Chapter {chapter_number} target section is missing related code {related_code}")
    elif code_match.start() <= content_end:
        errors.append(f"Chapter {chapter_number} related code must follow @ContentAndMedia")

expected_all_images = set(expected_heroes) | {item[1] for item in expected_chapters}
actual_sources = [source for source, _ in all_images]
if set(actual_sources) != expected_all_images or len(actual_sources) != len(expected_all_images):
    errors.append(
        "DocC sources must contain each of the eight approved visual images exactly once; "
        f"found {actual_sources!r}"
    )

seen_alt = {}
for image_source, alt in all_images:
    normalized = " ".join(alt.split()).casefold()
    if not normalized:
        errors.append(f"missing source alt text for {image_source}")
    elif normalized in seen_alt:
        errors.append(f"duplicate source alt text for {seen_alt[normalized]} and {image_source}")
    else:
        seen_alt[normalized] = image_source

for error in errors:
    print(error, file=sys.stderr)
sys.exit(1 if errors else 0)
PY
then
    fail "DocC visual narratives must map each generated concept screen to its target section and related code"
fi

verify_each_step "$CH1" 3 "Chapter 1"
verify_each_step "$CH2" 3 "Chapter 2"
verify_each_step "$CH3" 4 "Chapter 3"
verify_each_step "$CH4" 2 "Chapter 4"

if [[ -f "$CH1" ]]; then
    require_regex_count "$CH1" '^[[:space:]]*@Step[[:space:]]*\{' 3 "Chapter 1 @Step count"
    require_regex_count "$CH1" '@Code[[:space:]]*\(' 3 "Chapter 1 @Code count"
    require_fixed_count "$CH1" '실행 확인:' 3 "Chapter 1 execution-check count"
    require_fixed_count "$CH1" '실패·복구:' 3 "Chapter 1 failure-recovery count"
    require_fixed_count "$CH1" '01-ClosedWorld-01-ExperienceState.swift' 1 "Chapter 1 canonical code mapping"
    require_fixed_count "$CH1" '01-ClosedWorld-02-C3SceneAndInput.swift' 1 "Chapter 1 canonical code mapping"
    require_fixed_count "$CH1" '01-ClosedWorld-03-AutoDiscovery.swift' 1 "Chapter 1 canonical code mapping"
    require_regex "$CH1" 'C3' "Chapter 1 must describe C3"
    require_regex "$CH1" 'HideTree' "Chapter 1 must name HideTree"
    require_regex "$CH1" 'SCNCamera' "Chapter 1 must name SCNCamera"
    require_regex "$CH1" 'SCNView\.hitTest' "Chapter 1 must name SCNView.hitTest"
    require_regex "$CH1" '0\.40초' "Chapter 1 must keep the 0.40초 discovery delay"
    require_regex "$CH1" '0\.70초' "Chapter 1 must keep the 0.70초 handoff"
    require_regex "$CH1" '1\.5배' "Chapter 1 must keep the 1.5배 reaction scale"
    require_regex "$CH1" '1\.0배' "Chapter 1 must keep the 1.0배 restored scale"
    require_regex "$CH1" '(나레이션|narration).*(전|끝나기 전).*(탭|tap).*(무시|거부|받지|수용하지)' "Chapter 1 must state that taps before narration completion are rejected"
    require_regex "$CH1" '(자동.*(한 번|1회).*(발견|들킴)|한 번.*자동.*발견|자동.*발견.*(한 번|1회))' "Chapter 1 must describe one-shot automatic discovery"
    require_fixed_count "$CH1" '이 앱의 Chapter 1이 현실 입력을 연결하지 않았다' 1 "Chapter 1 scoped interpretation"
    require_fixed_count "$CH1" '<doc:02-OpeningTheDoor>' 1 "Chapter 1 next link"
fi

if [[ -f "$CH2" ]]; then
    require_regex_count "$CH2" '^[[:space:]]*@Step[[:space:]]*\{' 3 "Chapter 2 @Step count"
    require_regex_count "$CH2" '@Code[[:space:]]*\(' 3 "Chapter 2 @Code count"
    require_fixed_count "$CH2" '실행 확인:' 3 "Chapter 2 execution-check count"
    require_fixed_count "$CH2" '실패·복구:' 3 "Chapter 2 failure-recovery count"
    require_fixed_count "$CH2" '02-OpeningReality-01-CameraAuthorization.swift' 1 "Chapter 2 canonical code mapping"
    require_fixed_count "$CH2" '02-OpeningReality-02-SessionReadiness.swift' 1 "Chapter 2 canonical code mapping"
    require_fixed_count "$CH2" '02-OpeningReality-03-ScanFeedbackAndGate.swift' 1 "Chapter 2 canonical code mapping"
    require_regex "$CH2" 'ARView' "Chapter 2 must describe ARView"
    require_regex "$CH2" 'ARMeshAnchor' "Chapter 2 must describe ARMeshAnchor"
    require_regex "$CH2" '(classified[[:space:]]+horizontal[[:space:]]+floor|분류된.*수평.*floor|분류된 수평 바닥)' "Chapter 2 must require a classified horizontal floor"
    require_regex "$CH2" '((mesh|메시|메쉬).*(그리고|AND|&&|둘 다|모두).*(floor|바닥)|(floor|바닥).*(그리고|AND|&&|둘 다|모두).*(mesh|메시|메쉬))' "Chapter 2 readiness must require both mesh and floor"
    require_regex "$CH2" 'showSceneUnderstanding' "Chapter 2 must name showSceneUnderstanding"
    require_regex "$CH2" '공간 형태' "Chapter 2 must include the '공간 형태' mesh progress label"
    require_regex "$CH2" '바닥' "Chapter 2 must include independent floor progress"
    require_regex "$CH2" '((one-shot|한 번만|1회).*완료|완료.*(one-shot|한 번만|1회))' "Chapter 2 must describe one-shot readiness completion"
    require_regex "$CH2" '20초' "Chapter 2 must keep the 20초 scan deadline"
    require_regex "$CH2" '10초' "Chapter 2 must keep the 10초 interruption deadline"
    require_regex "$CH2" 'CTA.*전.*(탭|tap).*(무시|거부|받지|잠금|수용하지)' "Chapter 2 must ignore target taps before its CTA"
    require_regex "$CH2" '((같은|동일한).*AR[[:space:]]*(session|세션)|(AR[[:space:]]*)?(session|세션).*(같은|동일한))' "Chapter 2 to 3 must retain the same AR session"
    require_regex "$CH2" '(Chapter 3.*(debug|디버그).*(mesh|메시|메쉬).*(끄|끕|제거|해제|비활성)|(debug|디버그).*(mesh|메시|메쉬).*Chapter 3.*(끄|끕|제거|해제|비활성))' "Chapter 3 entry must remove the debug mesh"
    require_regex "$CH2" '(Reduce Motion.*(정적|static)|(정적|static).*Reduce Motion)' "Chapter 2 must provide a static Reduce Motion alternative"
    require_regex "$CH2" '(accepted[[:space:]-]*(hit|surface).*(marker|마커)|유효.*(hit|히트|표면).*(marker|마커))' "Chapter 2 must describe a marker only for an accepted real hit"
    require_regex "$CH2" '(bounding box|바운딩 박스|사각 외곽선)' "Chapter 2 must explicitly distinguish the scan UI from fake bounding boxes"
    require_regex "$CH2" '((의자|소파).*(label|라벨|인식)|(물체 종류).*(이름|label|라벨).*(않|금지|덧붙이지|만들지))' "Chapter 2 must explicitly reject fabricated object-semantic labels"
    require_fixed_count "$CH2" '<doc:01-ClosedWorld>' 1 "Chapter 2 previous link"
    require_fixed_count "$CH2" '<doc:03-RealHideAndSeek>' 1 "Chapter 2 next link"
    require_regex "$CH2" '실기기 대기' "Chapter 2 physical scan evidence must remain '실기기 대기'"
fi

if [[ -f "$CH3" ]]; then
    require_regex_count "$CH3" '^[[:space:]]*@Step[[:space:]]*\{' 4 "Chapter 3 @Step count"
    require_regex_count "$CH3" '@Code[[:space:]]*\(' 4 "Chapter 3 @Code count"
    require_fixed_count "$CH3" '실행 확인:' 4 "Chapter 3 execution-check count"
    require_fixed_count "$CH3" '실패·복구:' 4 "Chapter 3 failure-recovery count"
    require_fixed_count "$CH3" '03-RealHideAndSeek-01-ScaleAndFloorPlan.swift' 1 "Chapter 3 canonical code mapping"
    require_fixed_count "$CH3" '03-RealHideAndSeek-02-ViewSpaceSamples.swift' 1 "Chapter 3 canonical code mapping"
    require_fixed_count "$CH3" '03-RealHideAndSeek-03-StableOcclusion.swift' 1 "Chapter 3 canonical code mapping"
    require_fixed_count "$CH3" '03-RealHideAndSeek-04-CycleRecovery.swift' 1 "Chapter 3 canonical code mapping"
    for literal in \
        '0.18m' \
        '0.90m' \
        'abs(normal.y) <= 0.35' \
        '0.02m' \
        '0.10m' \
        '0.28m' \
        '80%' \
        'all-valid'; do
        require_regex "$CH3" "$(printf '%s' "$literal" | sed 's/[.[\*^$()+?{|]/\\&/g')" "Chapter 3 must include '$literal'"
    done
    require_regex "$CH3" '((retry|재시도).*0\.18m.*(최대[[:space:]]*2회|maximum[[:space:]]*2|2회)|0\.18m.*(최대[[:space:]]*2회|maximum[[:space:]]*2|2회).*(retry|재시도))' "Chapter 3 must keep 0.18m retries capped at two"
    require_regex "$CH3" '((8|여덟).*(corner|모서리)|(corner|모서리).*(8|여덟))' "Chapter 3 must derive samples from eight bounds corners"
    require_regex "$CH3" '(current camera.*right.*up|현재.*camera.*right.*up)' "Chapter 3 samples must use current camera right/up"
    require_regex "$CH3" 'center.*top.*bottom.*left.*right' "Chapter 3 must name center/top/bottom/left/right in order"
    require_regex "$CH3" 'blocked.*visible.*invalid' "Chapter 3 must distinguish blocked/visible/invalid"
    require_regex "$CH3" 'pigDistance[[:space:]]*-[[:space:]]*meshDistance[[:space:]]*>[[:space:]]*0\.03' "Chapter 3 must use the strict pigDistance - meshDistance > 0.03m rule"
    require_regex "$CH3" '(정확히.*0\.03m.*visible|0\.03m.*정확히.*visible|exactly.*0\.03m.*visible)' "Chapter 3 must state that exactly 0.03m is visible"
    require_regex "$CH3" 'center.*4/5.*(서로 다른|different).*(두|2).*(frame|프레임|관찰)' "Chapter 3 hide must require center + 4/5 across two different frames"
    require_regex "$CH3" '60.*1\.5' "Chapter 3 must keep the 60-frame/1.5-second deadline"
    require_regex "$CH3" '((두 번째|second).*hide.*pose|hide.*(두 번째|second).*pose)' "Chapter 3 must use the second successful hide pose"
    require_regex "$CH3" '0\.15m.*15°.*latch' "Chapter 3 must latch 0.15m or 15° movement"
    require_regex "$CH3" 'center.*3/5.*(서로 다른|different).*(두|2).*(frame|프레임|관찰)' "Chapter 3 reveal must require center + 3/5 across two different frames"
    require_regex "$CH3" '((one-shot|한 번만|1회).*(reveal|재발견|발견)|(reveal|재발견).*one-shot)' "Chapter 3 reveal must be one-shot"
    require_fixed_count "$CH3" '옆으로 움직이거나 카메라 방향을 바꿔 피기를 찾아봐.' 1 "Chapter 3 search guidance"
    require_regex "$CH3" '(verified hide|가림.*확인.*뒤에만|숨김.*검증.*뒤에만)' "Chapter 3 search guidance must appear only after verified hiding"
    require_fixed_count "$CH3" '<doc:02-OpeningTheDoor>' 1 "Chapter 3 previous link"
    require_fixed_count "$CH3" '<doc:04-Comparison>' 1 "Chapter 3 next link"
    require_regex "$CH3" '실기기 대기' "Chapter 3 physical size, occlusion, reveal, replay, and evidence must remain '실기기 대기'"
fi

if [[ -f "$CH4" ]]; then
    require_regex_count "$CH4" '^[[:space:]]*@Step[[:space:]]*\{' 2 "Chapter 4 @Step count"
    require_regex_count "$CH4" '@Code[[:space:]]*\(' 2 "Chapter 4 @Code count"
    require_fixed_count "$CH4" '실행 확인:' 2 "Chapter 4 execution-check count"
    require_fixed_count "$CH4" '실패·복구:' 2 "Chapter 4 failure-recovery count"
    require_fixed_count "$CH4" '04-Comparison-01-ComparisonModel.swift' 1 "Chapter 4 canonical code mapping"
    require_fixed_count "$CH4" '04-Comparison-02-ReplayRouting.swift' 1 "Chapter 4 canonical code mapping"
    require_token_order "$CH4" "Chapter 4 comparison axes must be world, coordinates, visibility, responsibilities in that order" \
        world coordinates visibility responsibilities
    for reason in \
        completedHide \
        cameraDenied \
        cameraRestricted \
        lidarUnavailable \
        sessionFailed \
        scanTimedOut \
        assetFailed; do
        require_regex "$CH4" "$reason" "Chapter 4 must include ComparisonEntryReason.$reason"
    done
    require_regex "$CH4" 'completedHide.*(실제.*완료|숨기.*완료|재발견.*완료|성공)' "Chapter 4 may claim actual hide completion only for completedHide"
    require_regex "$CH4" '우회' "Chapter 4 must distinguish bypass entry reasons from completion"
    require_regex "$CH4" '튜토리얼 완료' "Chapter 4 must include the completion CTA"
    require_regex "$CH4" 'Chapter 3 다시 하기' "Chapter 4 must include the Chapter 3 replay CTA"
    require_regex "$CH4" '처음부터 다시 보기' "Chapter 4 must include the full reset CTA"
    require_fixed_count "$CH4" '<doc:03-RealHideAndSeek>' 1 "Chapter 4 previous link"
    require_regex "$CH4" '실기기 대기' "Chapter 4 bypass reasons must retain '실기기 대기'"
fi

SCENE_GRAPH_ARTICLE="${ARTICLE_FILES[0]}"
ECS_ARTICLE="${ARTICLE_FILES[1]}"
DEVICE_ARTICLE="${ARTICLE_FILES[2]}"
MIGRATION_ARTICLE="${ARTICLE_FILES[3]}"

if [[ -f "$SCENE_GRAPH_ARTICLE" ]]; then
    require_regex "$SCENE_GRAPH_ARTICLE" 'C3' "SceneGraphDeepDive must use the C3 island experience"
    require_regex "$SCENE_GRAPH_ARTICLE" 'HideTree' "SceneGraphDeepDive must name HideTree"
    require_regex "$SCENE_GRAPH_ARTICLE" 'EscapePig' "SceneGraphDeepDive must name EscapePig"
    require_regex "$SCENE_GRAPH_ARTICLE" '(orbit camera|궤도 카메라)' "SceneGraphDeepDive must describe the orbit camera"
    require_regex "$SCENE_GRAPH_ARTICLE" 'SCNView\.hitTest' "SceneGraphDeepDive must describe node hit-testing"
    require_regex "$SCENE_GRAPH_ARTICLE" '(cancellable|취소 가능|취소 가능한).*auto-discovery|(auto-discovery|자동 발견).*(cancellable|취소 가능|취소 가능한)' "SceneGraphDeepDive must describe cancellable auto-discovery"
    require_regex "$SCENE_GRAPH_ARTICLE" '(Chapter 1.*현실.*(입력|관찰).*(연결하지|사용하지)|이 앱의 첫 장.*현실.*(입력|관찰).*(연결하지|사용하지))' "SceneGraphDeepDive must scope the lack of reality input to this app's Chapter 1"
fi

if [[ -f "$ECS_ARTICLE" ]]; then
    require_regex "$ECS_ARTICLE" 'ARKit.*(camera|카메라).*(plane|평면).*([Mm]esh|메시|메쉬)' "RealityKitECS must assign camera/plane/mesh observations to ARKit"
    require_regex "$ECS_ARTICLE" 'RealityKit.*(rendering|렌더링).*(collision|충돌).*(occlusion|가림|오클루전)' "RealityKitECS must assign rendering/collision/occlusion to RealityKit"
    require_regex "$ECS_ARTICLE" '(유효|valid).*(target|타깃).*(수락|accept).*(cycle|사이클).*(pig[[:space:]]*)?(anchor|앵커).*(attach|부착|추가)' "RealityKitECS must attach the pig cycle anchor only after a valid Chapter 3 target"
    require_regex "$ECS_ARTICLE" '(coordinator|코디네이터).*(policy|정책)|(policy|정책).*(coordinator|코디네이터)' "RealityKitECS must distinguish coordinator/policy code from RealityKit Systems"
    require_regex "$ECS_ARTICLE" '((mesh|메시|메쉬).*(그리고|AND|&&|둘 다|모두|와|과).*(floor|바닥)|(floor|바닥).*(그리고|AND|&&|둘 다|모두|와|과).*(mesh|메시|메쉬))' "RealityKitECS must describe mesh-and-floor readiness"
    require_regex "$ECS_ARTICLE" '((같은|동일한).*(session|세션).*Chapter 3|Chapter 3.*(같은|동일한).*(session|세션))' "RealityKitECS must preserve the same Chapter 2 to 3 session"
fi

if [[ -f "$DEVICE_ARTICLE" ]]; then
    require_regex "$DEVICE_ARTICLE" '(valid[[:space:]-]*layout|유효한.*(layout|레이아웃|bounds|크기))' "DeviceCameraDiagnostics must require a valid layout"
    require_regex "$DEVICE_ARTICLE" '(session|세션).*(시작|start)' "DeviceCameraDiagnostics must keep the session-start boundary"
    require_regex "$DEVICE_ARTICLE" '(scanning|스캔).*(pig|돼지).*(anchor|앵커).*(추가하지|부착하지|attach하지)' "DeviceCameraDiagnostics must keep pig anchors detached while scanning"
    require_regex "$DEVICE_ARTICLE" '(accepted|수락|유효).*(target|타깃|hit|히트).*(cycle|사이클).*(anchor|앵커).*(attach|부착|추가)' "DeviceCameraDiagnostics must attach a cycle anchor only after an accepted target"
    require_regex "$DEVICE_ARTICLE" '(session|세션).*시작.*(ready|readiness|준비 완료).*(아니|동일하지|별개|구분|같지)' "DeviceCameraDiagnostics must not equate session start with environment readiness"
    require_regex "$DEVICE_ARTICLE" '((mesh|메시|메쉬).*(그리고|AND|&&|둘 다|모두|와|과).*(classified|분류된).*(floor|바닥)|(classified|분류된).*(floor|바닥).*(그리고|AND|&&|둘 다|모두|와|과).*(mesh|메시|메쉬))' "DeviceCameraDiagnostics must require mesh plus classified floor readiness"
    require_regex "$DEVICE_ARTICLE" '실기기 대기' "DeviceCameraDiagnostics must mark physical scan/occlusion/reveal evidence as '실기기 대기'"
fi

if [[ -f "$MIGRATION_ARTICLE" ]]; then
    require_token_order "$MIGRATION_ARTICLE" "MigrationWorksheet axes must be world, coordinates, visibility, responsibilities in that order" \
        world coordinates visibility responsibilities
    require_regex "$MIGRATION_ARTICLE" 'SceneKit.*ARKit.*(명시적으로|연결)' "MigrationWorksheet must explain that SceneKit needs an explicit ARKit connection"
    require_regex "$MIGRATION_ARTICLE" 'RealityKit.*ARKit.*(observation|관찰)' "MigrationWorksheet must explain that RealityKit consumes ARKit observations"
    require_token_order "$MIGRATION_ARTICLE" "MigrationWorksheet must cover Chapter 1 through Chapter 4 in order" \
        '| 1 |' '| 2 |' '| 3 |' '| 4 |'
    require_regex "$MIGRATION_ARTICLE" '실기기 대기' "MigrationWorksheet must preserve pending physical verification"
fi

forbid_catalog_regex "old 0.45m placement distance is forbidden" '0\.45m'
forbid_catalog_regex "old 45cm placement distance is forbidden" '45[[:space:]]*cm'
forbid_catalog_regex "old raw 0.45 placement threshold is forbidden" '(simd_distance|minimumCameraDistance|cameraDistance).*(>=|>|=)[[:space:]]*0\.45([^0-9]|$)'
forbid_catalog_regex "old 0.35m pig height is forbidden" '(돼지.{0,24}높이.{0,12}0\.35m|높이.{0,12}0\.35m.{0,24}돼지)'
forbid_catalog_regex "old 35cm pig height is forbidden" '(35[[:space:]]*cm.{0,12}돼지|돼지.{0,12}35[[:space:]]*cm)'
forbid_catalog_regex "RoomBuilder is not the current Chapter 1 implementation" 'RoomBuilder'
forbid_catalog_regex "FakeSofa is not the current Chapter 1 implementation" 'FakeSofa'
forbid_catalog_regex "a fake sofa is not the current Chapter 1 implementation" '가짜 소파'
forbid_catalog_regex "the old additive mesh-distance rule is forbidden" 'meshDistance[[:space:]]*\+[[:space:]]*0\.03'
forbid_catalog_regex "mesh-or-floor readiness is forbidden" 'hasObservedMesh[[:space:]]*\|\|[[:space:]]*hasObservedFloor'
forbid_catalog_regex "movement completion cannot directly complete hiding" '(movementFinished.*(hiddenInReality|occlusionVerified)|(이동|movement).*완료.*(즉시|바로|직접).*(숨김|가림).*완료)'
forbid_catalog_regex "outdated Swift 6 strict failure or pending status is forbidden" 'Swift 6 strict.{0,16}(실패|대기)'
forbid_catalog_regex "a single center ray cannot complete hiding" '(중심.*(한 점|ray|레이).*(만으로|하나로).*(숨김|가림).*(성공|완료)|single[[:space:]-]*center[[:space:]-]*ray.*(success|complete))'
forbid_catalog_regex "Chapter 2 scanning must not attach a pig anchor" '((scanning|스캔).*(pig|돼지).*(anchor|앵커).*(attach|부착|추가)[[:space:]]*[.(]|(scanning|스캔).*anchor\.addChild)'
forbid_catalog_regex "fabricated object-recognition labels are forbidden" '((의자|소파)[[:space:]]*(인식 완료|감지 완료)|objectSemanticLabel|fakeSemanticLabel)'
forbid_catalog_regex "fabricated object bounding-box code is forbidden" '(FakeObjectBoundingBox|showObjectBoundingBoxes|fabricatedBoundingBox)'
forbid_catalog_regex "SceneKit/ARKit blanket incompatibility claim is forbidden" 'SceneKit은[[:space:]]+ARKit과[[:space:]]+함께[[:space:]]+사용할[[:space:]]+수[[:space:]]+없다'
forbid_catalog_regex "RealityKit automatic object-kind claim is forbidden" 'RealityKit이[[:space:]]+물체[[:space:]]+종류를[[:space:]]+자동으로[[:space:]]+안다'
forbid_catalog_regex "legacy Section 2 placeholder is forbidden" 'Section[[:space:]]+2'
forbid_catalog_regex "localization placeholders are forbidden" '\{(count|number)\}'
forbid_catalog_regex "the repeated legacy chapter icon reference is forbidden" 'closed-world-chapter-icon\.png'
forbid_catalog_regex "unobserved real-device completion claims are forbidden" '(실기기 검증 완료|LiDAR 가림 확인 완료|before/after 증거 확보 완료|공개 사이트 반영 완료)'

OLD_SNIPPET_NAMES=(
    "01-C3ClosedWorld-07-01.swift"
    "01-C3ClosedWorld-07-02.swift"
    "01-ClosedWorld-01-01.swift"
    "01-ClosedWorld-02-01.swift"
    "01-ClosedWorld-03-01.swift"
    "01-ClosedWorld-03-02.swift"
    "01-ClosedWorld-04-01.swift"
    "01-ClosedWorld-05-01.swift"
    "01-ClosedWorld-06-01.swift"
    "01-ClosedWorld-06-02.swift"
    "02-OpeningTheDoor-01-01.swift"
    "02-OpeningTheDoor-02-01.swift"
    "03-RealHideAndSeek-01-01.swift"
    "03-RealHideAndSeek-02-01.swift"
    "03-RealHideAndSeek-03-01.swift"
    "04-Comparison-01-01.swift"
)
for old_snippet in "${OLD_SNIPPET_NAMES[@]}"; do
    forbid_catalog_regex "old snippet filename reference is forbidden: $old_snippet" "${old_snippet//./\\.}"
done

for snippet_name in "${CANONICAL_SNIPPETS[@]}"; do
    snippet_path="$SNIPPET_DIR/$snippet_name"
    if [[ ! -f "$snippet_path" ]]; then
        continue
    fi
    require_regex "$snippet_path" '^[[:space:]]*//[[:space:]]*Production:' "$snippet_name must declare its Production source path"
    require_regex "$snippet_path" '^[[:space:]]*//[[:space:]]*Contract tests:' "$snippet_name must declare its Contract tests path"
    if grep -E -n -- '(TODO|TBD|<#[^>]*#>|//.*(\.\.\.|…))' "$snippet_path" > "$VERIFY_TEMP_DIR/snippet-placeholder.log" 2>/dev/null; then
        fail "$snippet_name contains a placeholder or omitted code"
        sed "s#^#$CATALOG_REL/Tutorials/Resources/$snippet_name:#" "$VERIFY_TEMP_DIR/snippet-placeholder.log" >&2
    fi
done

IOS_SDK_PATH=""
if ! command -v xcrun >/dev/null 2>&1; then
    fail "xcrun is unavailable; cannot independently type-check the canonical iPhoneOS snippets"
else
    SDK_LOG="$VERIFY_TEMP_DIR/iphoneos-sdk.log"
    if xcrun --sdk iphoneos --show-sdk-path > "$SDK_LOG" 2>&1; then
        IOS_SDK_PATH="$(sed -n '1p' "$SDK_LOG")"
    else
        fail "could not resolve the iPhoneOS SDK for independent snippet type-checking"
        cat "$SDK_LOG" >&2
    fi
fi

for snippet_name in "${CANONICAL_SNIPPETS[@]}"; do
    snippet_path="$SNIPPET_DIR/$snippet_name"
    if [[ ! -f "$snippet_path" ]]; then
        fail "independent iPhoneOS type-check cannot run because the canonical snippet is missing: $snippet_name"
        continue
    fi
    if [[ -z "$IOS_SDK_PATH" ]]; then
        fail "independent iPhoneOS type-check was not run for $snippet_name because the SDK is unavailable"
        continue
    fi

    compiler_log="$VERIFY_TEMP_DIR/typecheck-$snippet_name.log"
    if xcrun --sdk iphoneos swiftc \
        -typecheck \
        -swift-version 5 \
        -target arm64-apple-ios17.0 \
        -sdk "$IOS_SDK_PATH" \
        -module-cache-path "$VERIFY_TEMP_DIR/module-cache" \
        "$snippet_path" \
        > "$compiler_log" 2>&1; then
        TYPECHECK_PASS_COUNT=$((TYPECHECK_PASS_COUNT + 1))
    else
        fail "independent iPhoneOS type-check failed: $snippet_name"
        cat "$compiler_log" >&2
    fi
done

overview_count="$(grep -F -x -c 'SceneKitToRealityKit.tutorial' "$ACTUAL_TUTORIALS_FILE" 2>/dev/null || true)"
tutorial_count="$(grep -E -c '^Tutorials/[^/]+\.tutorial$' "$ACTUAL_TUTORIALS_FILE" 2>/dev/null || true)"
article_count="$(wc -l < "$ACTUAL_ARTICLES_FILE" | tr -d '[:space:]')"
snippet_count="$(wc -l < "$ACTUAL_SNIPPETS_FILE" | tr -d '[:space:]')"

if [[ "$ERROR_COUNT" -ne 0 ]]; then
    printf '\nDocC content verification FAILED with %d error(s).\n' "$ERROR_COUNT" >&2
    printf 'Observed inventory: overview %s, tutorials %s, articles %s, snippets %s.\n' \
        "$overview_count" "$tutorial_count" "$article_count" "$snippet_count" >&2
    printf 'Independent iPhoneOS snippet type-check: %d/%d passed.\n' \
        "$TYPECHECK_PASS_COUNT" "$TYPECHECK_EXPECTED_COUNT" >&2
    printf 'Forbidden semantic/source matches: %d.\n' "$FORBIDDEN_MATCH_COUNT" >&2
    exit 1
fi

printf 'DocC content verification passed.\n'
printf 'Inventory: overview 1, tutorials 4, articles 5, snippets 12.\n'
printf 'Independent iPhoneOS snippet type-check: 12/12 passed.\n'
printf 'Forbidden semantic/source matches: 0.\n'
