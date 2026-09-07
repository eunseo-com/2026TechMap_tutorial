#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d /tmp/piggy-policy-tests.XXXXXX)"
developer_dir="$(xcode-select -p)"
test_frameworks="$developer_dir/Platforms/MacOSX.platform/Developer/Library/Frameworks"
test_libraries="$developer_dir/Platforms/MacOSX.platform/Developer/usr/lib"
test_private_frameworks="$developer_dir/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"
sources=("$repo_root/PiggyEscape/PiggyEscape/Sources/Reality/RealityEnvironmentReadiness.swift")
telemetry_source="$repo_root/PiggyEscape/PiggyEscape/Sources/Reality/RealityScanTelemetry.swift"
if [[ -f "$telemetry_source" ]]; then sources+=("$telemetry_source"); fi
sources+=("$repo_root/PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift")
sources+=("$repo_root/PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift")
sources+=("$repo_root/PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionPolicy.swift")
preview_source="$repo_root/PiggyEscape/PiggyEscape/Sources/Reality/RealityTargetPreview.swift"
if [[ -f "$preview_source" ]]; then sources+=("$preview_source"); fi
route_source="$repo_root/PiggyEscape/PiggyEscape/Sources/Reality/RealityWalkRoute.swift"
if [[ -f "$route_source" ]]; then sources+=("$route_source"); fi
timeline_source="$repo_root/PiggyEscape/PiggyEscape/Sources/Reality/RealityWalkTimeline.swift"
if [[ -f "$timeline_source" ]]; then sources+=("$timeline_source"); fi
xcrun swiftc -swift-version 5 -D REALITY_POLICY_HOST_TESTS \
  -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
  -I "$test_libraries" -L "$test_libraries" -Xlinker -rpath -Xlinker "$test_libraries" \
  -Xlinker -rpath -Xlinker "$test_private_frameworks" \
  -module-cache-path "$test_dir/module-cache" \
  "${sources[@]}" \
  "$repo_root/PiggyEscape/PiggyEscapeTests/RealityScanTelemetryTests.swift" \
  "$repo_root/PiggyEscape/PiggyEscapeTests/RealityTargetPreviewTests.swift" \
  "$repo_root/PiggyEscape/PiggyEscapeTests/RealityWalkRouteTests.swift" \
  "$repo_root/PiggyEscape/PiggyEscapeTests/RealityWalkTimelineTests.swift" \
  "$repo_root/PiggyEscape/PiggyEscapeTests/RealityOcclusionPolicyTests.swift" \
  "$repo_root/scripts/tests/reality-policy-main.swift" \
  -o "$test_dir/reality-policy-tests"
"$test_dir/reality-policy-tests"
