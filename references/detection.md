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
possible at all. `camaraderie` and `palpable` run far above the human rate in
GPT-4o output; `a multi-pronged approach` and
`However, it is crucial to acknowledge` lean Gemini; full-width CJK punctuation glued into Latin prose is
tokeniser residue. Formatting separates model families, but less well than
vocabulary: in a five-way test, Markdown elements alone reached 73.1%
accuracy, word-shuffled text 88.9% and the full text 97.1% (Sun et al.). The
bold enumeration label is a ChatGPT habit specifically.

Treat all of this as a lean and never as proof.

## Sources to track

- Wikipedia, "Signs of AI writing", actively maintained. It describes rather
  than bans, dates its word lists by model era and lists signs of human
  writing as well.
- Reinhart et al., PNAS 2025: grammatical and lexical profiles of GPT-4o,
  GPT-4o Mini and Llama 3. No Claude model was tested.
- Sun et al., "Idiosyncrasies in Large Language Models", ICML 2025: words and
  formatting by model family, Claude 3.5 Sonnet included.
- System-prompt and scaffolding leak collections. Each new chat product feature
  leaks a new token family within weeks, which is where `artifacts.txt` grows.
