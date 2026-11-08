#!/bin/zsh
# Headless game-logic tests. Each suite in Tests/Logic is compiled together with Punch Mine/Game
# and run as its own executable. Exits non-zero if any check fails or a suite doesn't build.
#   Tests/run-logic-tests.sh            run every suite
#   Tests/run-logic-tests.sh 10_Items   run suites whose name contains the argument
set -u
ROOT="${0:A:h:h}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
passed=0; failed=0; broken=0
for suite in "$ROOT"/Tests/Logic/*.swift; do
    name="${suite:t:r}"
    [[ $# -gt 0 && "$name" != *"$1"* ]] && continue
    # A suite without @main is top-level script code, which Swift only accepts from a file named main.swift.
    source="$suite"
    if ! grep -q '^@main' "$suite"; then mkdir -p "$WORK/src/$name"; source="$WORK/src/$name/main.swift"; cp "$suite" "$source"; fi
    if ! xcrun swiftc -swift-version 5 -default-isolation MainActor -o "$WORK/$name" \
            "$ROOT"/"Punch Mine"/Game/*.swift "$source" 2> "$WORK/$name.build.txt"; then
        echo "BUILD FAILED $name"; grep error: "$WORK/$name.build.txt"; broken=$((broken + 1)); continue
    fi
    output="$(cd "$WORK" && "./$name" 2>&1)"; code=$?
    p=$(print -r -- "$output" | grep -c '^PASS'); f=$(print -r -- "$output" | grep -c '^FAIL')
    # A crash stops the suite early: count it as a failure and show why.
    if [[ $code -ne 0 ]]; then f=$((f + 1)); output+=$'\n'"FAIL suite exited with code $code: $(print -r -- "$output" | grep -v '^PASS' | tail -1)"; fi
    passed=$((passed + p)); failed=$((failed + f))
    printf '%-24s %3d pass %3d fail\n' "$name" "$p" "$f"
    print -r -- "$output" | grep '^FAIL' | sed 's/^/    /'
done
echo "Total: $passed passed, $failed failed, $broken suites failed to build"
[[ $failed -eq 0 && $broken -eq 0 ]]
