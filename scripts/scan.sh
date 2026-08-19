#!/bin/bash
# scan.sh - mechanical part of the Claudism pass.
#
# Usage: bash scan.sh [--us|--eu] [--no-l1] FILE [FILE...]
#
# Reports:
#   1. high-confidence banlist phrases  (references/patterns.txt)
#   2. loose phrases needing judgment   (references/patterns-loose.txt)
#   3. decorative punctuation and emoji
#   4. structural tics grep can see (--- dividers, bold-term bullets)
#   5. spelling variant, dates and units, second-language interference
#
# Phrases are matched against whole paragraphs, not single lines, so hard-wrapped
# text is scanned correctly. Hits are reported by the line the paragraph starts
# on; search for the quoted phrase itself to jump to it.
#
# Portability: works with GNU grep and with the BSD grep that macOS ships. GNU
# grep is preferred when present, including Homebrew's ggrep. Without PCRE the
# emoji check falls back to a byte match and the time-zone check to a two-pass
# filter; both still work. Set SCAN_FORCE_POSIX=1 to exercise that path on a
# GNU system.
#
# The scanner only sees literal strings. Crowned superlatives with an unusual
# noun, negative parallelism in fresh wording and staged epiphany have to be
# caught by reading. See SKILL.md, step 2.
#
# English text only. Do not run this over German drafts.

set -u

# ---------------------------------------------------------------- grep flavour

# Homebrew installs GNU grep as ggrep and leaves the system one in place.
if command -v ggrep > /dev/null 2>&1; then
    GREP="ggrep"
else
    GREP="grep"
fi

has_p="no"
has_wb="no"

if [ "${SCAN_FORCE_POSIX:-0}" != "1" ]; then
    if printf 'x\n' | "$GREP" -q -P 'x' 2> /dev/null; then
        has_p="yes"
    fi
    # \b must both match a boundary and refuse a non-boundary. A grep that
    # silently treats it as a literal passes the first test and fails this one.
    if printf 'cat\n' | "$GREP" -q -E '\bcat\b' 2> /dev/null \
       && ! printf 'concatenate\n' | "$GREP" -q -E '\bcat\b' 2> /dev/null; then
        has_wb="yes"
    fi
fi

# PCRE character ranges need a UTF-8 locale to see characters rather than bytes.
if [ "$has_p" = "yes" ]; then
    if ! printf '\xe2\x80\x94' | "$GREP" -q -P '\x{2014}' 2> /dev/null; then
        for cand in C.UTF-8 C.utf8 en_US.UTF-8 de_DE.UTF-8; do
            if printf '\xe2\x80\x94' | LC_ALL="$cand" "$GREP" -q -P '\x{2014}' 2> /dev/null; then
                export LC_ALL="$cand"
                break
            fi
        done
    fi
fi

# Without GNU \b, drop the boundaries from the pattern and let grep -w enforce
# them instead. Every pattern in the lists is word-delimited by design, so the
# two are equivalent here, and -w is POSIX: the fallback behaves the same on GNU
# and BSD, which means it can be tested on either.
WB_FLAG=""
if [ "$has_wb" != "yes" ]; then
    WB_FLAG="-w"
fi

port() {
    if [ "$has_wb" = "yes" ]; then
        printf '%s' "$1"
    else
        printf '%s' "$1" | sed 's/\\b//g'
    fi
}

tmpfile() {
    mktemp "${TMPDIR:-/tmp}/claudism.XXXXXX"
}

# ---------------------------------------------------------------------- inputs

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ref="${here}/../references"
strict="${ref}/patterns.txt"
loose="${ref}/patterns-loose.txt"
pairs="${ref}/variant-pairs.txt"
l1_err="${ref}/l1/errors.txt"
l1_ff="${ref}/l1/false-friends.txt"
hidden="${ref}/hidden-unicode.txt"

variant="auto"
do_l1="yes"
gate="no"
baseline=""
write_baseline=""
nfiles=0
files=()
for arg in "$@"; do
    case "$arg" in
        --us|--variant=us)          variant="us" ;;
        --eu|--gb|--variant=eu)     variant="eu" ;;
        --variant=auto)             variant="auto" ;;
        --no-l1)                    do_l1="no" ;;
        --gate)                     gate="yes" ;;
        --baseline=*)               baseline="${arg#*=}" ;;
        --write-baseline=*)         write_baseline="${arg#*=}" ;;
        -h|--help)
            echo "usage: bash scan.sh [--us|--eu] [--no-l1] FILE [FILE...]"
            echo "  --us | --eu   force the spelling variant (default: auto)"
            echo "  --no-l1       skip the second-language interference check"
            echo "  --gate        exit 1 if any unambiguous hit is found (for CI)"
            echo "  --baseline=F  ratchet against per-file counts in F; exit 1 on drift"
            echo "  --write-baseline=F  record the current counts as the new floor"
            exit 0 ;;
        -*)
            echo "scan.sh: unknown option $arg" >&2
            exit 2 ;;
        *)  files+=("$arg"); nfiles=$((nfiles + 1)) ;;
    esac
