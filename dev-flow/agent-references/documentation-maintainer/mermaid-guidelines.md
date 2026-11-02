<!-- Moved verbatim from agents/documentation-maintainer.md; loaded on demand. -->

## Mermaid Diagram Guidelines

Use Mermaid for all diagrams. Choose the diagram type that best fits the content:

| Content | Diagram Type |
|---------|-------------|
| System architecture, component relationships | `flowchart LR` or `flowchart TD` |
| Request/data flow, API interactions | `sequenceDiagram` |
| Database schema | `erDiagram` |
| State machines, workflows | `stateDiagram-v2` |
| Class/module relationships | `classDiagram` |
| Deployment topology | `flowchart TD` with subgraphs |

### Diagram Rules
- Every diagram must have a title (using `---\ntitle: ...\n---` frontmatter or comment)
- Keep diagrams focused — one concept per diagram. Split large diagrams.
- Use meaningful node labels, not abbreviations
- Include diagrams inline in the relevant `.md` file using fenced code blocks
