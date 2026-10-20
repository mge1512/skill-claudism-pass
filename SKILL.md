---
name: claudism-pass
description: Remove AI-writing tells ("Claudisms") from ENGLISH text and write in a register that suits fluent non-native readers. Use whenever an English deliverable is drafted, rewritten or reviewed: article, blog or LinkedIn post, mail, README, documentation, abstract, talk proposal, slide text, customer-facing copy. Apply before delivering longer English text, even unasked. Also on request: "Claudism pass", "AI tells". NOT for German, code, diffs, config, logs or short chat replies.
---

# Claudism pass

A banlist of AI-writing tells plus a register that fits the audience. Two jobs: keep the tells out while drafting, and catch the rest before delivery.

## Scope

Apply to English text meant to be read by someone else: articles, blog and LinkedIn posts, mails, documentation, README files, abstracts, talk proposals, slide text, customer-facing material, marketing copy.

Do not apply to:

- **German text.** The banlist is calibrated for English idiom. Do not translate the entries into German equivalents and do not police German drafts with it. German has its own tells; that is a separate problem for a separate day.
- Code, diffs, configuration, command output, log excerpts, package names, commit messages.
- Quoted third-party text. Quotes stay verbatim, even when they contain banned wording. Say in the report that the hit sits inside a quote.
- Short conversational replies in chat, unless the user asks for the pass explicitly.

In a mixed-language document, apply it to the English parts only.

## Audience

The author writes English as a second language. The readers are technical: engineers, architects, IT decision makers, partners, analysts. Most of them also read English as a second language, all of them fluent, most of them skimming under time pressure.

That audience decides the register:

- Prefer common words over rare ones. "use" over "leverage", "start" over "commence", "so" over "hence".
- One idea per sentence. Long subordinate chains are exactly what a second-language reader parses slowest.
- Say the thing literally. Metaphor, idiom and cultural reference are the slowest part of English for a non-native reader, and they are also most of what the banlist forbids. The two rules pull in the same direction, which is why the result reads plainer rather than duller.
- Keep terminology constant. Use the same word for the same thing every time. Elegant variation ("the image", "the artifact", "the payload" for one object) costs the reader more than the repetition does.
- Cut sports, war, poker and film metaphors outright: "we've seen this movie before", "the whole ballgame", "the tell", "moving the needle", "hits hardest".
- Prefer a plain verb to a phrasal verb where one exists: "meet" over "come along with", "found" over "bumped into", "focus on" over "lean into".
- Expand an abbreviation at first use in a document for a wide audience. A reader who guesses wrong stops reading. In a mail to peers, expand only what that reader may not know; explaining a term to someone who uses it daily reads as unreviewed machine text.

None of this licenses simplified or broken English. The grammar, spelling and punctuation stay correct throughout. Plain and correct, not simplified.

### Variant switch

Two variants, selected per document. Resolve in this order and stop at the first hit:

1. **What the user says at invocation.** "Claudism pass EU", "Claudism pass US", "British spelling for this one".
2. **A marker in the file.** A line containing `variant: eu` or `variant: us`, in whatever comment syntax the format uses: `<!-- variant: eu -->` in Markdown or HTML, `% variant: eu` in LaTeX, `# variant: eu` in a plain text or YAML header. The choice then travels with the document instead of depending on anyone remembering it.
3. **Detection from the content.** Choose EU when the text is about EU legislation or schemes (Cyber Resilience Act, NIS2, DORA, eIDAS, AI Act, certification schemes), is addressed to an EU institution or agency, uses tender or procurement language, or targets a British customer or publication.
4. **Default: US.**

State the chosen variant in the first line of the report, every time. A wrong choice then costs one word of correction rather than a re-read.

**US mode** (the default): color, initialize, license as noun and verb, catalog, analyze, center, behavior, defense, program.

The reason for the default is collision, not popularity. The technical vocabulary inside the same sentence is already American: `--no-color`, `initialize()`, `serialize`, `text-align: center`, RFC and POSIX wording, and the style guides of Microsoft, Google, IBM and Red Hat. British prose around American identifiers produces "initialise the `initialize()` method", which reads as carelessness rather than as a choice.

