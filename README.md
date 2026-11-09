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
uv run html5validator index.html consulting.html research.html about.html \
  resume.html documentation.html segmentation/index.html lucien.html
```

`pytest` checks page structure, internal links, mobile layout, and the generated
resume PDF with Playwright.

## Résumé

The web résumé lives in `resume.html`. Rebuild the printable PDF after editing
it:

```sh
uv run python scripts/build_resume_pdf.py
```

## Site layout

- `index.html` — two-path home: evaluation/audit consulting and research
- `consulting.html` — evaluation and audit services
- `research.html` — research hub: language science, applied systems, and selected publications
- `about.html` — longer bio and personal material
- `resume.html` / `resume.pdf` — current résumé
- `documentation.html` — research archive, including language documentation data
- `segmentation/index.html` — discourse segmentation research
- `lucien.html` — redirect retained for old inbound links
- `prototype/` — design reference, marked `noindex`
- `CV20xx.pdf` — historical academic CVs

## Design

The live pages use a paper-and-ink editorial system: warm paper, dark ink, moss
and rust accents, Alegreya for display, Karla for body and labels, and Caveat for
marginalia. Fonts and the paper-grain texture are self-hosted under `assets/`.
The blog is linked from the footer RSS mark rather than the primary navigation.
