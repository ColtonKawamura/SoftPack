#!/usr/bin/env python3
"""Regenerate and check the "Cited in" lists of the reference pages.

The lists drift by hand: a page gains a citation and the list of the key it
cites does not.  This script computes every list from the page texts, so the
lists cannot disagree with the pages.

What a list contains:

  wiki References.md      design doc marker, then the wiki pages that contain
                          "[Key]", in the section order of the wiki Home page,
                          then any link that is neither (kept as written, for
                          example the site's benchmark pages).
  site reference/references.md
                          design doc marker, then the site pages that contain
                          "[Key]", in nav order, then the kept links.

Usage (from anywhere; the paths default to the checkout this file lives in):

    python3 docs/scripts/citations.py            # check, exit 1 on drift
    python3 docs/scripts/citations.py --write    # rewrite the lists
    python3 docs/scripts/citations.py --wiki ../SoftPack.wiki

The wiki is a separate checkout; pass --wiki when it is not a sibling
directory of the SoftPack checkout.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

DESIGN_DOC = "https://github.com/ColtonKawamura/SoftPack/blob/main/docs/design-references.md"
WIKI_URL = "https://github.com/ColtonKawamura/SoftPack/wiki/"
NOT_PAGES = {"References", "Home", "_Sidebar", "AGENTS"}


def keys_of(text: str) -> set[str]:
    return set(re.findall(r"\[([A-Z][A-Za-z0-9_]+)\]", text))


def bib_keys(repo: Path) -> list[str]:
    text = (repo / "docs" / "references.bib").read_text(encoding="utf-8")
    return re.findall(r"^@\w+\{([^,]+),", text, flags=re.M)


def section_order(wiki: Path) -> dict[str, str]:
    """Home page: | 8 | [Damping](Damping) | ... -> {Damping: 8}."""
    order = {}
    for line in (wiki / "Home.md").read_text(encoding="utf-8").splitlines():
        m = re.match(r"\|\s*([0-9]+[a-c]?)\s*\|\s*\[[^\]]*\]\(([^)#]+)\)", line)
        if m:
            order[m.group(2)] = m.group(1)
    return order


def wiki_pages(wiki: Path) -> dict[str, str]:
    return {p.stem: p.read_text(encoding="utf-8")
            for p in sorted(wiki.glob("*.md")) if p.stem not in NOT_PAGES}


def site_pages(repo: Path) -> dict[str, str]:
    root = repo / "docs" / "src"
    out = {}
    for p in sorted(root.rglob("*.md")):
        rel = p.relative_to(root).as_posix()
        if rel.startswith("reference/references"):
            continue
        out[rel] = p.read_text(encoding="utf-8")
    return out


def title_of(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def page_label(path: str, text: str) -> str:
    """A nav-style label: the page's first heading, else the path's stem.

    An index page is labelled by its folder, which is how the nav reads
    ("pack", "benchmarks"); the site's root index is "Home".
    """
    p = Path(path)
    if p.stem == "index":
        return p.parent.name or "Home"
    t = title_of(text)
    if t and not t.startswith("`"):
        return t
    return p.stem


def order_key(label: str) -> tuple[int, str]:
    """Section order: 0, 1, ..., 7, 7a, 7b, 9, ... and unmatched last."""
    m = re.match(r"^(\d+)([a-c]?)$", label)
    if not m:
        return (99, label)
    return (int(m.group(1)), m.group(2))


def site_link(path: str) -> str:
    """The site page's URL relative to docs/src/reference/."""
    return "../" + path


def listed(line: str) -> list[tuple[str, str]]:
    """The links after 'Cited in:' as (label, url)."""
    if "Cited in:" not in line:
        return []
    return re.findall(r"\[([^\]]*)\]\(([^)]+)\)", line.split("Cited in:", 1)[1])


def suffix(pairs: list[tuple[str, str]]) -> str:
    return "Cited in: " + ", ".join(f"[{label}]({url})" for label, url in pairs) + "."


