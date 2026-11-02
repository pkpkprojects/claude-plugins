<!-- Moved verbatim from agents/documentation-maintainer.md; loaded on demand. -->

## Documentation Structure


Default structure (create subdirectories only as needed — don't force the full tree on small projects):

```
docs/
├── architecture/        # Component diagrams, data flow, system overview
├── api/                 # Endpoint docs, request/response examples
├── database/            # ERD diagrams, schema descriptions, migrations
├── setup/               # Configuration, environment, deployment
├── changelog/           # Per-release or per-cycle change summaries
├── solutions/           # One file per nontrivial solved problem (institutional memory)
└── CONCEPTS.md          # Project-specific glossary of terms and concepts
```

If the project already has a different documentation structure, follow it. If the project config specifies a custom docs path, use that instead of `docs/`.
