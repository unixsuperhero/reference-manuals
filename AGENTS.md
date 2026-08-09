# Reference Manuals Repository

## Purpose

This repository stores Markdown reference manuals and deterministic, static HTML
exports. Everything must remain usable directly from disk (`file://`): do not
introduce a web server, server-side rendering, or a runtime package dependency.

## Canonical content and metadata

- `docs/**/*.md` is the canonical document collection.
- Put each document's display title and arbitrary tags in YAML front matter.
- Tags are a YAML list, are case-sensitive display values, and should be short,
  reusable nouns such as `cli`, `manpage`, or `config`.
- Every document must have at least one tag. `bin/catalog validate` enforces this.
- Keep `index.md`/`index.html` as the conventional index for now. Validation
  requires `index.md` to link every canonical document exactly by membership;
  the rebuild regenerates `index.html`. `tagged.html`
  is the generated alternative organized by tag; do not replace the conventional
  index unless that decision is made explicitly.

Example:

```yaml
---
title: Zsh Options Reference
tags:
  - manpage
  - zsh
  - cli
  - config
---
```

## Static exports

- `bin/export-doc docs/path.md` exports one document to
  `export/path.html`, preserving subdirectories.
- `bin/rebuild-export` exports every `docs/**/*.md` file and rebuilds the root
  `index.html` and `tagged.html` catalogs. A full rebuild removes old
  HTML beneath `export/` first, preventing deleted documents from leaving stale
  pages; non-HTML files are preserved.
- `tagged.md` supplies the catalog's authored introduction;
  `templates/tagged.html` supplies its layout and client-side filters.
- The generated tag cloud and filter use only embedded browser JavaScript, so
  they work without a server.
- Local Markdown links are rewritten to `.html` by
  `bin/rewrite-md-links.lua` during export.

## Repository layout

- All Pandoc templates belong in `templates/`. `templates/claude-docs.html` is
  the vendored template used by the user's `~/bin/mdoc`, adapted for this repo.
- All export helpers, filters, and other scripts belong in the root `bin/`.
- Never place a new script or Pandoc template in a user-level directory as part
  of this project.
- Generated per-document HTML belongs in `export/`; the generated catalog is
  `tagged.html` at the repository root.

## Change checklist

When adding or changing a manual, update its front matter, keep its entry in
`index.md` current, run `bin/rebuild-export`, and verify `bin/catalog validate`.
Commit source, templates, scripts, and the generated HTML together when this
repository's current convention is to track exports.
