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

# Output must not depend on the reader's locale. Two things are at stake and they
# pull apart, so they are set separately: collation decides how report lines that
# share a line number sort against each other, and must be C for the output to be
# reproducible; character type must be UTF-8 for the grep -P ranges in the hidden
# character check. LC_ALL cannot express that, because it overrides both, so it is
# cleared. C.UTF-8 alone would not do either: macOS does not ship it, and the
# en_US.UTF-8 it would fall back to collates in dictionary order.
unset LC_ALL
export LC_COLLATE=C

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
            if printf '\xe2\x80\x94' | LC_CTYPE="$cand" "$GREP" -q -P '\x{2014}' 2> /dev/null; then
                export LC_CTYPE="$cand"
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

# A pattern bounded by \b on one side only gets grep -w on neither side (see
# wflag below), so the one boundary is spelled out instead: "\bhere," must not
# match "there," or "everywhere,". The class consumes the neighboring
# character, which trim_hit removes again before the hit is printed.
port() {
    if [ "$has_wb" = "yes" ]; then
        printf '%s' "$1"
        return
    fi
    case "$1" in
        '\b'*'\b') printf '%s' "$1" | sed 's/\\b//g' ;;
        '\b'*) printf '(^|[^[:alnum:]_])%s' "$(printf '%s' "${1#??}" | sed 's/\\b//g')" ;;
        *'\b') printf '%s([^[:alnum:]_]|$)' "$(printf '%s' "${1%??}" | sed 's/\\b//g')" ;;
        *) printf '%s' "$1" | sed 's/\\b//g' ;;
    esac
}

# $1 = original pattern, $2 = matched text from the ported pattern.
trim_hit() {
    local h="$2"
    if [ "$has_wb" != "yes" ]; then
        case "$1" in
            '\b'*'\b') ;;
            '\b'*) h="${h#[^[:alnum:]_]}" ;;
            *'\b') h="${h%[^[:alnum:]_]}" ;;
        esac
    fi
    printf '%s' "$h"
}

# grep -w enforces a word boundary at BOTH ends of the match, unconditionally.
# That equals \b only for patterns bounded by \b at both ends. A pattern that
# starts with punctuation (", because ...", ", highlighting ...") would be
# rejected, because the character before the comma is a letter, and it would
# silently never match. So -w is applied per pattern, only where the original
# was bounded on both sides. port() spells out the boundary of a one-sided
# pattern instead.
wflag() {
    [ "$has_wb" = "yes" ] && return 0
    case "$1" in
        '\b'*'\b') printf '%s' '-w' ;;
    esac
}

tmpfile() {
    if command -v mktemp > /dev/null 2>&1; then
        mktemp "${TMPDIR:-/tmp}/claudism.XXXXXX"
    else
        # Restricted runtimes without mktemp: pick an unused name from the PID.
        # mktemp also creates the file, so this does too. The race window is
        # acceptable for a scratch file owned by the running shell.
        d="${TMPDIR:-/tmp}"
        i=0
        while [ -e "$d/claudism.$$.$i" ]; do i=$((i + 1)); done
        f="$d/claudism.$$.$i"
        : > "$f" || return 1
        printf '%s\n' "$f"
    fi
}

# ---------------------------------------------------------------------- inputs

# BASH_SOURCE is unset in some restricted runtimes; $0 is the fallback there.
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ref="${here}/../references"
strict="${ref}/patterns.txt"
loose="${ref}/patterns-loose.txt"
pairs="${ref}/variant-pairs.txt"
l1_err="${ref}/l1/errors.txt"
l1_ff="${ref}/l1/false-friends.txt"
hidden="${ref}/hidden-unicode.txt"
artifacts="${ref}/artifacts.txt"
lexicon_file="${ref}/VERSION"
rotations="${ref}/rotations.txt"
sentences_awk="${here}/sentences.awk"

variant="auto"
do_l1="yes"
gate="no"
maxsent=25
do_comments="no"
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
        --comments)                 do_comments="yes" ;;
        --max-sentence=*)           maxsent="${arg#*=}" ;;
        --gate)                     gate="yes" ;;
        --baseline=*)               baseline="${arg#*=}" ;;
        --write-baseline=*)         write_baseline="${arg#*=}" ;;
        -h|--help)
            echo "usage: bash scan.sh [--us|--eu] [--no-l1] FILE [FILE...]"
            echo "  --us | --eu   force the spelling variant (default: auto)"
            echo "  --no-l1       skip the second-language interference check"
            echo "  --comments    scan the comments of a source file, not prose"
            echo "  --max-sentence=N  report sentences longer than N words (default 25;"
            echo "                    20 suits procedural text)"
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

