# claudism-pass

A Claude skill that scrubs AI-writing tells out of English drafts and adapts the
result to an international technical readership.

It checks a draft against a banlist of the words, phrases and structures that mark
text as machine-written. It also applies a register that suits readers who are
fluent in English but did not grow up with it: common words, literal statements,
consistent terminology, no idiom.

English only. It does not police German, Czech, French or any other language, and
it stays out of code, diffs, configuration and log output.

## Install

The skill is a directory with a `SKILL.md` at its root. Nothing is compiled and
nothing runs at install time.

**Claude Code**

```bash
git clone <repository-url> ~/.claude/skills/claudism-pass
```

Use `.claude/skills/claudism-pass` inside a repository instead if the skill should
be available in that project only. Start a new session afterwards; `/skills` lists what was
picked up. The directory layout must be `claudism-pass/SKILL.md`, with no extra
folder in between.

**Claude.ai and the desktop app**

Settings, then the skills section, then add a custom skill and upload the packaged
`claudism-pass.skill` file. Current steps are at https://support.claude.com if the
menu has moved.

## Use

Write as usual. The skill applies itself when a draft is an English deliverable:
an article, a blog or LinkedIn post, a mail, a README, an abstract, a talk
proposal, slide text, customer-facing material. Short chat replies are left alone.

To run it over text that already exists, say **"Claudism pass"**. Every pass ends
with a short report listing what was found and what replaced it.

Two switches, both resolved the same way: what you say at invocation beats a
marker in the file, which beats detection from the content, which beats the
default.

| Switch | Say | Marker in the file | Default |
| --- | --- | --- | --- |
| Spelling variant | "Claudism pass EU" | `<!-- variant: eu -->` | US |
| First language | "my first language is Czech" | `<!-- l1: cs -->` | none |

US spelling is the default because the identifiers in the same sentence are
already American: `--no-color`, `initialize()`, `text-align: center`. EU spelling
is for EU-facing documents: material about EU regulation, submissions to EU
institutions, public-sector tenders, or a customer who asks for it.

The first-language setting loads a file of the interference that language
produces in English. Supported today: German, Czech (also usable for Slovak and
Polish), Dutch, French, Spanish (also Portuguese), Italian, Greek. Without a
setting, only the shared file applies, which already covers the traps common to
all of them.

Dates, clock and numbers are the same in both variants: `YYYY-MM-DD`, 24-hour
with the time zone named, decimal point, a space before the unit.

## The scanner

```bash
SKILL_DIR=~/.claude/skills/claudism-pass
bash "$SKILL_DIR/scripts/scan.sh" draft.md
bash "$SKILL_DIR/scripts/scan.sh" --eu --no-l1 tender.md
```

It reports banlist phrases, decorative punctuation and emoji, `---` dividers,
mixed spelling variants, date and unit problems, and second-language
interference. Phrases are matched against whole paragraphs, so hard-wrapped mail
text is scanned correctly.

Requirements: bash and GNU grep with `-P`, which SLES, openSUSE and most
distributions ship by default. The script only reads; it writes nothing outside
`/tmp`.

## What it does not do

The scanner matches literal strings. Several constructions use ordinary words in
a particular arrangement, and those need a person or a model reading the draft:
crowned superlatives with an unusual noun, negative parallelism, announcing an
insight instead of delivering it. `SKILL.md` step 2 lists what to look for.

The language files are lists of known traps, not a grammar checker. They catch
the errors that a spelling checker passes over because every word is spelled
correctly.

Detection of a writer's first language is a guess. The skill is instructed to
report what it fixed, never to name the language it inferred, because guessing at
someone's background in an editing report is both rude and often wrong.

## Layout

```
claudism-pass/
├── SKILL.md                       what Claude reads
├── README.md                      this file
├── references/
│   ├── banlist.md                 the tells, with the reasoning for each
│   ├── patterns.txt               literal phrases the scanner matches
│   ├── patterns-loose.txt         phrases that need a judgment call
│   ├── variant-pairs.txt          US and British spelling pairs
│   └── l1/
│       ├── common.md              traps shared across European languages
│       ├── german.md  czech.md  dutch.md
│       ├── french.md  spanish.md  italian.md  greek.md
│       ├── errors.txt             interference the scanner can match
│       └── false-friends.txt      words that usually mean something else
└── scripts/
    └── scan.sh                    the mechanical pass
```

## Contributing

The banlist and the language files are meant to grow.

To add a tell, put an entry in `references/banlist.md` with a short reason and a
plainer replacement, and add the literal phrase to `references/patterns.txt` if a
regular expression can catch it without drowning the output in false positives.
Anything that needs judgment goes in `patterns-loose.txt` instead.

To add a first language, follow the layout of `references/l1/german.md`: a false
friends table, a structure section, and a register note. Add the row to the table
in `SKILL.md`, and add anything mechanically checkable to `references/l1/errors.txt`.
Keep the file short enough that someone reads it to the end.

To add a language that is not European, check the assumption behind `common.md`
first. It is built around false friends and article systems, which does not
describe Japanese, Chinese or Korean interference. Those need article and number
use, topic-comment structure, and politeness calibration instead.

## Source and license

`references/banlist.md` is the Claudisms banlist from https://claudisms.ai/
(Markdown at https://claudisms.ai/claudisms.md), which its publisher released into
the public domain under CC0 1.0. The article behind the list is "Your Name Is Still
on It" (https://wespomeroy.substack.com/p/your-name-is-still-on-it). The local copy
records the date it was taken; the upstream list grows, so re-fetch it now and
then. Entries caught in review are added locally.

Everything else here - the skill, the scanner, the pattern lists, the language
files - is dedicated to the public domain under the same terms. See `LICENSE`.

Authors: Matthias Georg Eckermann (mge1512), with Claude (Anthropic) as co-author.

CC0 removes the obligation to give credit. Credit is given here anyway, and anyone
reusing this is asked, not required, to do the same.
