# Pointing the lists the other way

This skill scrubs. The same lists can be used to judge whether a text was
machine-written, and that is a different job with different rules. These notes
come from the Lolly project (Andy Fitzsimon, SUSE), which built a detector on
top of this banlist.

## Evidence has grades

1. **Leaked scaffolding** (`references/artifacts.txt`, first sections) is
   near-certain and often names the product. A tool-call token has no other way
   into a document.
2. **Chatbot register** (same file, hard grade) proves a chat answer was pasted,
   though not which model produced it.
3. **Style** (`references/banlist.md`) is only ever a lean. Style never names a
   model, because every model trains on every other model's output, and people
   who read machine text all day drift towards its habits.

Never present grade 3 as grade 1.

## Rules that keep a detector honest

- **Density beats count.** Thresholds per 1000 words with an absolute floor, so
  long careful human prose is not punished for its length. Lolly flags em dashes
  at three or more AND at least 15 per 1000 words.
- **Abstain on short text.** Below roughly 60 words there is too little signal
  for a per-passage judgment.
- **Apply the quoted-text guard everywhere.** A style guide, a review of machine
  writing, or this file would otherwise convict itself. The scanner blanks code
  spans and quoted spans before the scaffolding check for this reason.
- **Leave the common words out.** `key`, `additionally` and `valuable` are
  over-represented in machine text and still far too common in human prose.
  Only the distinctive tail counts: `delve`, `tapestry`, `testament`,
  `multifaceted`. Even that tail dates: Wikipedia's "Signs of AI writing" lists
  the first three for 2023 to mid-2024 output and `multifaceted` for GPT-6
  output from mid-2026. Date every lean.
- **Version the lists.** `references/VERSION` stamps them, the ratchet baseline
  records the stamp, and the scanner says so when they differ. Counts move when
  the lists change, and an unversioned stored verdict goes stale without saying
  so.

## Not evidence of machine origin

The register rules are not. Wikipedia's "Signs of AI writing" (October 2026)
lists "in order to", "the fact that", "as a result of", "is the only" and "was
the first" among the constructions that are more common in human Wikipedia
text than in AI text. In 4.3 million words of human technical documentation
written before 2023, "in order to" occurs 236 times per million words, "prior
to" 65, "allows users to" and its variants 40, "here," 34 and "utilize" 31.
Leave the ASD-STE100 block and the "here," rule out of any detection score:
they enforce a register.

Curly quotes are not, least of all from Claude. ChatGPT and DeepSeek typically
emit them, Claude and Gemini typically do not, and Word, macOS, iOS and
LanguageTool produce them on their own (Wikipedia, October 2026). The scanner
counts them as house style.

## Attribution leans

Different models over-use different words, which is what makes attribution
possible at all. Record the model version with every lean, because the leans
change between versions: between the two latest versions of one model family,
55 to 72% of the tells differ (Graphite).

Claude 3.5 Sonnet (2024) answered questions about a pasted source with
"according to the text" and "based on the text", and most of its answers had
no bold text and no headers (Sun et al.). Claude Opus 5 (2026) over-used "is
genuinely", "less like a ... and more like", "rather than merely" and
"enormously". Opus 5.5 dropped most of that set and nearly all em dashes, and
uses "this matters", "why ... matters", "looking ahead" and "what comes next"
instead (Graphite, 2026); Pangram measured "genuinely" 83% lower in Opus 5.5
than in Opus 5. GPT-6 Astra uses "matters because" even more often, so that
phrase marks machine text in general.

"camaraderie" runs about 160 times the human rate in GPT-4o output and about
23 times in Llama 3 Instruct. "palpable" is shared (GPT-4o 95, GPT-4o Mini
145, Llama 3 Instruct 47 to 48), so it marks instruction tuning rather than
GPT (Reinhart et al.). By July 2025, 70% of GPT-4o messages contained an
emoji; the white heavy check mark ran at 11 times, the brain and the small
blue diamond at 10 times the human rate (Washington Post). Gemini 3.1 Pro
over-uses intensifiers: "ultimately this" 78, "absolutely essential" 32,
"profound" 25, "immense" 22, "remarkably" 19 and "incredibly" 18 times the
human rate (Graphite; one study). `a multi-pronged approach` and
`However, it is crucial to acknowledge` lean Gemini according to the Lolly
notes; none of the published sources checked in October 2026 confirms them.
Full-width CJK punctuation glued into Latin prose is tokenizer residue.

Formatting separates model families, but less well than vocabulary: in a
five-way test, Markdown elements alone reached 73.1% accuracy, word-shuffled
text 88.9% and the full text 97.1% (Sun et al.). The bold enumeration label is
a ChatGPT habit specifically.

The em dash no longer separates current models from people. GPT-4o put one in
more than half of its responses by summer 2025 (Washington Post). In 2026,
Claude Opus 5 used it at about the human rate, Opus 5.5 at 0.015 per 1000
words, GPT-6 Astra at about one eighth of the human rate and Gemini 3.1 Pro
almost never (Graphite). Wikipedia's page dates the sign from 2022 to
September 2026, reports newer models that avoid the dash altogether, and
cites a July 2026 study in which Claude was the only current model to use
more em dashes than professional writers. A text without em dashes says
nothing about its author.

Word leans decay once they are publicized. "delves" ran at about 40 times its
expected rate in PubMed abstracts in 2024 and at 8 times by mid-2025 (Kobak et
al.); "delve" fell from 4.9% to 2.1% of MDPI papers between 2024 and 2025,
while the "underscore" family kept rising (Thelwall and Kousha).

Grammar also separates instruction-tuned models from people: GPT-4o writes
present participial clauses at 5.3 times and nominalizations at 2.1 times the
human rate, and agentless passives at half of it (Reinhart et al.). Claude was
not tested. Noun-heavy style is also a German and French first-language habit
(`references/l1/`), so it is not evidence on its own.

Treat all of this as a lean and never as proof.

## Vendor watermarks

Anthropic has signed the Code of Practice for Article 50(2) of the EU AI Act.
Claude models launched in the EU from 2026-08-02 mark their text output, and
earlier models follow within the law's transition period. According to
Anthropic, the mark is part of the text, travels with copy and paste and may
survive some editing. How it is made, and how third parties will detect it,
has not been published (https://support.claude.com/en/articles/16266773,
checked 2026-10-20). The mark is a separate grade of evidence, and this scanner
does not look for it.

## Sources to track

- Wikipedia, "Signs of AI writing", actively maintained. It describes rather
  than bans, dates its word lists by model era and lists signs of human
  writing as well.
- Reinhart et al., PNAS 2025: grammatical and lexical profiles of GPT-4o,
  GPT-4o Mini and Llama 3. No Claude model was tested.
- Sun et al., "Idiosyncrasies in Large Language Models", ICML 2025: words and
  formatting by model family, Claude 3.5 Sonnet included.
- Graphite, "AI Tells" (2026-09-16) and "AI Tells: Opus 5.5 Update"
  (2026-10-01): tells per model against 10,000 human articles from before
  ChatGPT. A vendor study, not peer-reviewed.
- Pangram's posts on new model versions: comparisons between versions, without
  a human baseline.
- Kobak et al., Science Advances 2025, with the data to recompute the excess
  ratios at https://github.com/berenslab/llm-excess-vocab.
- The slop-score leaderboard of the Antislop project (arXiv 2510.15061):
  over-represented phrases per model.
- System-prompt and scaffolding leak collections. Each new chat product feature
  leaks a new token family within weeks, which is where `artifacts.txt` grows.
