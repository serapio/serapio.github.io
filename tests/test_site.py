import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

import pytest
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parent.parent

PAGES = [
    "index.html",
    "lucien.html",
    "research.html",
    "resume.html",
    "documentation.html",
    "segmentation/index.html",
]


def resolve_target(source: Path, href: str) -> Path:
    path = unquote(urlsplit(href).path)
    if not path:
        return source
    target = (source.parent / path).resolve()
    if href.endswith("/") or target.is_dir():
        return target / "index.html"
    return target


def ids_for(path: Path) -> set[str]:
    soup = BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser")
    return {element["id"] for element in soup.select("[id]")}


@pytest.mark.parametrize("page_name", PAGES)
def test_page_has_title_and_main(page, page_name):
    page.goto((ROOT / page_name).as_uri())
    assert page.title()
    assert page.locator("main").count() == 1


@pytest.mark.parametrize("page_name", PAGES)
def test_page_has_one_h1_and_site_chrome(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    assert len(soup.select("h1")) == 1, f"{page_name}: expected exactly one h1"
    assert soup.select_one("header.masthead") is not None
    assert soup.select_one("footer.footer") is not None


@pytest.mark.parametrize("page_name", PAGES)
def test_links_and_images_resolve(page_name):
    source = ROOT / page_name
    soup = BeautifulSoup(source.read_text(encoding="utf-8"), "html.parser")

    for anchor in soup.select("a[href]"):
        href = anchor["href"].strip()
        if not href or href.startswith(("mailto:", "http://", "https://", "data:")):
            continue

        target = resolve_target(source, href)
        assert target.exists(), f"{page_name}: missing target for {href}"

        fragment = urlsplit(href).fragment
        if fragment and target.suffix == ".html":
            assert fragment in ids_for(target), (
                f"{page_name}: missing anchor #{fragment} in {target.name}"
            )

    for image in soup.select("img[src]"):
        src = image["src"].strip()
        if src.startswith(("data:", "http://", "https://")):
            continue
        assert (source.parent / unquote(src)).resolve().exists(), (
            f"{page_name}: missing image {src}"
        )


def test_home_links_to_research():
    soup = BeautifulSoup((ROOT / "index.html").read_text(encoding="utf-8"), "html.parser")
    hrefs = {anchor.get("href") for anchor in soup.select("a[href]")}
    assert "research.html" in hrefs
    assert "lucien.html" in hrefs


def test_profile_links_to_the_work():
    soup = BeautifulSoup((ROOT / "lucien.html").read_text(encoding="utf-8"), "html.parser")
    hrefs = {anchor.get("href") for anchor in soup.select("a[href]")}
    assert "index.html" in hrefs
    assert "research.html" in hrefs
    assert "resume.html" in hrefs


@pytest.mark.parametrize("page_name", PAGES)
def test_mobile_layout_has_no_horizontal_scroll(page, page_name):
    page.set_viewport_size({"width": 390, "height": 844})
    page.goto((ROOT / page_name).as_uri())
    scroll_width = page.evaluate("document.documentElement.scrollWidth")
    client_width = page.evaluate("document.documentElement.clientWidth")
    assert scroll_width <= client_width, f"{page_name}: horizontal overflow"


def test_profile_page_is_indexed_content():
    soup = BeautifulSoup((ROOT / "lucien.html").read_text(encoding="utf-8"), "html.parser")
    assert soup.find("meta", attrs={"http-equiv": "refresh"}) is None
    robots = soup.find("meta", attrs={"name": "robots"})
    assert robots is None or "noindex" not in (robots.get("content") or "")


def test_resume_prints_to_pdf():
    assert (ROOT / "resume.pdf").stat().st_size > 10_000


def test_resume_pdf_matches_current_content():
    from pypdf import PdfReader

    soup = BeautifulSoup(
        (ROOT / "resume.html").read_text(encoding="utf-8"), "html.parser"
    )
    headings = [h.get_text(" ", strip=True) for h in soup.select("h2")]
    assert headings, "resume.html: no h2 headings to canary against"

    pdf_text = " ".join(
        page.extract_text() or "" for page in PdfReader(ROOT / "resume.pdf").pages
    )
    pdf_text = " ".join(pdf_text.split()).casefold()
    missing = [
        h
        for h in headings
        if " ".join(h.split()).casefold() not in pdf_text
    ]
    assert not missing, f"resume.pdf is stale; missing: {missing}"


CHROME_FRAGMENTS = [
    "Alameda County, CA · 2026",
    "© 2026 Lucien Carroll",
    "Static HTML and CSS, written via Kilo Code with",
]


@pytest.mark.parametrize("page_name", PAGES)
def test_site_chrome_is_consistent(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    text = " ".join(soup.get_text(" ", strip=True).split())
    for fragment in CHROME_FRAGMENTS:
        assert fragment in text, f"{page_name}: missing chrome text {fragment!r}"


@pytest.mark.parametrize("page_name", PAGES)
def test_ids_are_unique(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    ids = [element["id"] for element in soup.select("[id]")]
    duplicates = {i for i in ids if ids.count(i) > 1}
    assert not duplicates, f"{page_name}: duplicate ids {duplicates}"


def test_css_classes_are_used():
    css = (ROOT / "assets" / "site.css").read_text(encoding="utf-8")
    classes = set(re.findall(r"\.([a-zA-Z][a-zA-Z0-9_-]*)", css))
    html = " ".join(
        (ROOT / name).read_text(encoding="utf-8")
        for name in [*PAGES, "prototype/style-tile.html"]
    )
    unused = sorted(c for c in classes if c not in html)
    assert not unused, f"site.css: unused class selectors {unused}"


@pytest.mark.parametrize("page_name", PAGES)
def test_images_have_alt_text(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    for image in soup.select("img"):
        assert image.get("alt", "").strip(), (
            f"{page_name}: img missing alt text ({image.get('src')})"
        )


@pytest.mark.parametrize("page_name", PAGES)
def test_aria_references_resolve(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    page_ids = ids_for(ROOT / page_name)
    for attribute in ("aria-labelledby", "aria-describedby"):
        for element in soup.select(f"[{attribute}]"):
            for target in element[attribute].split():
                assert target in page_ids, (
                    f"{page_name}: {attribute} points at missing id {target!r}"
                )
