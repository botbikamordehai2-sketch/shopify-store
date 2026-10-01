"""
MQL5 Market competition scraper (public search pages only).

RESEARCH_ONLY: reads public mql5.com Market search-result pages and writes
a JSON report under research/. Never touches the live Shopify store, and
never logs in / submits purchases / bypasses any access control.

For each niche (one or more alternate search phrases) it fetches the
Market's own in-page search (filtered product listing for MT5), and
records the top 10 results: product name, price, star rating, and number
of reviews/ratings. It then summarizes, per niche: how many competing
products matched, the price range, free-vs-paid split, and which
product(s) lead on review count (the most concrete demand+competition
signal available from this public page).

run_scan(niches, output_path) is the reusable entry point — see
mql5_market_competition_scraper_wide.py for a second run against a
different set of niches without duplicating this logic.

Mechanics notes (reverse-engineered from the page's own JS, not an
undocumented API): the visible search box posts to /en/market/mt5 with
a query param the page's JS calls "keyword", but that param is only used
client-side for autosuggest. The actual param the server honors for a
filtered listing is "filter" (see `keywordParamName:'filter'` in the
page's inline script). That is the only non-public mechanism used here;
everything else is a plain GET of a public HTML page.

Politeness:
  - robots.txt for mql5.com is fetched via `requests` (not
    RobotFileParser.read(), which uses bare urllib and gets blocked here)
    and checked with urllib.robotparser before every fetch.
  - A random 2-3s delay is inserted between every page request.
"""
import json
import random
import re
import time
import urllib.parse
import urllib.robotparser
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

ROBOTS_URL = "https://www.mql5.com/robots.txt"
SEARCH_BASE = "https://www.mql5.com/en/market/mt5"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36 MarketResearchBot/1.0 "
    "(+educational research; contact: mbotbika9@gmail.com)"
}

TERMS = ["smart money concepts", "order block", "supply and demand", "ICT"]
TOP_N = 10

REPO_ROOT = Path(r"C:\Users\User\Projects\shopify-store")
OUTPUT_PATH = REPO_ROOT / "research" / "mql5_competition_analysis.json"


def load_robots_parser():
    resp = requests.get(ROBOTS_URL, headers=HEADERS, timeout=20)
    rp = urllib.robotparser.RobotFileParser()
    rp.parse(resp.text.splitlines())
    return rp


def parse_price(raw_text):
    text = " ".join(raw_text.split())
    if not text:
        return None
    if "free" in text.lower():
        return {"amount": 0.0, "currency": "USD", "raw": text}
    m = re.match(r"([\d,\s]+(?:\.\d+)?)\s*([A-Z]{3})?", text)
    if m and m.group(1).strip():
        amount = float(m.group(1).replace(",", "").replace(" ", ""))
        return {"amount": amount, "currency": m.group(2) or "USD", "raw": text}
    return {"amount": None, "currency": None, "raw": text}


def parse_rating(card):
    info = card.select_one(".product-card__rating .g-rating__info")
    if not info:
        return {"value": None, "review_count": None}
    text = info.get_text(strip=True)
    m = re.match(r"([\d.]+)\s*\((\d+)\)", text)
    if not m:
        return {"value": None, "review_count": None}
    return {"value": float(m.group(1)), "review_count": int(m.group(2))}


def extract_pagination(soup):
    """MQL5 shows ~70 products per page; the bottom pager's highest page
    number is the only place the result-set size is exposed."""
    pages = []
    for a in soup.select(".market-paginator-bottom .paginatorEx a, .market__block-filter .paginatorEx a"):
        text = a.get_text(strip=True)
        if text.isdigit():
            pages.append(int(text))
    return max(pages) if pages else 1


def extract_products(soup):
    cards = soup.select("div.product-card")
    products = []
    for card in cards:
        title_el = card.select_one("a.product-card__title")
        name_el = card.select_one(".product-card__title-wrapper")
        price_el = card.select_one(".product-card__price")
        author_el = card.select_one(".product-card__author")
        category_el = card.select_one(".product-card__category-name")

        if not name_el:
            continue

        rating = parse_rating(card)
        products.append(
            {
                "name": name_el.get_text(strip=True),
                "url": urllib.parse.urljoin("https://www.mql5.com", title_el["href"]) if title_el else None,
                "author": author_el.get_text(strip=True) if author_el else None,
                "category": category_el.get_text(strip=True) if category_el else None,
                "price": parse_price(price_el.get_text()) if price_el else None,
                "rating": rating["value"],
                "review_count": rating["review_count"],
            }
        )
    return products


def fetch_term(rp, session, term):
    """One GET for one literal search phrase. A niche may combine several
    of these (alternate phrasings) via fetch_niche()."""
    url = f"{SEARCH_BASE}?filter={urllib.parse.quote(term)}"

    if not rp.can_fetch(HEADERS["User-Agent"], url):
        return {"term": term, "url": url, "error": "disallowed by robots.txt"}

    try:
        resp = session.get(url, timeout=20)
    except requests.RequestException as exc:
        return {"term": term, "url": url, "error": str(exc)}

    if resp.status_code != 200:
        return {"term": term, "url": url, "error": f"http {resp.status_code}"}

    soup = BeautifulSoup(resp.text, "html.parser")
    all_products = extract_products(soup)
    page_size = len(all_products)
    pages = extract_pagination(soup)

    return {
        "term": term,
        "url": url,
        "products_on_first_page": page_size,
        "result_pages": pages,
        "competitor_count_estimate": {
            "method": "page_size * last_page_number (last page may be partial, so this is an upper bound; exact on-page count only when result_pages == 1)",
            "value": page_size if pages == 1 else page_size * pages,
            "is_exact": pages == 1,
        },
        "all_products": all_products,
    }


