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

# --- report order must not depend on the environment's locale ----------------
# sort ties on the line number and then compares whole lines, which is collation
# dependent, so the same draft produced different output on a German system than
# on a C one. Every sort in the scanner is pinned to C.
printf 'What moved is clear. hand-waves at it. Here, nobody has settled.\n' > "${work}/collate.md"
# stdout only: a locale that is not installed makes the shell warn on stderr,
# which says nothing about the report.
ref="$(SCAN_FORCE_POSIX=0 LC_ALL=C bash "$scan" "${work}/collate.md" 2> /dev/null | norm)"
same=1
for loc in C.utf8 en_US.UTF-8 de_DE.UTF-8 tr_TR.UTF-8; do
    locale -a 2> /dev/null | "${GREP:-grep}" -q -i -x "$(printf '%s' "$loc" | tr 'A-Z' 'a-z' | tr -d '-')" \
        || locale -a 2> /dev/null | "${GREP:-grep}" -q -x "$loc" \
        || continue
    got="$(SCAN_FORCE_POSIX=0 LC_ALL="$loc" bash "$scan" "${work}/collate.md" 2> /dev/null | norm)"
    [ "$got" = "$ref" ] || same=0
done
if [ "$same" -eq 1 ]; then ok; else bad "report order changes with the locale"; fi

# The comparison above can only run where a dictionary-collating locale is
# installed, so assert the mechanism as well: the scanner must clear LC_ALL,
# which would override both settings, and pin collation to C.
if "${GREP:-grep}" -q '^unset LC_ALL$' "$scan" && "${GREP:-grep}" -q '^export LC_COLLATE=C$' "$scan"; then
    ok
else
    bad "scan.sh must clear LC_ALL and pin LC_COLLATE=C"
fi

# --- reference lists must not arrive truncated --------------------------------
# A fetch route that truncates a list produces fewer patterns, all of them valid,
# so the compile check passes and the scanner reports files clean. A floor on the
# entry count catches a truncated or placeholder file.
check_floor() {
    local file="$1" floor="$2" n
    n="$("${GREP:-grep}" -c -v -E '^[[:space:]]*(#|$)' "${root}/references/${file}" 2> /dev/null)"
    if [ "${n:-0}" -ge "$floor" ]; then ok; else bad "references/${file} has ${n:-0} entries, expected at least ${floor}"; fi
}
check_floor patterns.txt 175
check_floor patterns-loose.txt 40
check_floor artifacts.txt 35
check_floor variant-pairs.txt 28
check_floor rotations.txt 9
check_floor hidden-unicode.txt 35
check_floor l1/errors.txt 22
check_floor l1/false-friends.txt 20
if [ "$("${GREP:-grep}" -c . "${root}/references/banlist.md")" -ge 140 ]; then ok; else bad "references/banlist.md looks truncated"; fi

# --- sentence length and terminology rotations ------------------------------
printf 'The system will check the configuration and then verify the settings before it runs the migration, which is a long sentence that runs well past any reasonable limit for a second language reader.\n' > "${work}/long.md"
printf 'A short sentence. Another short one.\n' > "${work}/short.md"

out="$(SCAN_FORCE_POSIX=0 bash "$scan" "${work}/long.md" 2>&1)"
case "$out" in *"33 words"*) ok ;; *) bad "long sentence is counted and reported" ;; esac
case "$out" in *"check verify"*) ok ;; *) bad "a terminology rotation is reported" ;; esac

out="$(SCAN_FORCE_POSIX=0 bash "$scan" "${work}/short.md" 2>&1)"
case "$out" in *"long sentences"*clean*) ok ;; *) bad "short sentences report clean" ;; esac

out="$(SCAN_FORCE_POSIX=0 bash "$scan" --max-sentence=10 "${work}/short.md" 2>&1)"
case "$out" in *"over 10 words"*) ok ;; *) bad "--max-sentence changes the limit" ;; esac