done

if [ "$nfiles" -lt 1 ]; then
    echo "usage: bash scan.sh [--us|--eu] [--no-l1] FILE [FILE...]" >&2
    exit 2
fi

for f in "$strict" "$loose" "$pairs" "$l1_err" "$l1_ff" "$hidden"; do
    if [ ! -r "$f" ]; then
        echo "scan.sh: cannot read $f" >&2
        exit 2
    fi
done

if [ "$has_p" != "yes" ] || [ "$has_wb" != "yes" ]; then
    echo "scan.sh: $GREP lacks PCRE or GNU word boundaries, using the portable path."
    echo "         All checks run; emoji matching is coarser. On macOS, 'brew install grep'"
    echo "         provides ggrep and this message goes away."
    echo
fi

# -ise verbs that are spelled the same in both variants.
ise_both='advertise|advise|apprise|arise|chastise|circumcise|comprise|compromise|concise|demise|despise|devise|disguise|enterprise|excise|exercise|expertise|franchise|improvise|incise|likewise|merchandise|otherwise|paradise|precise|premise|promise|revise|rise|supervise|surprise|televise|wise'

# ------------------------------------------------------------------- functions

# Blank out fenced code blocks and inline code spans, keeping the line count so
# reported line numbers still match the original. Identifiers are not prose.
strip_code() {
    awk '
        /^[[:space:]]*```/ { inblock = !inblock; print ""; next }
        inblock { print ""; next }
        { gsub(/`[^`]*`/, " "); print }
    ' "$1"
}

# One paragraph per output line, prefixed with the line it starts on.
join_paragraphs() {
    awk '
        /^[[:space:]]*$/ { if (buf != "") { printf "%d:%s\n", start, buf; buf = "" } ; next }
        { if (buf == "") { start = NR; buf = $0 } else { buf = buf " " $0 } }
        END { if (buf != "") printf "%d:%s\n", start, buf }
    ' "$1"
}

# $1 = joined-paragraph file, $2 = pattern file. One output line per hit.
scan_list() {
    local joined="$1" patterns="$2"
    local pat rx para start text hit

    while IFS= read -r pat; do
        case "$pat" in
            ''|'#'*) continue ;;
        esac
        rx="$(port "$pat")"
        while IFS= read -r para; do
            start="${para%%:*}"
            text="${para#*:}"
            while IFS= read -r hit; do
                [ -n "$hit" ] || continue
                printf '  line %-6s %-30s [%s]\n' \
                    "$start" "$(printf '%s' "$hit" | cut -c1-30)" "$pat"
            done < <(printf '%s\n' "$text" | "$GREP" -i -o $WB_FLAG -E "$rx" 2> /dev/null)
        done < <("$GREP" -i $WB_FLAG -E "$rx" "$joined" 2> /dev/null)
    done < "$patterns"
}

# ------------------------------------------------------------------------ main

total=0
gate_total=0
gate_counts="$(tmpfile)"