def rebuild(line: str, cited: list[tuple[str, str]], keep: list[tuple[str, str]]) -> str:
    head = line.split("Cited in:", 1)[0].rstrip().rstrip(".")
    return head + ". " + suffix(cited + keep)


def keep_links(line: str) -> list[tuple[str, str]]:
    """Links the script does not compute: anything outside this repo.

    A wiki page link and a site page path are both regenerated, so a stale one
    is dropped rather than kept.
    """
    return [(label, url) for label, url in listed(line)
            if url.startswith(("http://", "https://")) and url != DESIGN_DOC]


def check_file(path: Path, pages: dict[str, str], design: str, order: dict[str, str],
               is_wiki: bool) -> tuple[bool, list[str], list[str], str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    problems: list[str] = []
    seen: list[str] = []
    for i, line in enumerate(lines):
        m = re.match(r"- \*\*\[([A-Za-z0-9_]+)\]\*\*", line)
        if not m:
            continue
        key = m.group(1)
        seen.append(key)
        want = [p for p, t in pages.items() if f"[{key}]" in t]
        want.sort(key=lambda p: order_key(order.get(p, "")) if is_wiki else p)
        cited = []
        if f"[{key}]" in design:
            cited.append(("design doc", DESIGN_DOC))
        if is_wiki:
            for p in want:
                section = order.get(p, "")
                label = section if re.fullmatch(r"\d+[a-c]?", section) else page_label(p, pages[p])
                cited.append((label, p))
        else:
            cited += [(page_label(p, pages[p]), site_link(p)) for p in want]
        keep = keep_links(line)
        new = rebuild(line, cited, keep)
        if new != line:
            problems.append(f"{path.name}:{i + 1}  {key}\n  now: {line.strip()}\n  want: {new.strip()}")
            lines[i] = new
    corpus = " ".join(pages.values())
    missing = [k for k in bib_keys_cached if f"[{k}]" in corpus and k not in seen]
    return (not problems), problems, missing, "\n".join(lines) + "\n"


bib_keys_cached: list[str] = []


def main() -> int:
    here = Path(__file__).resolve()
    default_repo = here.parent.parent.parent
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, default=default_repo, help="SoftPack checkout")
    ap.add_argument("--wiki", type=Path, default=None, help="SoftPack.wiki checkout")
    ap.add_argument("--write", action="store_true", help="rewrite the lists in place")
    args = ap.parse_args()

    repo = args.repo.resolve()
    wiki = (args.wiki or repo.parent / "SoftPack.wiki").resolve()
    if not (wiki / "References.md").exists():
        print(f"no wiki checkout at {wiki}; pass --wiki", file=sys.stderr)
        return 2

    global bib_keys_cached
    bib_keys_cached = bib_keys(repo)
    design = (repo / "docs" / "design-references.md").read_text(encoding="utf-8")
    order = section_order(wiki)
    wpages = wiki_pages(wiki)
    spages = site_pages(repo)

    ok = True
    for path, pages, names, is_wiki in (
        (wiki / "References.md", wpages, set(wpages), True),
        (repo / "docs" / "src" / "reference" / "references.md", spages, set(spages), False),
    ):
        good, problems, missing, new = check_file(path, pages, design, order, is_wiki)
        ok &= good
        if missing:
            print(f"{path.name}: keys from references.bib with no entry: {', '.join(missing)}")
        if problems:
            for p in problems:
                print(p)
            if args.write:
                path.write_text(new, encoding="utf-8")
                print(f"rewrote {path}")
    uncited = [k for k in bib_keys_cached
               if f"[{k}]" not in " ".join(wpages.values())
               and f"[{k}]" not in " ".join(spages.values())
               and f"[{k}]" not in design]
    if uncited:
        print(f"keys cited nowhere: {', '.join(uncited)}")
    if ok:
        print("Cited-in lists match the pages.")
    elif not args.write:
        print("Cited-in lists are stale; run with --write.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