SCAN_FORCE_POSIX=0 bash "$scan" --gate "${work}/long.md" > /dev/null 2>&1
if [ $? -eq 0 ]; then ok; else bad "long sentences and rotations must not gate"; fi

# --- preemptive defence and the trailing moral ------------------------------
printf 'That is not a turf claim.\nIt fails, because a judgment call is not a gate.\n' > "${work}/defence.md"
out="$(SCAN_FORCE_POSIX=0 bash "$scan" "${work}/defence.md" 2>&1)"
case "$out" in *"That is not a turf claim"*) ok ;; *) bad "preemptive defence is caught" ;; esac
case "$out" in *", because a judgment call"*) ok ;; *) bad "the trailing moral is caught" ;; esac

# --- comments mode through the whole scanner --------------------------------
out="$(SCAN_FORCE_POSIX=0 bash "$scan" --comments "${here}/lexer/python.py" 2>&1)"
case "$out" in *"worth noting"*) ok ;; *) bad "--comments reads a python docstring" ;; esac
case "$out" in *"not a comment"*) bad "--comments must not read string literals" ;; *) ok ;; esac

out="$(SCAN_FORCE_POSIX=0 bash "$scan" --comments "${here}/lexer/shell.sh" 2>&1)"
case "$out" in *tapestry*) bad "--comments must not read a heredoc body" ;; *) ok ;; esac
case "$out" in *"cutting-edge"*) ok ;; *) bad "--comments reads a shell comment" ;; esac

# --- each special character is counted once, on both grep paths -----------
# U+00A0 and U+2011 sat in both the hidden-character list and the punctuation
# class, so one occurrence counted twice; U+2010 was missing from the BSD path
# altogether. tests/docs/typography.md holds every character and runs on both
# paths; these three pin the counts.
for ch in '\302\240' '\342\200\221' '\342\200\220'; do
    printf 'one%bhere\n' "$ch" > "${work}/one.md"
    for posix in 0 1; do
        out="$(SCAN_FORCE_POSIX=$posix bash "$scan" "${work}/one.md" 2>&1)"
        case "$out" in
            *"ratchetable): 1"*) ok ;;
            *) bad "single $ch must give exactly one gate hit (SCAN_FORCE_POSIX=$posix)" ;;
        esac
    done
done

# --- a missing awk program must fail loudly, not report clean ----------------
# awk with a missing -f file prints nothing, and nothing reads as "clean". The
# scanner is copied so the real tree is never touched.
copy="${work}/copy"
mkdir -p "$copy"
cp -r "${root}/scripts" "${root}/references" "$copy/"
printf '# This is groundbreaking and seamless.\necho hi\n' > "${work}/x.sh"

rm "${copy}/scripts/comments.awk"
SCAN_FORCE_POSIX=0 bash "${copy}/scripts/scan.sh" --comments "${work}/x.sh" > /dev/null 2>&1
if [ $? -eq 2 ]; then ok; else bad "missing comments.awk must exit 2 under --comments"; fi
SCAN_FORCE_POSIX=0 bash "${copy}/scripts/scan.sh" "${work}/short.md" > /dev/null 2>&1
if [ $? -eq 0 ]; then ok; else bad "comments.awk is only required under --comments"; fi
cp "${root}/scripts/comments.awk" "${copy}/scripts/"

rm "${copy}/scripts/sentences.awk"
SCAN_FORCE_POSIX=0 bash "${copy}/scripts/scan.sh" "${work}/short.md" > /dev/null 2>&1
if [ $? -eq 2 ]; then ok; else bad "missing sentences.awk must exit 2"; fi

rm -rf "$work"

# Recorded output must carry no trailing whitespace. Editors strip it on save
# and git apply --whitespace=fix strips it from patches, and a golden file that
# depends on it then fails for no reason.
tw="$("${GREP:-grep}" -l '[[:space:]]$' "${here}"/docs/*.expected "${here}"/lexer/*.expected 2> /dev/null)"
if [ -z "$tw" ]; then ok; else bad "trailing whitespace in recorded output: $(printf '%s ' $tw)"; fi

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