# The awk programs are checked with the lists. A missing one does not make awk
# crash the scan: it makes awk print nothing, and nothing reads as "clean".
comments_awk="${here}/comments.awk"
need="$strict $loose $pairs $l1_err $l1_ff $hidden $artifacts $rotations $sentences_awk"
[ "$do_comments" = "yes" ] && need="$need $comments_awk"
for f in $need; do
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

lexicon="$(cat "$lexicon_file" 2> /dev/null || echo unknown)"

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

# Typographic quotes, as word processors and chat windows produce them. The lists
# are written with ASCII quotes, so the phrase and scaffolding checks read a copy
# with U+2018 and U+2019 folded to ' and U+201C and U+201D to ". The
# decorative-punctuation check reads the original and still reports them.
lsq="$(printf '\342\200\230')"; rsq="$(printf '\342\200\231')"
ldq="$(printf '\342\200\234')"; rdq="$(printf '\342\200\235')"
fold_quotes() {
    LC_ALL=C sed -e "s/${lsq}/'/g" -e "s/${rsq}/'/g" \
                 -e "s/${ldq}/\"/g" -e "s/${rdq}/\"/g" "$1"
}

# Blank the contents of double-quoted spans. A document that quotes a chatbot is
# a human writing about a machine, so the self-identification patterns must not
# fire inside quotation marks.
strip_quoted() {
    awk '{ gsub(/"[^"]*"/, " "); print }' "$1"
}