def fetch_niche(rp, session, niche, delay_between_terms=True):
    """A niche may list 2+ alternate search phrases (e.g. "copy trading" /
    "signal copier"). Each phrase is fetched separately (MQL5's filter only
    takes one phrase at a time) with the usual 2-3s delay between the
    requests, then the phrases' results are merged: dedup by product URL
    (keep the entry seen with the higher review_count), re-sorted by
    review_count, and the competitor-count estimate is the max across the
    phrases (summing would double-count products that match both phrases)."""
    term_results = []
    for i, term in enumerate(niche["terms"]):
        term_results.append(fetch_term(rp, session, term))
        if delay_between_terms and i < len(niche["terms"]) - 1:
            time.sleep(random.uniform(2, 3))

    errors = [r for r in term_results if "error" in r]
    ok_results = [r for r in term_results if "error" not in r]

    merged_by_url = {}
    for r in ok_results:
        for p in r["all_products"]:
            key = p.get("url") or p["name"]
            existing = merged_by_url.get(key)
            if existing is None or (p.get("review_count") or 0) > (existing.get("review_count") or 0):
                merged_by_url[key] = p

    merged_products = sorted(merged_by_url.values(), key=lambda p: p.get("review_count") or 0, reverse=True)

    best_estimate = None
    if ok_results:
        best = max(ok_results, key=lambda r: r["competitor_count_estimate"]["value"])
        best_estimate = best["competitor_count_estimate"]

    return {
        "id": niche["id"],
        "label": niche["label"],
        "terms": niche["terms"],
        "per_term": [
            {
                "term": r["term"],
                "url": r.get("url"),
                "error": r.get("error"),
                "result_pages": r.get("result_pages"),
                "competitor_count_estimate": r.get("competitor_count_estimate"),
            }
            for r in term_results
        ],
        "errors": [e["error"] for e in errors] or None,
        "competitor_count_estimate": best_estimate,
        "top_results": merged_products[:TOP_N],
    }


def summarize(niche_result):
    products = niche_result.get("top_results") or []
    priced = [p["price"]["amount"] for p in products if p.get("price") and p["price"]["amount"] is not None]
    rated = [p for p in products if p.get("review_count")]

    top_by_reviews = sorted(rated, key=lambda p: p["review_count"], reverse=True)[:3]

    free_count = sum(1 for p in products if p.get("price") and p["price"]["amount"] == 0)
    paid_count = sum(1 for p in products if p.get("price") and p["price"]["amount"] not in (None, 0))
    unknown_price_count = len(products) - free_count - paid_count

    return {
        "competitor_count_estimate": niche_result.get("competitor_count_estimate"),
        "price_range_usd": {"min": min(priced), "max": max(priced)} if priced else None,
        "free_vs_paid_in_top10": {
            "free": free_count,
            "paid": paid_count,
            "unknown_price": unknown_price_count,
            "percent_free": round(free_count / len(products) * 100, 1) if products else None,
        },
        "leading_products_by_review_count": [
            {"name": p["name"], "review_count": p["review_count"], "rating": p["rating"], "price": p["price"]}
            for p in top_by_reviews
        ],
    }


def terms_to_niches(terms):
    """Back-compat helper: wrap a flat list of single-phrase terms (the
    original 4-niche run) as single-term niches for run_scan()."""
    return [{"id": t.replace(" ", "_"), "label": t, "terms": [t]} for t in terms]


def print_niche_result(result):
    if result.get("errors"):
        print(f"  [error] {result['errors']}")
        return
    for p in result["top_results"]:
        price_str = (
            "Free" if p["price"] and p["price"]["amount"] == 0 else
            f"{p['price']['amount']} {p['price']['currency']}" if p["price"] and p["price"]["amount"] is not None else
            "n/a"
        )
        print(f"  - {p['name']} | {price_str} | rating={p['rating']} | reviews={p['review_count']}")
    print(f"  summary: {json.dumps(result['summary'], ensure_ascii=False)}")


def run_scan(niches, output_path, source_label=SEARCH_BASE):
    """Fetch every niche (each niche's own terms, with delays already
    applied between them), summarize, print, and save to output_path."""
    rp = load_robots_parser()
    session = requests.Session()
    session.headers.update(HEADERS)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": source_label,
        "niches": [],
    }

    for i, niche in enumerate(niches):
        print(f"\n=== {niche['label']} ({', '.join(niche['terms'])}) ===")
        result = fetch_niche(rp, session, niche, delay_between_terms=True)
        result["summary"] = None if result.get("errors") and not result["top_results"] else summarize(result)
        print_niche_result(result)
        report["niches"].append(result)

        if i < len(niches) - 1:
            time.sleep(random.uniform(2, 3))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nSaved report to {output_path}")
    print("\n===== FULL REPORT =====")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return report


def main():
    run_scan(terms_to_niches(TERMS), OUTPUT_PATH)


if __name__ == "__main__":
    main()