**EU mode**: `-ise` endings, colour, centre, defence, licence as noun and license as verb, "programme" for everything except a computer program, "per cent", "judgment" in legal contexts and "judgement" elsewhere, and the institutional vocabulary of the body being addressed (Member State, the Commission, the Agency). The European Commission English Style Guide (8th edition, updated August 2026) is the reference, with one deliberate exception: the guide prescribes curly single quotation marks (2.29), and this skill keeps straight double quotes in both modes. The guide is house style for the Commission's own authors and translators. If a contracting authority requires it, follow it and record the decorative-punctuation hits as deliberate keeps.

**What the switch controls**: spelling family, quotation punctuation placement, the thousands separator, and institutional vocabulary in EU texts. Nothing else. Dates, clock, decimal separator, units and the whole banlist stay identical in both modes, which is what makes the switch safe to flip late in a draft.

**In both modes**:

- One variant per document, never mixed. If the draft mixes them, report which one was chosen and how many changes it took.
- Quoted text, identifiers, file names, command output, product names and titles of legislation keep their original spelling. An EU regulation quoted inside a US document is not a mixture; say so in the report so it does not look like a miss.
- Punctuation goes outside a quoted literal. A period inside `"systemctl reload"` breaks the command, so logical placement wins over the American convention even in US mode. In running prose that quotes no literal, follow the mode.

### Numbers, dates, units

Identical in both variants, except the thousands separator. These cost more with an international readership than any spelling variant, and German habits collide with English ones:

- Dates in ISO 8601: 2026-08-18. Never `08/18/2026` and never `18.08.2026`, which are read differently on either side of the Atlantic. A spelled-out month (18 August 2026) is acceptable in running prose, and it is what the Commission uses there; a numeric date is always ISO. Official Journal citations keep their published form (OJ L 119, 4.5.2016, p. 1); the scanner skips their dates.
- 24-hour clock with two digits for the hour, and name the time zone (CET, CEST, UTC) whenever a time appears. 09:30 CET, 14:30 CEST, never 2:30 pm.
- Decimal separator is a point: 3.5 for drei Komma fünf. Thousands separator: a comma or a space in US mode (1,000 or 1 000); in EU mode a space, preferably a no-break space, also in four-digit numbers (3 000), as the Commission prescribes. In EU mode the scanner lists a no-break space next to a figure for checking and does not count it. German `1.000` reads as one.
- Percent sign closed up: 25%. Where the word is needed, "percent" in US mode and "per cent" in EU mode.
- Milliarde is billion (10^9); German Billion is trillion (10^12).
- Space between number and unit: 4 GB, 25 ms, 10 Gbit/s. Binary prefixes where they are meant: GiB, MiB.

## Drafting

Prevention beats repair. While writing, keep off the four constructions that produce most hits:

1. **Crowned superlatives and false singularity.** "the one that ...", "the whole X", "the only X that ...", "where it helps most". If order genuinely matters, give the reason instead of the crown.
2. **Negative parallelism.** "not just X, it's Y", "This isn't about X. It's about Y.", "No X. No Y. Just Z." Cited in every external reference on AI writing. Banned in all wordings.
3. **Announcing instead of delivering.** "Here's where it gets interesting", "Let's break it down", "I'm going to make three points", "It's worth noting that". Deliver the point; the announcement adds nothing.
4. **Value-claim filler.** "this matters", "worth considering", "the right way", "the useful thing here". Telling the reader what to value before they decided. Let the substance make the case.

Also keep off placement and agency metaphors ("shape", "lives", "holds", "carries", "moves", "points", "hands you", "vouches for", "the engine", "doing the work") and off hype adjectives ("robust", "seamless", "transformative", "comprehensive", "holistic", "cutting-edge").

Rewrite an em dash rather than swapping in another character. A comma, a full stop, parentheses or two sentences usually fit; keep " - " for the rare aside. One substitute in every slot keeps the habit, and the simple-english skill counts a spaced hyphen between two statements as a dash.

## The pass

Run this over the finished draft as a separate step. Drafting and editing compete for attention; a pass that runs while the content is still moving catches the easy hits and misses the structural ones.

### Step 1: mechanical scan

If the draft is in a file, run the scanner:

