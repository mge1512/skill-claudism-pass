#!/bin/bash
# run.sh - regression tests for scan.sh and comments.awk.
#
#   bash tests/run.sh              # check, exit 1 on any difference
#   bash tests/run.sh --update     # re-record the expected output
#
# Two fixture sets. tests/lexer/<lang>.<ext> exercises comments.awk directly, so
# a lexer regression is isolated from everything else; the file name before the
# dot is the lang to pass. tests/docs/*.md exercises the whole scanner.
#
# Every case runs twice, once with whatever grep is installed and once with
# SCAN_FORCE_POSIX=1, because the portable path is a separate implementation and
# a scanner that silently reports clean is the failure this exists to catch.

set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"
scan="${root}/scripts/scan.sh"
lexer="${root}/scripts/comments.awk"

update="no"
[ "${1:-}" = "--update" ] && update="yes"

pass=0
fail=0

# Strip what legitimately varies: the absolute path and the lexicon stamp.
norm() {
    sed -e "s|${root}/||g" -e 's|   lexicon .*||'
}

# $1 = label, $2 = expected file, $3 = file holding the actual output.
# Deliberately not fed by a pipeline: a pipeline runs its last stage in a
# subshell, and the pass/fail counters would be discarded there.
check() {
    local label="$1" want="$2" got
    got="$(cat "$3")"
    if [ "$update" = "yes" ]; then
        printf '%s\n' "$got" > "$want"
        echo "recorded  $label"
        return
    fi
    if [ ! -r "$want" ]; then
        echo "MISSING   $label (no expected output; run with --update)"
        fail=$((fail + 1))
        return
    fi
    if printf '%s\n' "$got" | diff -u "$want" - > /dev/null; then
        pass=$((pass + 1))
    else
        echo "FAIL      $label"
        printf '%s\n' "$got" | diff -u "$want" - | sed 's/^/          /'
        fail=$((fail + 1))
    fi
}

actual="$(mktemp "${TMPDIR:-/tmp}/claudism-test.XXXXXX")"
trap 'rm -f "$actual"' EXIT

for f in "${here}"/lexer/*; do
    case "$f" in *.expected) continue ;; esac
    base="$(basename "$f")"
    lang="${base%%.*}"
    awk -v lang="$lang" -f "$lexer" "$f" > "$actual" 2>&1
    check "lexer $base" "${f}.expected" "$actual"
done

for f in "${here}"/docs/*; do
    case "$f" in *.expected) continue ;; esac
    base="$(basename "$f")"
    bash "$scan" "$f" 2>&1 | norm > "$actual"
    check "scan $base" "${f}.expected" "$actual"
    SCAN_FORCE_POSIX=1 bash "$scan" "$f" 2>&1 | norm | tail -n +5 > "$actual"
    check "scan $base (portable path)" "${f}.expected" "$actual"
done

# The gate must fail on a dirty file and pass on a clean one, or CI is decorative.
bash "$scan" --gate "${here}/docs/clean.md" > /dev/null 2>&1
if [ $? -eq 0 ]; then pass=$((pass + 1)); else echo "FAIL      gate passes a clean file"; fail=$((fail + 1)); fi
bash "$scan" --gate "${here}/docs/dirty.md" > /dev/null 2>&1
if [ $? -eq 1 ]; then pass=$((pass + 1)); else echo "FAIL      gate fails a dirty file"; fail=$((fail + 1)); fi

if [ "$update" = "yes" ]; then
    echo "expected output re-recorded; review the diff before committing"
    exit 0
fi

echo "${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
