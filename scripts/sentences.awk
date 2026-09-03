# sentences.awk - report sentences longer than a word limit.
#
#   awk -v limit=25 -f sentences.awk file
#
# Output: endline:wordcount:first words of the sentence
#
# Sentence length is the most reliable predictor of misreading for a reader who
# is fluent in English but did not grow up with it. ASD-STE100 puts the limit at
# 20 words for an instruction and 25 for an explanation; those numbers are the
# default here.
#
# Counting follows the same idea as STE rule 8.6: what the scanner has already
# blanked (code spans, identifiers, command output) does not inflate the count.
# Markdown headings and table rows are skipped, and a list marker is not a word.
#
# POSIX awk only.

BEGIN {
    if (limit == "") limit = 25
    n = 0
    txt = ""
}

function report() {
    if (n > limit) printf "%d:%d:%s\n", NR, n, substr(txt, 1, 44)
    n = 0
    txt = ""
}

{
    line = $0
    if (line ~ /^[[:space:]]*$/) { n = 0; txt = ""; next }
    if (line ~ /^[[:space:]]*#/) next
    if (line ~ /^[[:space:]]*\|/) next
    if (line ~ /^[[:space:]]*>/) next
    sub(/^[[:space:]]*[-*+][[:space:]]+/, "", line)
    sub(/^[[:space:]]*[0-9]+[.)][[:space:]]+/, "", line)

    nf = split(line, w, /[[:space:]]+/)
    for (i = 1; i <= nf; i++) {
        if (w[i] == "") continue
        n = n + 1
        if (txt == "") txt = w[i]
        else txt = txt " " w[i]

        # A word ending in a terminator closes the sentence, unless it is a
        # known abbreviation or an initial.
        if (w[i] ~ /[.!?][")']?$/) {
            if (w[i] ~ /^(e\.g\.|i\.e\.|etc\.|vs\.|cf\.|approx\.|no\.|fig\.|resp\.|Dr\.|Mr\.|Mrs\.|Ms\.|St\.|Inc\.|Ltd\.)$/) continue
            if (w[i] ~ /^[A-Z]\.$/) continue
            report()
        }
    }
}

END { report() }
