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

# Test against a specific awk with AWK=gawk, AWK=original-awk and so on.
AWK="${AWK:-awk}"

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
    "$AWK" -v lang="$lang" -f "$lexer" "$f" > "$actual" 2>&1
    check "lexer $base" "${f}.expected" "$actual"
done

for f in "${here}"/docs/*; do
    case "$f" in *.expected) continue ;; esac
    base="$(basename "$f")"
    SCAN_FORCE_POSIX=0 bash "$scan" "$f" 2>&1 | norm > "$actual"
    check "scan $base" "${f}.expected" "$actual"
    SCAN_FORCE_POSIX=1 bash "$scan" "$f" 2>&1 | norm | tail -n +5 > "$actual"
    check "scan $base (portable path)" "${f}.expected" "$actual"
done


ok()  { pass=$((pass + 1)); }
bad() { echo "FAIL      $1"; fail=$((fail + 1)); }

# --- every pattern in every list must compile ------------------------------
# A malformed regex matches nothing and reports the file clean, which is the
# failure this whole suite exists to catch. grep exits 2 on a bad expression and
# 1 on a valid one that found nothing.
compiles() {
    printf '' | "${GREP:-grep}" -E "$1" > /dev/null 2>&1
    [ $? -le 1 ]
}

for pf in patterns.txt patterns-loose.txt artifacts.txt l1/errors.txt l1/false-friends.txt; do
    badpat=0
    while IFS= read -r pat; do
        case "$pat" in ''|'#'*) continue ;; esac
        if ! compiles "$pat"; then
            echo "          bad ERE in $pf: $pat"
            badpat=$((badpat + 1))
        fi
        # the portable path strips \b and relies on grep -w, so check that form too
        stripped="$(printf '%s' "$pat" | sed 's/\\b//g')"
        if ! compiles "$stripped"; then
            echo "          bad ERE in $pf after \\b removal: $stripped"
            badpat=$((badpat + 1))
        fi
    done < "${root}/references/${pf}"
    if [ "$badpat" -eq 0 ]; then ok; else bad "patterns compile: $pf"; fi
done

badpair=0
while IFS='|' read -r us gb; do
    case "$us" in ''|'#'*) continue ;; esac
    compiles "${us%e}(e|es|ed|ing|s|ations?)?" || badpair=$((badpair + 1))
    compiles "${gb%e}(e|es|ed|ing|s|ations?)?" || badpair=$((badpair + 1))
done < "${root}/references/variant-pairs.txt"
if [ "$badpair" -eq 0 ]; then ok; else bad "variant pairs compile"; fi

badesc=0
while IFS="$(printf '\t')" read -r esc name; do
    case "$esc" in ''|'#'*) continue ;; esac
    esc="${esc#\?}"
    [ -n "$(printf '%b' "$esc")" ] || badesc=$((badesc + 1))
done < "${root}/references/hidden-unicode.txt"
if [ "$badesc" -eq 0 ]; then ok; else bad "hidden-unicode escapes decode"; fi

# --- the ratchet, in all three drift directions -----------------------------
work="$(mktemp -d "${TMPDIR:-/tmp}/claudism-ratchet.XXXXXX")"
printf 'This is groundbreaking and seamless.\n' > "${work}/a.md"
printf 'A plain sentence about the release.\n' > "${work}/b.md"
base="${work}/baseline"

SCAN_FORCE_POSIX=0 bash "$scan" --write-baseline="$base" "${work}/a.md" "${work}/b.md" > /dev/null 2>&1
SCAN_FORCE_POSIX=0 bash "$scan" --baseline="$base" "${work}/a.md" "${work}/b.md" > /dev/null 2>&1
if [ $? -eq 0 ]; then ok; else bad "ratchet holds on an unchanged tree"; fi

printf 'This is groundbreaking, seamless and a testament to tapestry.\n' > "${work}/a.md"
out="$(SCAN_FORCE_POSIX=0 bash "$scan" --baseline="$base" "${work}/a.md" "${work}/b.md" 2>&1)"
case "$out" in *regressed:*) ok ;; *) bad "ratchet reports a regression" ;; esac

printf 'A plain sentence.\n' > "${work}/a.md"
out="$(SCAN_FORCE_POSIX=0 bash "$scan" --baseline="$base" "${work}/a.md" "${work}/b.md" 2>&1)"
case "$out" in *improved:*) ok ;; *) bad "ratchet reports an unrecorded improvement" ;; esac

printf 'Another seamless and groundbreaking line.\n' > "${work}/c.md"
out="$(SCAN_FORCE_POSIX=0 bash "$scan" --baseline="$base" "${work}/a.md" "${work}/b.md" "${work}/c.md" 2>&1)"
case "$out" in *"new and not clean"*) ok ;; *) bad "ratchet reports a new dirty file" ;; esac

sed 's/^# lexicon .*/# lexicon 1970-01-01/' "$base" > "${base}.old"
out="$(SCAN_FORCE_POSIX=0 bash "$scan" --baseline="${base}.old" "${work}/b.md" 2>&1)"
case "$out" in *"recorded against lexicon"*) ok ;; *) bad "ratchet warns on a stale lexicon stamp" ;; esac