```bash
# SKILL_DIR is the directory this file sits in. Depending on the agent that is
# ~/.claude/skills/claudism-pass, .agents/skills/claudism-pass,
# ~/.gemini/skills/claudism-pass, or a path under /mnt/skills.
bash "$SKILL_DIR/scripts/scan.sh" draft.md
bash "$SKILL_DIR/scripts/scan.sh" --eu tender.md
```

The scanner also reports leaked scaffolding: citation and tool-call tokens, prompt-format tags, stamped URL parameters and chatbot boilerplate ("As an AI language model", knowledge-cutoff disclaimers, compliance openers). These convict where a style tell only suggests, and the token is pure noise, so a hit is always a removal. Tokens inside code spans are ignored, so a document that documents them stays clean.

The scanner also reports invisible characters: zero-width spaces and joiners, bidi controls, byte order marks, soft hyphens, non-breaking and exotic spaces, and their HTML entity spellings. None of these have a use in a plain-text technical document, and none show up in an editor, so a hit is always a paste artifact and always gets removed. Some are reported but never counted, because removing them corrupts the text: the zero-width joiner and non-joiner (Arabic and Indic shaping, emoji sequences), the left-to-right, right-to-left and Arabic letter marks (mixed-direction text), and the variation selectors U+FE00 to U+FE0E (CJK and emoji). In EU mode a no-break space next to a figure (3 000, EUR 15 000) is the Commission's prescribed form, so it is listed for checking and not counted either.

Without a flag the scanner reads a `variant:` marker in the file, and falls back
to a tally of the spellings it finds. `--us` and `--eu` override both and list
every word that needs converting. It also checks dates, clock, decimal separator,
unit spacing, and second-language interference; `--no-l1` skips the last one.

Hits are reported by the line the paragraph starts on. Every hit needs a decision: rewrite it, or record it in the report as a deliberate keep with the reason.

If the draft is not yet in a file, write it to a temporary file and scan that.

If the draft is in the conversation rather than a file, skip to step 2 and do the literal check by reading.

### Step 2: read for the constructions a scanner cannot see

A text search matches literal strings. The same move with a different noun or verb in the slot reads identically and slips past. Check these by eye, section by section:

- Crowned superlatives with a novel noun: "the layer that pays off most", "the argument that lands hardest".
- "the whole [X]" and "the only [X] that [verb]" with any noun in the slot.
- Negative parallelism and staccato negation in any wording, including the reversed "Y rather than X" and hedges such as "should be read as a summary rather than a verdict".
- Section announcers and staged epiphany: any sentence that promises an insight instead of stating it.
- Preemptive defense: any sentence answering an objection nobody raised ("That is not a turf claim", "rather than pretending otherwise"). Delete it and check whether anything was lost; usually the sentence before it already carried the argument.
- The trailing moral: a fact followed by a clause explaining why the reader should approve of it ("..., because a judgment call is not a gate", "..., which keeps the floor honest"). State the fact and stop.
- Discovery-arc framing: "I didn't set out to ..., but", "what I didn't expect to find".
- Invented observations: "most people I've talked to", "everyone I've worked with". If the conversation or the source material does not contain it, it did not happen and cannot go in.
- Invented reactions: "it stuck with me", "the thing that got me". Name the actual reaction or leave it out.
- "Bold term: explanation sentence" bullet lists, `---` as a section divider, and a neat bullet summary at the end.
- Four or more short declarative sentences in a row. Vary the length.
- Triplets by reflex: three adjectives, phrases or examples where the content has two or four.
- Headings: Title Case where the house style is sentence case, a first heading that repeats the title, a heading with only sub-headings under it, skipped levels, and "X and Y" headings such as "Challenges and Outlook".
- Boldface on every mention of a term, a small table that a sentence would say better, and Markdown (`**`, `##`, `---`) pasted into a plain-text target such as a LinkedIn post or a text mail.
- "Little-known, yet important": the text admits that the subject is minor, then stresses its importance anyway.
- A trailing participle clause that adds an evaluation or a consequence ("..., paving the way for ...") with a verb the scanner does not list.
- Contrast definitions and importance flags in new wordings: "less a policy than a habit", "this is what decides it".
- An echo of a prompt the reader never saw: "the text", "the passage", "the document you shared".
- The symmetric closer: a last line with a balanced, philosophical cadence that nobody uses in speech.
- A sentence that could have come from anyone. Rewrite it with the specific fact, or cut it.
- Every number, quote and reference in the draft has a source that someone checked.

