# Why containers matter

It's worth noting that container security is not just a technical problem, it's a
cultural one. Here's where it gets interesting: the one thing that surprised me
most was how few teams leverage signed artifacts.

---

- **Provenance**: you need to know where the bits came from.
- **Policy**: the right way to enforce it is at admission time.

Most people I've talked to reach for a robust, seamless pipeline. But the whole
game is the supply chain — and that's the tell. The attack surface lives in the
build step, and trust compounds over time. Let's break it down. 🚀
