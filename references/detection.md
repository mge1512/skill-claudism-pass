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
  over-represented in machine text and still far too common in human prose. The
  distinctive tail carries the weight: `delve`, `tapestry`, `testament`,
  `multifaceted`.
- **Version the lists.** `references/VERSION` stamps them, the ratchet baseline
  records the stamp, and the scanner says so when they differ. Counts move when
  the lists change, and an unversioned stored verdict goes stale without saying
  so.

## Attribution leans

Different models over-use different words, which is what makes attribution
possible at all. `camaraderie` and `palpable` run far above the human rate in
GPT-4o output; `a multi-pronged approach` and
`However, it is crucial to acknowledge` lean Gemini; full-width CJK punctuation glued into Latin prose is
tokeniser residue. Formatting habits separate model families better than
vocabulary does: the bold enumeration label is a ChatGPT habit specifically.

Treat all of this as a lean and never as proof.

## Sources to track

- Wikipedia, "Signs of AI writing", actively maintained.
- Reinhart et al., PNAS 2025, per-model lexical fingerprints.
- The ICML 2025 idiosyncrasies study, formatting habits by model family.
- System-prompt and scaffolding leak collections. Each new chat product feature
  leaks a new token family within weeks, which is where `artifacts.txt` grows.