# Comment syntax by file extension, for --comments. See scripts/comments.awk.
awk_lang() {
    case "$1" in
        *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)   echo "js" ;;
        *.rs)                                echo "rust" ;;
        *.py)                                echo "python" ;;
        *.sh|*.bash|*.zsh)                   echo "shell" ;;
        *.c|*.h|*.cc|*.cpp|*.hpp|*.java|*.go|*.css|*.scss|*.kt|*.swift|*.cs)
                                             echo "cfamily" ;;
        *.rb|*.pl|*.yaml|*.yml|*.toml|*.cfg|*.conf|Makefile|*.mk|*.spec)
                                             echo "hash" ;;
        *.sql|*.lua|*.adb|*.ads)             echo "dash" ;;
        *.el|*.lisp|*.scm|*.ini|*.asm|*.s)   echo "semi" ;;
        *.tex|*.sty|*.erl)                   echo "percent" ;;
        *)                                   echo "hash" ;;
    esac
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
    local pat rx wf para start text hit

    while IFS= read -r pat; do
        case "$pat" in
            ''|'#'*) continue ;;
        esac
        rx="$(port "$pat")"
        wf="$(wflag "$pat")"
        while IFS= read -r para; do
            start="${para%%:*}"
            text="${para#*:}"
            while IFS= read -r hit; do
                [ -n "$hit" ] || continue
                hit="$(trim_hit "$pat" "$hit")"
                printf '  line %-6s %-30s [%s]\n' \
                    "$start" "$(printf '%s' "$hit" | cut -c1-30)" "$pat"
            done < <(printf '%s\n' "$text" | "$GREP" -i -o $wf -E "$rx" 2> /dev/null)
        done < <("$GREP" -i $wf -E "$rx" "$joined" 2> /dev/null)
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
    if [ "$do_comments" = "yes" ]; then
        lang="$(awk_lang "$target")"
        case "$target" in
            *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
                echo "  note: a slash after a closing parenthesis is read as division," >&2
                echo "        so 'if (x) /re/.test(s)' misreads that one line." >&2 ;;
        esac
        if ! awk -v lang="$lang" -f "$comments_awk" "$target" > "$tmp_prose"; then
            echo "scan.sh: comments.awk failed on $target; not reporting it clean" >&2
            exit 2
        fi
        check_src="$tmp_prose"
    else
        strip_code "$target" > "$tmp_prose"
        check_src="$target"
    fi
    tmp_qprose="$(tmpfile)"
    fold_quotes "$tmp_prose" > "$tmp_qprose"
    join_paragraphs "$tmp_qprose" > "$tmp_join"
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

    # Leaked scaffolding and chatbot boilerplate. A hit here is near-certain
    # machine origin and pure noise, so it is always a removal.
    echo "--- leaked scaffolding and chatbot boilerplate"
    tmp_art="$(tmpfile)"
    while IFS= read -r pat; do
        case "$pat" in
            ''|'#'*) continue ;;
        esac
        while IFS= read -r hit; do
            [ -n "$hit" ] || continue
            printf '  line %-6s %-30s [%s]\n' \
                "${hit%%:*}" "$(printf '%s' "${hit#*:}" | cut -c1-30)" "$pat" >> "$tmp_art"
        done < <("$GREP" -n -o -E "$(port "$pat")" "$tmp_qprose" 2> /dev/null)
    done < "$artifacts"
    # Visible tokens outside ASCII, written here as octal bytes so that
    # artifacts.txt stays ASCII: the U+3010 reference wrapper of 2026 ChatGPT
    # output ("cite|turn0search0|..."), and dagger citations (U+2020) from
    # DeepSeek, file search and Meta AI.
    for vt in \
        '\343\200\220(cite|filecite|navlist|filenavlist|entity|image_group|url|link_title|products?|video|genui|finance|schedule|standing|forecast|i)[|]::reference in U+3010 brackets' \
        '\343\200\220[0-9]+(:[0-9]+)?\342\200\240::dagger citation (U+3010, U+2020)' \
        '\343\200\220post-[0-9]+\343\200\221::post citation in U+3010 brackets'
    do
        vpat="${vt%%::*}"; vname="${vt##*::}"
        while IFS= read -r hit; do
            [ -n "$hit" ] || continue
            printf '  line %-6s %-30s [%s]\n' \
                "${hit%%:*}" "$(printf '%s' "${hit#*:}" | cut -c1-30)" "$vname" >> "$tmp_art"
        done < <(LC_ALL=C "$GREP" -n -o -E "$(printf '%b' "$vpat")" "$tmp_qprose" 2> /dev/null)
    done
    # A line-start "Assistant:" is ordinary human writing (film credits, staff
    # rosters). It counts only when a line-start "Human:" appears as well.
    if "$GREP" -q -E '^[[:space:]]*Human:' "$tmp_qprose" 2> /dev/null \
       && "$GREP" -q -E '^[[:space:]]*Assistant:' "$tmp_qprose" 2> /dev/null; then
        echo "  Human:/Assistant: transcript markers, both present" >> "$tmp_art"
    fi
    # Self-identification convicts only outside quotation marks.
    tmp_unq="$(tmpfile)"
    strip_quoted "$tmp_qprose" > "$tmp_unq"
    selfid="$("$GREP" -n -o -E -i "(I am|I'm) (Grok|Claude|ChatGPT|Gemini)( built by| made by| trained by| created by)|built by (xAI|Anthropic|OpenAI)|trained by (Google|OpenAI|Anthropic)" "$tmp_unq" 2> /dev/null || true)"
    if [ -n "$selfid" ]; then
        printf '%s\n' "$selfid" | sed 's|^|  line |; s|$|   [self-identification, outside quotes]|' >> "$tmp_art"
    fi
    rm -f "$tmp_unq"
    n_art="$("$GREP" -c . "$tmp_art" || true)"
    if [ "$n_art" -gt 0 ]; then
        sort -k2,2n "$tmp_art"
    else
        echo "  clean"
    fi
    rm -f "$tmp_art"
    gate_n=$((gate_n + n_art))

    # The variant is settled here, before the character checks, because EU mode
    # changes what the no-break space check counts. An explicit flag beats a
    # marker in the file; the tally in the spelling section only reports.
    marker="$(head -20 "$check_src" 2> /dev/null \
        | "$GREP" -i -o -m1 -E '^[[:space:]]*(<!--|%|#|//)?[[:space:]]*variant:[[:space:]]*(us|eu|gb|uk|british)' \
        | "$GREP" -i -o -E 'variant:[[:space:]]*(us|eu|gb|uk|british)' | tr 'A-Z' 'a-z')"
    eff="$variant"
    if [ -n "$marker" ] && [ "$eff" = "auto" ]; then
        case "$marker" in *us*) eff="us" ;; *) eff="eu" ;; esac
    fi

    # Invisible characters. Nothing here has a legitimate use in a plain-text
    # technical document, and none of it shows up in an editor. Matched as
    # literal bytes, so no PCRE is needed.
    echo "--- hidden characters"
    hid=0
    while IFS="$(printf '\t')" read -r esc name; do
        case "$esc" in
            ''|'#'*) continue ;;
        esac
        ctx="no"
        case "$esc" in
            '?'*) ctx="yes"; esc="${esc#?}" ;;
        esac
        ch="$(printf '%b' "$esc")"
        src="$check_src"
        tmp_nb=""
        # EU mode: the Commission's style guide puts a hard space in 3 000,
        # EUR 15 000 and 50 km. Next to a figure it is the prescribed form, so
        # it is listed for checking and not counted.
        if [ "$eff" = "eu" ]; then
            case "$esc" in
                '\302\240'|'\342\200\257')
                    near="$(LC_ALL=C "$GREP" -n -E "[0-9]${ch}|${ch}[0-9]" "$check_src" 2> /dev/null \
                            | cut -d: -f1 | tr '\n' ' ')"
                    near="${near% }"
                    if [ -n "$near" ]; then
                        nn="$(printf '%s\n' $near | "$GREP" -c .)"
                        printf '  check: %-31s x%-4s line %s (EU mode, next to a figure)\n' "$name" "$nn" "$near"
                    fi
                    tmp_nb="$(tmpfile)"
                    LC_ALL=C sed -e "s/\([0-9]\)${ch}/\1 /g" -e "s/${ch}\([0-9]\)/ \1/g" "$check_src" > "$tmp_nb"
                    src="$tmp_nb" ;;
            esac
        fi
        found="$(LC_ALL=C "$GREP" -c -F "$ch" "$src" 2> /dev/null || true)"
        if [ "${found:-0}" -gt 0 ]; then
            lines="$(LC_ALL=C "$GREP" -n -F "$ch" "$src" | cut -d: -f1 | tr '\n' ' ')"
            lines="${lines% }"
            if [ "$ctx" = "yes" ]; then
                printf '  check: %-31s x%-4s line %s\n' "$name" "$found" "$lines"
            else
                printf '  %-38s x%-4s line %s\n' "$name" "$found" "$lines"
                hid=$((hid + found))
            fi
        fi
        [ -n "$tmp_nb" ] && rm -f "$tmp_nb"
    done < "$hidden"
    # Ranges, which a literal list cannot express. Tag characters are both
    # invisible and a known channel for hidden instructions; the private-use
    # block wraps ChatGPT citation tokens, so finding it convicts even when the
    # visible token has already been stripped. A leading "?" marks a range
    # that is reported and never counted, as in hidden-unicode.txt: the
    # variation selectors U+FE00 to U+FE0E are part of CJK and emoji text.
    for rng in \
        '\363\240[\200\201][\200-\277]::TAG CHARACTERS (U+E0000-E007F, hidden-instruction channel)' \
        '\363\240[\204-\207][\200-\277]::VARIATION SELECTOR SUPPLEMENT (U+E0100-E01EF)' \
        '\356\210[\200-\206]::PRIVATE USE (U+E200-E206, wraps chat citation tokens)' \
        '?\357\270[\200-\216]::VARIATION SELECTOR (U+FE00-FE0E)'
    do
        rctx="no"
        case "$rng" in
            '?'*) rctx="yes"; rng="${rng#?}" ;;
        esac
        rpat="${rng%%::*}"; rname="${rng##*::}"
        rhit="$(LC_ALL=C "$GREP" -c -E "$(printf '%b' "$rpat")" "$check_src" 2> /dev/null || true)"
        if [ "${rhit:-0}" -gt 0 ]; then
            if [ "$rctx" = "yes" ]; then
                printf '  check: %-31s x%s\n' "$rname" "$rhit"
            else
                printf '  %-38s x%s\n' "$rname" "$rhit"
                hid=$((hid + rhit))
            fi
        fi
    done
    ent="$("$GREP" -n -i -o -E '&(mdash|ndash|nbsp|ensp|emsp|thinsp|shy|#8212|#x2014|#160|#8194|#8195|#8201|#8239|#173|#8203);' "$check_src" 2> /dev/null || true)"
    if [ -n "$ent" ]; then
        printf '%s\n' "$ent" | sed 's/^/  HTML entity, line /'
        hid=$((hid + $(printf '%s\n' "$ent" | "$GREP" -c . )))
    fi
    [ "$hid" -eq 0 ] && echo "  clean"
    gate_n=$((gate_n + hid))

    # Decorative punctuation. Straight quotes, plain hyphen and three dots
    # instead. Diacritics belong to the spelling and are never flagged.
    echo "--- decorative punctuation"
    # One implementation for both grep paths: the characters are enumerated as
    # UTF-8 byte sequences, so the two paths cannot drift apart and the script
    # stays ASCII. They did drift once: the PCRE class and a literal fallback
    # list disagreed, and U+2010 went undetected on BSD grep. U+00A0 and U+2011
    # are invisible and belong to the hidden-character check above; listing
    # them here as well counted every occurrence twice.
    #   U+2010 U+2012-2015 hyphen and dashes     U+2018 U+2019 U+201C U+201D quotes
    #   U+2026 ellipsis   U+00AB U+00BB guillemets   U+2190 U+2192 arrows
    #   U+2022 bullet     U+2264 U+2265 U+2260 comparison signs
    punct_pat="$(printf '\342\200\220|\342\200\222|\342\200\223|\342\200\224|\342\200\225|\342\200\230|\342\200\231|\342\200\234|\342\200\235|\342\200\246|\302\253|\302\273|\342\206\220|\342\206\222|\342\200\242|\342\211\244|\342\211\245|\342\211\240')"
    punct="$(LC_ALL=C "$GREP" -n -o -E "$punct_pat" "$check_src" 2> /dev/null)"
    if [ "$has_p" = "yes" ]; then
        emoji="$("$GREP" -n -o -P '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]' "$check_src" 2> /dev/null)"
    else
        # Match the UTF-8 byte sequences instead: F0 9F xx xx covers the
        # pictographs, E2 98..9E xx the dingbats, EF B8 8F the variation
        # selector. Coarser than the PCRE ranges, and it needs no PCRE.
        emoji="$(LC_ALL=C "$GREP" -n -o -E \
            $'\xf0\x9f[\x80-\xbf][\x80-\xbf]|\xe2[\x98-\x9e][\x80-\xbf]|\xef\xb8\x8f' \
            "$check_src" 2> /dev/null)"
    fi
    if [ -n "$punct" ] || [ -n "$emoji" ]; then
        [ -n "$punct" ] && printf '%s\n' "$punct" | sed 's/^/  line /'
        [ -n "$emoji" ] && printf '%s\n' "$emoji" | sed 's/^/  emoji, line /'
        gate_n=$((gate_n + $(printf '%s%s' "$punct" "$emoji" | "$GREP" -c . || true)))
    else
        echo "  clean"
    fi

    # Structural tics a regex can see. YAML front matter opens with --- on
    # line 1 and closes with the next --- or ... line. Neither delimiter is a
    # divider. Excluding line 1 alone reported the closing one, so a file with
    # front matter, such as a SKILL.md, could never pass --gate.
    echo "--- structural tics"
    struct=0
    div="$(awk '
        NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
        fm && /^(---|\.\.\.)[[:space:]]*$/ { fm = 0; next }
        fm { next }
        /^[[:space:]]*---+[[:space:]]*$/ { print NR ":" $0 }
    ' "$tmp_prose")"
    if [ -n "$div" ]; then
        printf '%s\n' "$div" | sed 's/^/  divider, line /'
        struct=1
    fi
    # Bold-term bullets: the colon after or inside the bold, numbered items, and
    # the U+2022 and U+2013 bullets of pasted text (as bytes, so this script
    # stays ASCII). Read from the copy with code blanked, so a fenced example
    # is not reported.
    bul="$(printf '\342\200\242')|$(printf '\342\200\223')"
    bold="$(LC_ALL=C "$GREP" -n -E "^[[:space:]]*([-*+]|${bul}|[0-9]+[.)])[[:space:]]+\*\*[^*]+(\*\*[[:space:]]*[:-]|:\*\*)" "$tmp_prose" || true)"
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

    [ -n "$marker" ] && echo "  file marker: $marker"
    echo "  US markers: $n_us   EU/British markers: $n_gb   (variant: $eff)"
    # One flipped word is a quotation, a proper noun or a package name. Two or
    # more is a mixed document.
    if [ "$eff" = "auto" ] && [ "$n_us" -ge 2 ] && [ "$n_gb" -ge 2 ]; then
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

    # Dates, clock and units. Identical in both variants. Official Journal
    # citations are quoted as published (OJ L 119, 4.5.2016, p. 1), so their
    # dates are blanked first.
    echo "--- dates, clock, units"
    loc=0
    tmp_dates="$(tmpfile)"
    LC_ALL=C sed -E 's/(OJ [A-Z]+[^()]{0,30})[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{4}/\1(OJ date)/g' "$check_src" > "$tmp_dates"
    for check in \
        '[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}::ambiguous numeric date, use YYYY-MM-DD' \
        '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{2,4}::German numeric date, use YYYY-MM-DD' \
        '[0-9]{1,2}(:[0-9]{2})?[[:space:]]?[ap]\.?m\.?\b::12-hour clock, use 24-hour' \
        '[0-9],[0-9]{1,2}[[:space:]]?(%|GB|MB|ms|s\b)::decimal comma, use a point' \
        '\b[0-9]+(GB|MB|TB|KB|MHz|GHz|ms|Gbit)\b::missing space between number and unit'
    do
        pat="${check%%::*}"; note="${check##*::}"
        hit="$("$GREP" -n -o $WB_FLAG -E "$(port "$pat")" "$tmp_dates" 2> /dev/null)"
        if [ -n "$hit" ]; then
            printf '%s\n' "$hit" | sed "s/^/  line /; s/$/   <- $note/"
            loc=1
        fi
    done
    rm -f "$tmp_dates"
    # A time with no zone. Matching the optional zone greedily and then keeping
    # only the matches that stopped at the minutes avoids a negative lookahead,
    # which BSD grep has no way to express.
    tz="$("$GREP" -n -o -E '[0-9]{1,2}:[0-9]{2}([[:space:]]*(UTC|GMT|CES?T|EES?T|WES?T|Z|[+-][0-9]{2}:?[0-9]{2}))?' "$check_src" 2> /dev/null \
          | "$GREP" -E ':[0-9]{1,2}:[0-9]{2}$' || true)"
    if [ -n "$tz" ]; then
        printf '%s\n' "$tz" | sed 's/^/  line /; s/$/   <- time without a time zone/'
        loc=1
    fi
    [ "$loc" -eq 0 ] && echo "  clean"

    # Sentence length. A notice, never gated: length is the author's judgment
    # and a long sentence is sometimes the right one.
    echo "--- long sentences (over $maxsent words)"
    if ! long="$(awk -v limit="$maxsent" -f "$sentences_awk" "$tmp_prose")"; then
        echo "scan.sh: sentences.awk failed on $target; not reporting it clean" >&2
        exit 2
    fi
    if [ -n "$long" ]; then
        printf '%s\n' "$long" | while IFS=: read -r ln cnt txt; do
            printf '  line %-6s %3s words   %s...\n' "$ln" "$cnt" "$txt"
        done
    else
        echo "  clean"
    fi

    # Terminology rotations. Also a notice: two members of a set can name two
    # different operations, and only the author knows whether they do.
    echo "--- terminology consistency"
    rot=0
    while IFS= read -r set; do
        case "$set" in ''|'#'*) continue ;; esac
        hits=""
        count=0
        old_ifs="$IFS"; IFS='|'
        for word in $set; do
            if "$GREP" -q -i -w -E "${word}(s|es|ed|ing)?" "$tmp_prose" 2> /dev/null; then
                hits="${hits}${word} "
                count=$((count + 1))
            fi
        done
        IFS="$old_ifs"
        if [ "$count" -ge 2 ]; then
            echo "  ${hits}- pick one and use it throughout"
            rot=$((rot + 1))
        fi
    done < "$rotations"
    [ "$rot" -eq 0 ] && echo "  clean"

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
    rm -f "$tmp_join2" "$tmp_prose" "$tmp_qprose"

    total=$((total + n_strict + n_loose))
    [ "$gate_n" -gt 0 ] && printf '%s %s\n' "$gate_n" "$target" >> "$gate_counts"
    gate_total=$((gate_total + gate_n))
    echo
done

echo "total phrase hits: $total"
echo "gate hits (unambiguous, ratchetable): $gate_total   lexicon $lexicon"
echo "Now read the draft for the constructions grep cannot see (SKILL.md, step 2)."

# The gate counts only what needs no judgment: banlist phrases, hidden
# characters, decorative punctuation, structural tics, and interference that is
# wrong in any register. Loose hits and false friends never fail a build.
rc=0

if [ -n "$write_baseline" ]; then
    { echo "# lexicon $lexicon"; sort -k2 "$gate_counts"; } > "$write_baseline"
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
    base_lex="$("$GREP" -m1 '^# lexicon ' "$baseline" | cut -d' ' -f3)"
    if [ "${base_lex:-none}" != "$lexicon" ]; then
        echo "note: baseline was recorded against lexicon ${base_lex:-none}, the lists are now $lexicon."
        echo "      Counts move when the lists change; re-record after reviewing."
    fi
    while read -r was file; do
        case "$was" in '#'*) continue ;; esac
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
        case "$now" in '#'*) continue ;; esac
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
