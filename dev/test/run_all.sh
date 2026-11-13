#!/bin/bash
# runs every check: syntax of all built files + the logic tests of every game
REPO="$(cd "${1:-.}" && pwd)"
cd "$(dirname "$0")/.." || exit 1
fail=0
texlua test/syntax.lua casinoSettings.lua "$REPO"/*/startup.lua "$REPO/installer.lua" || fail=1
for t in slots plinko villager baccarat craps holdem settings tos smoke_tos; do
    printf '%-9s ' "$t"
    f=test/test_$t.lua; [ -f "$f" ] || f=test/$t.lua; out=$(texlua $f 2>&1); code=$?
    echo "$out" | tail -1
    [ $code -ne 0 ] && { echo "$out" | tail -5; fail=1; }
done
exit $fail