for target in "${files[@]}"; do
    if [ ! -r "$target" ]; then
        echo "scan.sh: cannot read $target" >&2
        continue
    fi

    echo "=== $target"
    gate_n=0

    tmp_join="$(tmpfile)"
    tmp_strict="$(tmpfile)"
    tmp_loose="$(tmpfile)"
    tmp_prose="$(tmpfile)"
    tmp_join2="$(tmpfile)"
    strip_code "$target" > "$tmp_prose"
    join_paragraphs "$tmp_prose" > "$tmp_join"
    cp "$tmp_join" "$tmp_join2"
    scan_list "$tmp_join" "$strict" > "$tmp_strict"
    scan_list "$tmp_join" "$loose" > "$tmp_loose"

    n_strict="$("$GREP" -c . "$tmp_strict" || true)"
    n_loose="$("$GREP" -c . "$tmp_loose" || true)"

    echo "--- banlist hits, rewrite these: $n_strict"
    [ "$n_strict" -gt 0 ] && sort -k2,2n "$tmp_strict"
    gate_n=$((gate_n + n_strict))
    echo "--- needs judgment, check the carve-outs in SKILL.md: $n_loose"
    [ "$n_loose" -gt 0 ] && cat "$tmp_loose"
    rm -f "$tmp_join" "$tmp_strict" "$tmp_loose"

    # Invisible characters. Nothing here has a legitimate use in a plain-text
    # technical document, and none of it shows up in an editor. Matched as
    # literal bytes, so no PCRE is needed.
    echo "--- hidden characters"
    hid=0
    while IFS="$(printf '\t')" read -r esc name; do
        case "$esc" in
            ''|'#'*) continue ;;
        esac
        ch="$(printf '%b' "$esc")"
        found="$(LC_ALL=C "$GREP" -c -F "$ch" "$target" 2> /dev/null || true)"
        if [ "${found:-0}" -gt 0 ]; then
            lines="$(LC_ALL=C "$GREP" -n -F "$ch" "$target" | cut -d: -f1 | tr '\n' ' ')"
            printf '  %-38s x%-4s line %s\n' "$name" "$found" "$lines"
            hid=$((hid + found))
        fi
    done < "$hidden"
    ent="$("$GREP" -n -i -o -E '&(mdash|ndash|nbsp|ensp|emsp|thinsp|shy|#8212|#x2014|#160|#8194|#8195|#8201|#8239|#173|#8203);' "$target" 2> /dev/null || true)"
    if [ -n "$ent" ]; then
        printf '%s\n' "$ent" | sed 's/^/  HTML entity, line /'
        hid=$((hid + $(printf '%s\n' "$ent" | "$GREP" -c . )))
    fi
    [ "$hid" -eq 0 ] && echo "  clean"
    gate_n=$((gate_n + hid))

    # Decorative punctuation. Straight quotes, plain hyphen and three dots
    # instead. Diacritics belong to the spelling and are never flagged.
    echo "--- decorative punctuation"
    punct=""
    if [ "$has_p" = "yes" ]; then
        punct="$("$GREP" -n -o -P '[\x{2010}-\x{2015}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}\x{00AB}\x{00BB}\x{2190}\x{2192}\x{2022}\x{00A0}\x{2264}\x{2265}\x{2260}]' "$target" 2> /dev/null)"
    fi
    if [ -z "$punct" ]; then
        nbsp="$(printf '\302\240')"
        punct="$("$GREP" -n -o -F -e '—' -e '–' -e '‒' -e '―' -e '…' \
                                  -e '“' -e '”' -e '‘' -e '’' -e '«' -e '»' \
                                  -e '→' -e '←' -e '•' -e '≤' -e '≥' -e '≠' \
                                  -e "$nbsp" "$target" 2> /dev/null)"
    fi
    if [ "$has_p" = "yes" ]; then
        emoji="$("$GREP" -n -o -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]' "$target" 2> /dev/null)"
    else
        # Match the UTF-8 byte sequences instead: F0 9F xx xx covers the
        # pictographs, E2 98..9E xx the dingbats, EF B8 8F the variation
        # selector. Coarser than the PCRE ranges, and it needs no PCRE.
        emoji="$(LC_ALL=C "$GREP" -n -o -E \
            $'\xf0\x9f[\x80-\xbf][\x80-\xbf]|\xe2[\x98-\x9e][\x80-\xbf]|\xef\xb8\x8f' \
            "$target" 2> /dev/null)"
    fi
    if [ -n "$punct" ] || [ -n "$emoji" ]; then
        [ -n "$punct" ] && printf '%s\n' "$punct" | sed 's/^/  line /'
        [ -n "$emoji" ] && printf '%s\n' "$emoji" | sed 's/^/  emoji, line /'
        gate_n=$((gate_n + $(printf '%s%s' "$punct" "$emoji" | "$GREP" -c . || true)))
    else
        echo "  clean"
    fi

    # Structural tics a regex can see. A --- on line 1 is YAML frontmatter,
    # not a divider.
    echo "--- structural tics"
    struct=0
    div="$("$GREP" -n -E '^[[:space:]]*-{3,}[[:space:]]*$' "$tmp_prose" | "$GREP" -v '^1:' || true)"
    if [ -n "$div" ]; then
        printf '%s\n' "$div" | sed 's/^/  divider, line /'
        struct=1
    fi
    bold="$("$GREP" -n -E '^[[:space:]]*[-*][[:space:]]+\*\*[^*]+\*\*[[:space:]]*[:-]' "$target" || true)"
    if [ -n "$bold" ]; then
        printf '%s\n' "$bold" | cut -c1-70 | sed 's/^/  bold-term bullet, line /'
        struct=1
    fi
    [ "$struct" -eq 0 ] && echo "  clean"
    gate_n=$((gate_n + struct))

    # Spelling variant. Explicit flag beats a marker in the file, which beats
    # the tally. Detection from content is a judgment call and stays with the
    # reader of this output.
    echo "--- spelling variant"
    marker="$(head -20 "$target" 2> /dev/null \
        | "$GREP" -i -o -m1 -E '^[[:space:]]*(<!--|%|#|//)?[[:space:]]*variant:[[:space:]]*(us|eu|gb|uk|british)' \
        | "$GREP" -i -o -E 'variant:[[:space:]]*(us|eu|gb|uk|british)' | tr 'A-Z' 'a-z')"
    us_hits=""
    gb_hits=""
    while IFS='|' read -r us gb; do
        case "$us" in ''|'#'*) continue ;; esac
        found="$("$GREP" -i -o -w -E "${us%e}(e|es|ed|ing|s|ations?)?" "$tmp_prose" 2> /dev/null)"
        [ -n "$found" ] && us_hits="${us_hits}${found}"$'\n'
        found="$("$GREP" -i -o -w -E "${gb%e}(e|es|ed|ing|s|ations?)?" "$tmp_prose" 2> /dev/null)"
        [ -n "$found" ] && gb_hits="${gb_hits}${found}"$'\n'
    done < "$pairs"

    ize="$("$GREP" -i -o -w -E "$(port '\b[a-z]{3,}(ize|izes|ized|izing|ization|izations)\b')" "$tmp_prose" 2> /dev/null)"
    ise="$("$GREP" -i -o -w -E "$(port '\b[a-z]{3,}(ise|ises|ised|ising|isation|isations)\b')" "$tmp_prose" 2> /dev/null \
           | "$GREP" -i -v -E "^(${ise_both})(s|es|ed|ing|d)?$" || true)"
    [ -n "$ize" ] && us_hits="${us_hits}${ize}"$'\n'
    [ -n "$ise" ] && gb_hits="${gb_hits}${ise}"$'\n'

    n_us="$(printf '%s' "$us_hits" | "$GREP" -c . || true)"
    n_gb="$(printf '%s' "$gb_hits" | "$GREP" -c . || true)"

    eff="$variant"
    if [ -n "$marker" ]; then
        echo "  file marker: $marker"
        if [ "$eff" = "auto" ]; then
            case "$marker" in *us*) eff="us" ;; *) eff="eu" ;; esac
        fi
    fi
    echo "  US markers: $n_us   EU/British markers: $n_gb   (variant: $eff)"
    if [ "$eff" = "auto" ] && [ "$n_us" -gt 0 ] && [ "$n_gb" -gt 0 ]; then
        echo "  MIXED, pick one variant and convert the minority:"
        [ "$n_us" -le "$n_gb" ] && printf '%s' "$us_hits" | sort -u -f | sed 's/^/    US: /'
        [ "$n_gb" -lt "$n_us" ] && printf '%s' "$gb_hits" | sort -u -f | sed 's/^/    EU: /'
    fi
    if [ "$eff" = "us" ] && [ "$n_gb" -gt 0 ]; then
        printf '%s' "$gb_hits" | sort -u -f | sed 's/^/  convert to US: /'
    fi
    if [ "$eff" = "eu" ] && [ "$n_us" -gt 0 ]; then
        printf '%s' "$us_hits" | sort -u -f | sed 's/^/  convert to EU: /'
    fi

    # Dates, clock and units. Identical in both variants.
    echo "--- dates, clock, units"
    loc=0
    for check in \
        '[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}::ambiguous numeric date, use YYYY-MM-DD' \
        '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{2,4}::German numeric date, use YYYY-MM-DD' \
        '[0-9]{1,2}(:[0-9]{2})?[[:space:]]?[ap]\.?m\.?\b::12-hour clock, use 24-hour' \
        '[0-9],[0-9]{1,2}[[:space:]]?(%|GB|MB|ms|s\b)::decimal comma, use a point' \
        '\b[0-9]+(GB|MB|TB|KB|MHz|GHz|ms|Gbit)\b::missing space between number and unit'
    do
        pat="${check%%::*}"; note="${check##*::}"
        hit="$("$GREP" -n -o $WB_FLAG -E "$(port "$pat")" "$target" 2> /dev/null)"
        if [ -n "$hit" ]; then
            printf '%s\n' "$hit" | sed "s/^/  line /; s/$/   <- $note/"
            loc=1
        fi
    done
    # A time with no zone. Matching the optional zone greedily and then keeping
    # only the matches that stopped at the minutes avoids a negative lookahead,
    # which BSD grep has no way to express.
    tz="$("$GREP" -n -o -E '[0-9]{1,2}:[0-9]{2}([[:space:]]*(UTC|GMT|CES?T|EES?T|WES?T|Z|[+-][0-9]{2}:?[0-9]{2}))?' "$target" 2> /dev/null \
          | "$GREP" -E ':[0-9]{1,2}:[0-9]{2}$' || true)"
    if [ -n "$tz" ]; then
        printf '%s\n' "$tz" | sed 's/^/  line /; s/$/   <- time without a time zone/'
        loc=1
    fi
    [ "$loc" -eq 0 ] && echo "  clean"

    # Second-language interference. The word lists are first-language neutral;
    # references/l1/<language>.md holds what each L1 adds.
    if [ "$do_l1" = "yes" ]; then
        echo "--- second-language interference"
        tmp_e="$(tmpfile)"; tmp_f="$(tmpfile)"
        scan_list "$tmp_join2" "$l1_err" > "$tmp_e"
        scan_list "$tmp_join2" "$l1_ff" > "$tmp_f"
        n_e="$("$GREP" -c . "$tmp_e" || true)"
        n_f="$("$GREP" -c . "$tmp_f" || true)"
        if [ "$n_e" -gt 0 ]; then
            echo "  wrong in any register: $n_e"
            sort -k2,2n "$tmp_e"
            gate_n=$((gate_n + n_e))
        fi
        if [ "$n_f" -gt 0 ]; then
            echo "  false friends, check against the L1 file: $n_f"
            sort -k2,2n "$tmp_f"
        fi
        [ "$n_e" -eq 0 ] && [ "$n_f" -eq 0 ] && echo "  clean"
        rm -f "$tmp_e" "$tmp_f"
    fi
    rm -f "$tmp_join2" "$tmp_prose"

    total=$((total + n_strict + n_loose))
    [ "$gate_n" -gt 0 ] && printf '%s %s\n' "$gate_n" "$target" >> "$gate_counts"
    gate_total=$((gate_total + gate_n))
    echo
