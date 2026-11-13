# discurs.us

Personal portfolio for Lucien S. Carroll. Static HTML/CSS, served by GitHub
Pages at [discurs.us](https://discurs.us).

## Local development

The tooling is managed with [uv](https://docs.astral.sh/uv/). Python 3.12+ is
required.

```sh
uv sync
uv run playwright install chromium   # once, for browser tests and PDF build
uv run python -m http.server 8000    # preview at http://localhost:8000
```

## Checks

```sh
uv run ruff check .
uv run pytest
uv run html5validator index.html consulting.html research.html \
  resume.html documentation.html segmentation/index.html lucien.html
```

`pytest` checks page structure, one `h1` per page, internal links, anchors, and
images, unique ids, alt text and `aria` references, site chrome consistency
(masthead, location, colophon) across pages, unused CSS class selectors in
`assets/site.css`, and mobile horizontal overflow (via Playwright). The resume
PDF is checked for size and for content matching the current `resume.html`
(via `pypdf`). HTML validity is checked separately with `html5validator`.

## Résumé

The web résumé lives in `resume.html`. Rebuild the printable PDF after editing
it:

```sh
uv run python scripts/build_resume_pdf.py
```

## Site layout

- `index.html` — two-path home: evaluation/internationalization consulting and research
- `consulting.html` — evaluation, internationalization, and audit services
- `research.html` — research hub: language science, language technology, and selected publications
- `resume.html` / `resume.pdf` — current résumé
- `documentation.html` — language documentation research archive
- `segmentation/index.html` — discourse segmentation research archive
- `lucien.html` — redirect retained for old inbound links
- `prototype/style-tile.html` — style tile (palette, type, components), marked `noindex`
- `CV20xx.pdf` — historical academic CVs

## Design

The live pages use a paper-and-ink editorial system: warm paper, dark ink, moss
and rust accents, Alegreya for display, Karla for body and labels, and Caveat for
marginalia. Fonts and the paper-grain texture are self-hosted under `assets/`.
The blog is linked from the footer RSS mark rather than the primary navigation.
