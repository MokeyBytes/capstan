# Knowledge base

The [document home](document-home.md) holds one project's records. The knowledge base is the other thing: your own vault or notes folder, outside the repository, holding what you know across every project. At delivery the Courier writes one note there per effort, covering what the effort was, what was decided, what was rejected, and where the code and the records live. It is the only place that can answer a question spanning two projects, because no single repository can.

Set it with a key in this repository's own `CLAUDE.md` or `AGENTS.md`, the same two files the document home uses, and never a user-level file:

```markdown
capstan-knowledge-base: /Users/you/vault/Efforts
```

`setup` does not write this one. There is no default to fall back to, so leaving the key out is a complete answer. The Courier writes no note and says so in its close-out, rather than guessing a folder, because a note nobody can find again is worse than no note.

Capstan never runs git in there either. It writes the note, a Reviewer reads it at that path, and you commit it.
