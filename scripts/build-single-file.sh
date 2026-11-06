#!/bin/bash
# build-single-file.sh - SKILL.md, the references and the license as one
# Markdown file. It is for tools that take documents but can neither extract an
# archive nor run the scanner. Examples are Gemini Notebook (formerly
# NotebookLM) and chat assistants that only read their knowledge files. SQLite
# ships its C sources the same way and calls the result the amalgamation.
#
#   bash scripts/build-single-file.sh > claudism-pass-single-file.md
#
# Every file is copied unchanged under a heading that names its path. Only the
# Markdown headings move down one level, so the parts nest; lists and the
# license go into text blocks. The result can be checked against the
# repository line by line.

set -eu

here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
root="$(cd "${here}/.." && pwd)"
ref="${root}/references"

version="$(sed -n 's/^  version: "\(.*\)"$/\1/p' "${root}/SKILL.md" | head -n 1)"
lexicon="$(cat "${ref}/VERSION")"
build="$(git -C "$root" describe --tags --always 2> /dev/null || true)"

# Headings one level down, outside fenced code blocks.
demote() {
    awk '
        /^[ \t]*(```|~~~)/ { fence = !fence; print; next }
        !fence && /^#{1,5} / { print "#" $0; next }
        { print }
    ' "$1"
}

# SKILL.md without its YAML front matter.
body() {
    awk '
        NR == 1 && /^---$/ { fm = 1; next }
        fm && /^---$/ { fm = 0; lead = 1; next }
        fm { next }
        lead && /^$/ { next }
        { lead = 0; print }
    ' "$1"
}

# A plain-text file in a text block. Four backticks, because artifacts.txt has
# a pattern that contains three.
listing() {
    printf '\n## %s\n\n%s\n\n````text\n' "$1" "$2"
    cat "${root}/$1"
    printf '````\n'
}

cat <<EOF
# Claudism pass, single-file edition

Version ${version}, lists of ${lexicon}${build:+, built from ${build}}.
Source: https://github.com/mge1512/skill-claudism-pass. CC0 1.0; Part 6 has the
license and the credits for included work.

This file contains SKILL.md, the references and the license of the
claudism-pass skill. It is for tools that take documents but can neither
extract an archive nor run the scanner. Examples are Gemini Notebook (formerly
NotebookLM) and chat assistants that only read their knowledge files. Each file
is copied unchanged under a heading with its path; only the heading levels are
one step lower.

## How to use it

1. Give the tool this file as a document: a source in a notebook, a knowledge
   file in an assistant.
2. Paste the custom instructions below into the tool's field for instructions
   that apply to every chat. In Gemini Notebook, that is Configure chat,
   Custom. Without the instructions, the rules apply only when a question
   happens to bring them up.
3. For a Claudism pass, ask for one and paste the draft with the request, or
   name the source that contains it. Other requests get a normal answer, and
   English answers follow the rules.

## What is missing without the scanner

The skill normally runs \`scripts/scan.sh\` for Step 1 of the pass. Here Step 1
is done by reading: the draft is compared with the banlist (Part 2) and the
lists (Part 4). Banned phrases and leaked chat tokens can be found that way.
Invisible characters (zero-width and no-break spaces, bidi controls) and the
difference between straight and curly quotes mostly cannot. Where the final
text must be free of them, run the scanner on it.

## Where the paths in Part 1 point

| Path in the skill | Part of this file |
| --- | --- |
| \`SKILL.md\` | Part 1 |
| \`references/banlist.md\` | Part 2 |
| \`references/l1/*.md\` | Part 3 |
| \`references/*.txt\`, \`references/l1/*.txt\` | Part 4 |
| \`references/detection.md\` | Part 5 |
| \`LICENSE\` | Part 6 |

## Custom instructions

Paste this into the tool's field for custom instructions:

\`\`\`\`text
EOF
cat "${here}/single-file-instructions.txt"
printf '````\n'

printf '\n# Part 1: The skill (SKILL.md)\n\n'
body "${root}/SKILL.md" | demote -

printf '\n# Part 2: The banlist (references/banlist.md)\n\n'
demote "${ref}/banlist.md"

printf '\n# Part 3: First-language interference (references/l1/)\n'
for l in common german czech dutch french spanish italian greek; do
    printf '\nFile: `references/l1/%s.md`\n\n' "$l"
    demote "${ref}/l1/${l}.md"
done

cat <<'EOF'

# Part 4: Lists the scanner matches

One extended regular expression per line, matched without regard to case
unless the file says otherwise; lines starting with # are comments. `\b` marks
a word boundary, `(a|b)` means a or b, `[a-z]+` stands for any word and
`.{1,40}` for up to 40 characters. A line in `patterns.txt` is a rewrite
without discussion; a line in `patterns-loose.txt` needs a judgment call.
EOF
listing references/patterns.txt "Banned phrases: every match is rewritten."
listing references/patterns-loose.txt "Phrases with legitimate uses: every match needs a judgment call."
listing references/artifacts.txt "Leaked scaffolding and chatbot boilerplate: every match is removed."
listing references/hidden-unicode.txt "Invisible characters, as octal byte sequences with their names."
listing references/variant-pairs.txt "US and British spelling pairs for the variant switch."
listing references/rotations.txt "Synonym sets: pick one member per document."
listing references/l1/errors.txt "First-language interference the scanner can match."
listing references/l1/false-friends.txt "Words that usually mean something else in a European first language."

printf '\n# Part 5: Notes on detection (references/detection.md)\n\n'
demote "${ref}/detection.md"

printf '\n# Part 6: License (LICENSE)\n\n````text\n'
cat "${root}/LICENSE"
printf '````\n'