done

echo "total phrase hits: $total"
echo "gate hits (unambiguous, ratchetable): $gate_total"
echo "Now read the draft for the constructions grep cannot see (SKILL.md, step 2)."

# The gate counts only what needs no judgment: banlist phrases, hidden
# characters, decorative punctuation, structural tics, and interference that is
# wrong in any register. Loose hits and false friends never fail a build.
rc=0

if [ -n "$write_baseline" ]; then
    sort -k2 "$gate_counts" > "$write_baseline"
    echo
    echo "wrote baseline: $("$GREP" -c . "$write_baseline" || true) files, $gate_total hits"
fi

if [ -n "$baseline" ]; then
    echo
    if [ ! -r "$baseline" ]; then
        echo "scan.sh: cannot read baseline $baseline" >&2
        rm -f "$gate_counts"
        exit 2
    fi
    # A ratchet fails three ways: a file got worse, a file is new and dirty, and
    # a file improved without the win being recorded. The third keeps the
    # baseline honest about the real floor.
    drift=0
    while read -r was file; do
        [ -n "${file:-}" ] || continue
        now="$("$GREP" -E "^[0-9]+ ${file}$" "$gate_counts" 2> /dev/null | cut -d' ' -f1)"
        now="${now:-0}"
        if [ "$now" -gt "$was" ]; then
            echo "regressed: $file $was -> $now"
            drift=1
        elif [ "$now" -lt "$was" ]; then
            echo "improved:  $file $was -> $now   lock it in with --write-baseline"
            drift=1
        fi
    done < "$baseline"
    while read -r now file; do
        [ -n "${file:-}" ] || continue
        if ! "$GREP" -q -E "^[0-9]+ ${file}$" "$baseline" 2> /dev/null; then
            echo "new and not clean: $file has $now"
            drift=1
        fi
    done < "$gate_counts"
    if [ "$drift" -eq 0 ]; then
        echo "ratchet holds: no file above its baseline"
    else
        rc=1
    fi
elif [ "$gate" = "yes" ] && [ "$gate_total" -gt 0 ]; then
    rc=1
fi

rm -f "$gate_counts"
exit "$rc"
