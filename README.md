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
git clone https://github.com/mge1512/skill-claudism-pass.git ~/.claude/skills/claudism-pass
```

The target directory has to be `claudism-pass`, matching the skill name, not
`skill-claudism-pass` as the repository is called. Pull in place to update:

```bash
git -C ~/.claude/skills/claudism-pass pull
```

Use `.claude/skills/claudism-pass` inside a repository instead if the skill should
be available in that project only. Start a new session afterwards; `/skills` lists
what was picked up. The layout must be `claudism-pass/SKILL.md`, with no extra
folder in between.

**Claude.ai and the desktop app**

Settings, then the skills section, then add a custom skill and upload the packaged
`claudism-pass.skill` file from the releases page. Current steps are at
https://support.claude.com if the menu has moved.

**Antigravity CLI (`agy`) and the Antigravity IDE**

```bash
# per workspace, recognised by every Antigravity surface
git clone https://github.com/mge1512/skill-claudism-pass.git \
    .agents/skills/claudism-pass

# global
git clone https://github.com/mge1512/skill-claudism-pass.git \
    ~/.gemini/config/skills/claudism-pass
```

Antigravity comes in three flavours (`agy`, the CLI and the IDE) and they do not
search the same global locations. The workspace path is the one all of them agree
on, and it travels with the repository, so prefer it. Run `/skills` in a session
to see which locations the installed version reads; the published
documentation has been behind the binary.

**Gemini CLI**

```bash
git clone https://github.com/mge1512/skill-claudism-pass.git \
    ~/.gemini/skills/claudism-pass
```

Per project, use `.gemini/skills/claudism-pass`. Gemini CLI stopped serving the
free and individual tiers on 2026-06-18; it needs a Gemini Code Assist Standard or
Enterprise license, or a paid API key.

**KIT (Knowledge Inference Tool)**

```bash
git clone https://github.com/mge1512/skill-claudism-pass.git \
    ~/.config/kit/skills/claudism-pass
```

Point KIT at it in `~/.kit.yml`:

```yaml
skill:
  - ~/.config/kit/skills/claudism-pass
```

Or per invocation: `kit --skill ~/.config/kit/skills/claudism-pass`. An explicit
`skill:` list switches off auto-discovery, so list every skill you use, or set
`skills-dir:` to scan a directory of them instead. KIT also discovers skills on
its own; its documented cross-client convention for named agents is
`.agents/agents/`, so a project-level clone into `.agents/skills/claudism-pass`
should be found too, though the README does not state the skill paths. Check
with `/skill:claudism-pass` in a session.

**Anything else that reads SKILL.md**

The skill is a plain directory in the Agent Skills format, so copy it wherever the
agent looks. `.agents/skills/<name>/` is becoming the shared project-level
convention across tools.

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

Requirements: bash and grep. GNU grep is used when present, including Homebrew's
`ggrep`. macOS ships the BSD grep, which has neither PCRE (`-P`) nor GNU word
boundaries; the scanner detects this and takes a portable path that produces the
same report, with a coarser emoji match. `brew install grep` restores the full
set. `SCAN_FORCE_POSIX=1` exercises the portable path on a GNU system. The script
only reads; it writes nothing outside `/tmp`.

## Comments in source files

Comments are prose that people read, so the same rules apply to them. `--comments`
runs the checks over the comment text only, leaving code, strings and command
output untouched.

```bash
scan.sh --comments engine/*.go scripts/*.sh
```

The comment text is extracted by `scripts/comments.awk`, a state machine in POSIX
awk: it tracks strings and escapes, so a `//` inside a URL or a `#` inside
`${#var}` is not mistaken for a comment, and a quote inside a comment does not
confuse it. Comment syntax is chosen by file extension. Line numbers survive, so
a hit still points at the right line of the original.

The limit is the one no lexer can solve without the grammar of the language: in
JavaScript and TypeScript a `/` may open a regular expression or divide, and a
quote inside a regex can throw the string tracking off. The scanner warns on those
extensions rather than pretending otherwise. If the language has a real parser
available, use it.

## Leaked scaffolding

Copying out of a chat window brings more than prose with it. Citation tokens,
tool-call markers, prompt-format tags and stamped URL parameters survive the
paste and are pure noise, so the scanner always reports them:

```
--- leaked scaffolding and chatbot boilerplate
  line 1   Certainly! Here's      [^(Sure|Certainly|Absolutely|Of course)[!,.] ...]
  line 3   As an AI               [[Aa]s an? (AI|artificial intelligence|...)]
  line 6   contentReference[oaicite
  line 7   utm_source=chatgpt.com
```

`references/artifacts.txt` carries these. Two calibration rules keep them from
firing on honest text: a line-start `Assistant:` counts only when a line-start
`Human:` appears too, since film credits and staff rosters use it; and
self-identification strings convict only outside quotation marks, since an
article quoting a chatbot is a human writing about a machine. Tokens inside code
spans are ignored, so a document that documents these tokens stays clean.

## Using it as a gate

The scanner is deterministic: character and substring matching, no model in the
loop. That makes it usable in CI, where guidance in a document binds only the
person who reads it.

```bash
scan.sh --gate docs/*.md          # exit 1 if anything unambiguous is found
```

The gate counts banlist phrases, hidden characters, decorative punctuation,
structural tics and interference that is wrong in any register. Loose hits and
false friends never fail a build, because a judgment call is not a gate.

An existing docs tree will fail on day one, so there is a ratchet: a per-file
count that can only go down.

```bash
scan.sh --write-baseline=.claudism-baseline docs/*.md   # record the floor
scan.sh --baseline=.claudism-baseline docs/*.md         # exit 1 on drift
```

It fails three ways. A file that got worse. A new file that is not clean. And a
file that improved without the baseline being updated, which keeps the recorded
floor honest and forces each win to be locked in.

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

The repository root is the skill directory.

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

## Repository

https://github.com/mge1512/skill-claudism-pass

## Detection

`references/detection.md` covers the other direction: what changes when the same
lists are used to judge whether a text was machine-written rather than to clean
it up. Short version, evidence has grades, density beats count, and style alone
never names a model.

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

The leaked-scaffolding list, the chatbot-register patterns, the detection notes
and several corrections to the variant pairs and the invisible-character list
come from the Lolly project (Andy Fitzsimon, SUSE), contributed under CC0 1.0.

CC0 removes the obligation to give credit. Credit is given here anyway, and anyone
reusing this is asked, not required, to do the same.