Consult `references/banlist.md` for the full list with the reasoning behind each entry, and to check anything that looks borderline. The file is grouped into confirmed entries, structural and framing tics, register tics, spoken-word tells, imported vocabulary, and local additions caught in review.

### Step 3: report

Append a short report under the delivered text. The report is editor metadata, so the banlist does not apply to it.

```
## Claudism pass
- variant: US (default; no EU trigger in this text)
- "leverage the build service" -> "use the build service" (corporate verb)
- section 2 crowned one option as the best -> gave the reason instead of the ranking
- 3 em dashes -> 2 commas, 1 full stop
- FLAG: "attack surface" kept, term of art, not the banned verb use
- FLAG: "eventually" in paragraph 4 - if "possibly" was meant, this says the opposite
```

One line per hit. If unsure whether something counts, flag it rather than guessing or silently rewriting. If the draft came back clean, say so in one line.

When the simple-english skill is active in the same session, its reply rules flag headings and bullets in chat. Then write the report as plain lines: first "Claudism pass (variant: US, default)", then one change per line, without a heading or bullets.

## Carve-outs

Several banned words are terms of art in IT. Leave them alone in their technical sense and note the keep in the report if it might look like a miss:

| Banned as | Keeps its meaning as |
| --- | --- |
| "surface" (verb) | attack surface, surface area |
| "harness" (verb) | test harness |
| "realm" (filler) | Kerberos realm, PAM realm, `realmd` |
| "compound" (growth metaphor) | chemical compound, compound key |
| "landscape" (figurative) | an established industry term such as SAP system landscape |
| "physics" (metaphor) | actual physics |
| "shape" (metaphor) | array shape, reshape |
| "real" (adjective) | real mode, real user ID, real time as a technical property |
| "load-bearing" (metaphor) | an actual wall |
| "points" (directional metaphor) | a pointer, symlink, DNS record or reference that points to a target |
| "moves" (abstract motion) | a literal move: a file, a service, data to another host |
| "underscore" (verb) | the `_` character, as in `snake_case` names |

"Robust" and "seamless" have no technical carve-out. Replace them with the measurable claim: "survives a node failure without data loss", "no manual step between build and deployment".

## First-language interference

Writers carry habits from their first language into English. These are separate from the Claudism list, they are invisible to the writer, and they cost credibility with exactly the readers the text is written for.

`references/l1/common.md` covers what nearly every European first language produces: "eventually" and "actual" as false friends, plural "informations", "since three years", "how does it look like", and "must not" used where "does not have to" was meant. Read it on every pass.

Then read the file for the writer's first language:

| First language | File |
| --- | --- |
| German | `references/l1/german.md` |
| Czech, Slovak, Polish | `references/l1/czech.md` |
| Dutch | `references/l1/dutch.md` |
| French | `references/l1/french.md` |
| Spanish, Portuguese | `references/l1/spanish.md` |
| Italian | `references/l1/italian.md` |
| Greek | `references/l1/greek.md` |

### Selecting the language

Same precedence as the variant switch, first hit wins:

1. **What the user says.** "my first language is Czech", "Claudism pass, L1 German".
2. **A marker in the file.** `<!-- l1: cs -->`, `% l1: fr`, `# l1: de`. Codes are ISO 639-1: de, cs, nl, fr, es, it, el.
3. **Detection from the draft.** The interference patterns are themselves diagnostic: missing articles point to Czech, Polish or Greek; "globally" for "roughly" points to Dutch; "delay" for "lead time" points to French; "argument" for "topic" points to Italian.
4. **No selection.** Apply `common.md` only.

### How to report it

Report what was fixed, not who the writer is. Write "missing article before 'build service'", never "Czech interference" or "your English reads Slavic". Detection is a guess and guessing at someone's nationality in an editing report is both rude and often wrong. Name the first language only when the writer named it.

Correct these in the text and list them in the report, so the same one does not come back next time. Never imitate them, and never introduce one for authenticity.

## Provenance

`references/banlist.md` is a living list of AI-writing tells, cross-checked against public references on the subject. When a new tell gets flagged in conversation, offer to add it there rather than keeping it in the chat only. The same applies to the language files: a false friend caught in review belongs in `references/l1/`.
