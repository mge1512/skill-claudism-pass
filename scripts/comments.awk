# comments.awk - keep the comment text of a source file, blank everything else,
# and preserve the line numbering so a hit can be reported against the original.
#
#   awk -v lang=js -f comments.awk file.ts
#
# lang:
#   js        // and /* */, with regex-literal detection   (JavaScript, TypeScript)
#   cfamily   // and /* */, no regex literals              (C, C++, Java, Go, CSS)
#   rust      cfamily plus nested block comments           (Rust)
#   python    # comments plus docstrings                   (Python)
#   shell     # comments, heredoc bodies skipped           (sh, bash, zsh)
#   hash      # comments                                   (YAML, TOML, Make, conf)
#   dash      -- to end of line                            (SQL, Lua, Ada)
#   semi      ; to end of line                             (Lisp, ini, assembler)
#   percent   % to end of line                             (LaTeX, Erlang)
#
# POSIX awk only: no gensub, no multi-character RS, no length() on an array, no
# \x escapes. Runs on the awk that ships with Linux, BSD and macOS alike.
#
# A state machine, not a parser. It knows strings, escapes, heredocs and (in js
# mode) regular expression literals, so a comment marker inside any of those is
# not mistaken for a comment. What it does not know is the grammar, so one case
# stays ambiguous: a slash after a closing parenthesis is read as division, and
# `if (x) /re/.test(s)` therefore misreads that one line. A misread line is the
# worst outcome; nothing propagates past it.

BEGIN {
    if (lang == "") lang = "hash"
    blockdepth = 0          # inside /* */, and how deep for rust
    multi = ""              # a string still open at end of line: ` or """ or '''
    heredoc = ""            # heredoc terminator word, "" when not in one
    heredoc_dash = 0     # <<- allows the terminator to be indented
    docstring = 0
    prev = ""               # last significant character, for the regex heuristic
}

function blanks(k,    s) {
    s = ""
    while (k-- > 0) s = s " "
    return s
}

{
    line = $0
    n = length(line)
    out = ""
    i = 1
    instr = ""

    # A heredoc body is data. Blank the whole line, and look for the terminator.
    if (heredoc != "") {
        t = line
        if (heredoc_dash) sub(/^[ \t]+/, "", t)
        if (t == heredoc) heredoc = ""
        print blanks(n)
        next
    }

    # A string that was still open at the end of the previous line.
    if (multi != "") {
        ml = length(multi)
        while (i <= n) {
            if (substr(line, i, ml) == multi) {
                keep = (multi == "\"\"\"" || multi == "'''")
                multi = ""
                out = out blanks(ml)
                i = i + ml
                break
            }
            # docstring text is prose and is kept; a raw string is not
            if (docstring) out = out substr(line, i, 1)
            else out = out " "
            i = i + 1
        }
        if (multi != "") {
            if (docstring) print line
            else print blanks(n)
            next
        }
    }

    while (i <= n) {
        c = substr(line, i, 1)
        c2 = substr(line, i + 1, 1)

        # ---- inside a block comment: keep the text
        if (blockdepth > 0) {
            if (lang == "rust" && c == "/" && c2 == "*") {
                blockdepth = blockdepth + 1
                out = out "/*"
                i = i + 2
                continue
            }
            if (c == "*" && c2 == "/") {
                blockdepth = blockdepth - 1
                out = out "  "
                i = i + 2
                continue
            }
            out = out c
            i = i + 1
            continue
        }

        # ---- inside a single-line string
        if (instr != "") {
            if (c == "\\") { out = out "  "; i = i + 2; continue }
            if (c == instr) instr = ""
            out = out " "
            i = i + 1
            continue
        }

        # ---- python docstrings and triple-quoted strings
        if (lang == "python" && (substr(line, i, 3) == "\"\"\"" || substr(line, i, 3) == "'''")) {
            q = substr(line, i, 3)
            j = index(substr(line, i + 3), q)
            if (j > 0) {                       # opens and closes on this line
                out = out blanks(3) substr(line, i + 3, j - 1) blanks(3)
                i = i + 3 + j + 2
            } else {                           # runs on
                multi = q
                docstring = 1
                out = out blanks(3) substr(line, i + 3)
                i = n + 1
            }
            continue
        }

        # ---- a string that may cross lines
        if ((lang == "js" || lang == "cfamily" || lang == "rust") && c == "`") {
            multi = "`"
            docstring = 0
            j = index(substr(line, i + 1), "`")
            if (j > 0) { out = out blanks(j + 1); i = i + j + 1; multi = "" }
            else { out = out blanks(n - i + 1); i = n + 1 }
            continue
        }

        # ---- ordinary strings
        if (c == "\"" || c == "'") {
            instr = c
            out = out " "
            i = i + 1
            prev = c
            continue
        }

        # ---- comments
        if ((lang == "js" || lang == "cfamily" || lang == "rust") && c == "/" && c2 == "/") {
            out = out substr(line, i)
            break
        }
        if ((lang == "js" || lang == "cfamily" || lang == "rust") && c == "/" && c2 == "*") {
            blockdepth = 1
            out = out "  "
            i = i + 2
            continue
        }

        # ---- a slash in js: regex literal or division?
        if (lang == "js" && c == "/") {
            if (prev ~ /[A-Za-z0-9_$)\]]/) {          # division
                out = out " "
                i = i + 1
                prev = "/"
                continue
            }
            j = i + 1                                  # regex literal
            incls = 0
            while (j <= n) {
                d = substr(line, j, 1)
                if (d == "\\") { j = j + 2; continue }
                if (d == "[") incls = 1
                else if (d == "]") incls = 0
                else if (d == "/" && !incls) break
                j = j + 1
            }
            out = out blanks(j - i + 1)
            i = j + 1
            prev = "/"
            continue
        }

        if (lang == "shell" && c == "<" && c2 == "<") {
            rest = substr(line, i + 2)
            hd = 0
            if (match(rest, /^-?[ \t]*["']?[A-Za-z_][A-Za-z0-9_]*["']?/)) {
                word = substr(rest, RSTART, RLENGTH)
                heredoc_dash = (substr(word, 1, 1) == "-")
                sub(/^-/, "", word)
                sub(/^[ \t]+/, "", word)
                gsub(/["']/, "", word)
                if (word != "") { heredoc = word; hd = 1 }
            }
            out = out blanks(2 + (hd ? RLENGTH : 0))
            i = i + 2 + (hd ? RLENGTH : 0)
            continue
        }

        if ((lang == "hash" || lang == "shell" || lang == "python") && c == "#" \
            && (i == 1 || substr(line, i - 1, 1) == " " || substr(line, i - 1, 1) == "\t")) {
            out = out substr(line, i)
            break
        }
        if (lang == "dash" && c == "-" && c2 == "-") { out = out substr(line, i); break }
        if (lang == "semi" && c == ";")              { out = out substr(line, i); break }
        if (lang == "percent" && c == "%")           { out = out substr(line, i); break }

        if (c != " " && c != "\t") prev = c
        out = out " "
        i = i + 1
    }

    print out
}