# --- the variant switch ------------------------------------------------------
printf 'We initialize the catalog and analyze the behavior of the service.\n' > "${work}/us.md"
printf 'We initialise the catalogue and analyse the behaviour of the centre.\n' > "${work}/gb.md"
printf 'We initialize the catalog and analyze the colour of the behavior.\n' > "${work}/one.md"
printf 'We initialize the catalog but analyse the behaviour of the centre.\n' > "${work}/mix.md"

out="$(SCAN_FORCE_POSIX=0 bash "$scan" "${work}/one.md" 2>&1)"
case "$out" in *MIXED*) bad "one flipped word must not count as mixed" ;; *) ok ;; esac

out="$(SCAN_FORCE_POSIX=0 bash "$scan" "${work}/mix.md" 2>&1)"
case "$out" in *MIXED*) ok ;; *) bad "two flipped pairs are a mixed document" ;; esac

out="$(SCAN_FORCE_POSIX=0 bash "$scan" --eu "${work}/us.md" 2>&1)"
case "$out" in *"convert to EU"*) ok ;; *) bad "--eu lists the words to convert" ;; esac

out="$(SCAN_FORCE_POSIX=0 bash "$scan" --us "${work}/gb.md" 2>&1)"
case "$out" in *"convert to US"*) ok ;; *) bad "--us lists the words to convert" ;; esac

{ echo '<!-- variant: eu -->'; cat "${work}/us.md"; } > "${work}/marked.md"
out="$(SCAN_FORCE_POSIX=0 bash "$scan" "${work}/marked.md" 2>&1)"
case "$out" in *"file marker"*eu*) ok ;; *) bad "a variant marker near the top is honoured" ;; esac

printf 'See the table in `<!-- variant: eu -->` further down the document.\n%s' \
    "$(cat "${work}/us.md")" > "${work}/late.md"
out="$(SCAN_FORCE_POSIX=0 bash "$scan" "${work}/late.md" 2>&1)"
case "$out" in *"file marker"*) bad "a marker inside a code span must not count" ;; *) ok ;; esac

# --- comments mode through the whole scanner --------------------------------
out="$(SCAN_FORCE_POSIX=0 bash "$scan" --comments "${here}/lexer/python.py" 2>&1)"
case "$out" in *"worth noting"*) ok ;; *) bad "--comments reads a python docstring" ;; esac
case "$out" in *"not a comment"*) bad "--comments must not read string literals" ;; *) ok ;; esac

out="$(SCAN_FORCE_POSIX=0 bash "$scan" --comments "${here}/lexer/shell.sh" 2>&1)"
case "$out" in *tapestry*) bad "--comments must not read a heredoc body" ;; *) ok ;; esac
case "$out" in *"cutting-edge"*) ok ;; *) bad "--comments reads a shell comment" ;; esac

rm -rf "$work"

# The gate must fail on a dirty file and pass on a clean one, or CI is decorative.
SCAN_FORCE_POSIX=0 bash "$scan" --gate "${here}/docs/clean.md" > /dev/null 2>&1
if [ $? -eq 0 ]; then pass=$((pass + 1)); else echo "FAIL      gate passes a clean file"; fail=$((fail + 1)); fi
SCAN_FORCE_POSIX=0 bash "$scan" --gate "${here}/docs/dirty.md" > /dev/null 2>&1
if [ $? -eq 1 ]; then pass=$((pass + 1)); else echo "FAIL      gate fails a dirty file"; fail=$((fail + 1)); fi

if [ "$update" = "yes" ]; then
    echo "expected output re-recorded; review the diff before committing"
    exit 0
fi

echo "${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
