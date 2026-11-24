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
    "Static HTML and CSS, coded via",
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
    css = re.sub(r"url\([^)]*\)", "", css)
    classes = set(re.findall(r"\.([a-zA-Z][a-zA-Z0-9_-]*)", css))
    used = set()
    html_files = [*PAGES, "prototype/style-tile.html"]
    for name in html_files:
        soup = BeautifulSoup((ROOT / name).read_text(encoding="utf-8"), "html.parser")
        for element in soup.find_all(class_=True):
            used.update(element.get("class", []))
    unused = sorted(c for c in classes if c not in used)
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


PUBLISHED_EMAIL = "contact@discurs.us"
PRIVATE_EMAIL = "lucien@discurs.us"
DELETED_PAGES = ["consulting.html", "about.html"]


def test_real_email_never_published():
    for name in [*PAGES, "prototype/style-tile.html", "README.md", "resume.pdf"]:
        data = (ROOT / name).read_bytes()
        assert PRIVATE_EMAIL.encode() not in data, (
            f"{name}: real address must not be published; use {PUBLISHED_EMAIL}"
        )


@pytest.mark.parametrize("page_name", PAGES)
def test_published_email_is_alias(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    mailtos = [a["href"] for a in soup.select('a[href^="mailto:"]')]
    for href in mailtos:
        assert PRIVATE_EMAIL in href or PUBLISHED_EMAIL in href, (
            f"{page_name}: unexpected mailto {href}"
        )


@pytest.mark.parametrize("page_name", PAGES)
def test_no_links_to_deleted_pages(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    for anchor in soup.select("a[href]"):
        path = urlsplit(anchor["href"]).path
        assert not any(path.endswith(f"/{name}") or path == name for name in DELETED_PAGES), (
            f"{page_name}: links to deleted page {anchor['href']}"
        )
    text = (ROOT / page_name).read_text(encoding="utf-8")
    for name in DELETED_PAGES:
        assert f'href="{name}"' not in text, f"{page_name}: links to {name}"


@pytest.mark.parametrize("page_name", PAGES)
def test_og_tags_match_head_meta(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    title = soup.title.get_text(strip=True)
    og_title = soup.find("meta", attrs={"property": "og:title"})
    assert og_title is not None and og_title["content"] == title, (
        f"{page_name}: og:title does not match <title>"
    )
    canonical = soup.find("link", attrs={"rel": "canonical"})
    og_url = soup.find("meta", attrs={"property": "og:url"})
    if canonical and og_url:
        assert og_url["content"] == canonical["href"], (
            f"{page_name}: og:url does not match canonical"
        )


@pytest.mark.parametrize("page_name", PAGES)
def test_external_links_use_https(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    for anchor in soup.select('a[href^="http://"]'):
        assert False, f"{page_name}: insecure external link {anchor['href']}"


def test_sitemap_urls_resolve():
    import xml.etree.ElementTree as ET

    root = ET.fromstring((ROOT / "sitemap.xml").read_text(encoding="utf-8"))
    ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    locs = [e.text for e in root.findall(".//s:url/s:loc", ns)]
    assert len(locs) == len(PAGES), (
        f"sitemap has {len(locs)} urls, expected {len(PAGES)}"
    )
    for loc in locs:
        path = unquote(urlsplit(loc).path)
        target = ROOT / (path.lstrip("/") or "index.html")
        if target.is_dir():
            target = target / "index.html"
        assert target.exists(), f"sitemap lists missing page {loc}"


def test_robots_txt_policy():
    text = (ROOT / "robots.txt").read_text(encoding="utf-8")
    assert "Sitemap: https://discurs.us/sitemap.xml" in text

    # default group (web search): everything allowed
    default = text.split("User-agent: *", 1)[1].split("User-agent:", 1)[0]
    assert "Allow: /" in default
    assert "Disallow:" not in default

    # AI training crawlers: PDFs and document directories blocked
    assert "Disallow: /*.pdf$" in text
    for bot in ("GPTBot", "CCBot", "ClaudeBot", "Bytespider", "Applebot-Extended"):
        assert f"User-agent: {bot}" in text
    # AI search assistants stay allowed
    assert "User-agent: OAI-SearchBot" in text
    assert "User-agent: Perplexity-User" in text
