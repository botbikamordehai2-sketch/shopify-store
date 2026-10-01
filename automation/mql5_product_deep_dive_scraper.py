"""
MQL5 Market competitor deep-dive: single public product page.

RESEARCH_ONLY: reads one public mql5.com Market product page and writes a
JSON report under research/. Never touches the live Shopify store, never
logs in, never downloads the product's actual screenshots/files - image
URLs and alt text are recorded, the images themselves are not fetched.

Target product and URL were taken from the prior wide competition scan
(research/mql5_competition_analysis_wide.json -> "Position Size
Calculator" niche -> "Forex Trade Manager MT5").

robots.txt notes (checked via urllib.robotparser against text fetched
with `requests`, since RobotFileParser.read()'s bare urllib call gets
blocked by mql5.com - see the sibling competition scraper for the same
issue): the product overview page itself is allowed, but
"Disallow: /*/market/product/*/comments" and
".../updates" explicitly block the separate Comments and "What's new"
(changelog) tabs/pages - those are skipped entirely, including their
links, even though the page's own robots.txt is permissive enough that a
naive wildcard-unaware parser would let them through. Reviews are not
behind that block: MQL5 renders the latest ~20 reviews directly into the
main product page's HTML, so no disallowed page is needed to get them.

Politeness: a short delay between the robots.txt fetch and the page
fetch; this is a single-page job so there is nothing to loop a 2-3s delay
over, but the pause before the one real request is kept anyway.
"""
import json
import random
import re
import time
import urllib.robotparser
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

PRODUCT_URL = "https://www.mql5.com/en/market/product/39150"  # Forex Trade Manager MT5
ROBOTS_URL = "https://www.mql5.com/robots.txt"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36 MarketResearchBot/1.0 "
    "(+educational research; contact: mbotbika9@gmail.com)"
}
# robots.txt explicitly blocks these sub-paths for this product; never fetch them.
DISALLOWED_SUFFIXES = ("/comments", "/updates")

REPO_ROOT = Path(r"C:\Users\User\Projects\shopify-store")
OUTPUT_PATH = REPO_ROOT / "research" / "competitor_deep_dive_forex_trade_manager.json"


def load_robots_parser():
    resp = requests.get(ROBOTS_URL, headers=HEADERS, timeout=20)
    rp = urllib.robotparser.RobotFileParser()
    rp.parse(resp.text.splitlines())
    return rp


def extract_description_and_features(soup):
    desc_el = soup.select_one("#description")
    if not desc_el:
        return None, []

    # Plain-text description: every top-level <p> that isn't inside a
    # feature <ul> (those get pulled out separately below).
    paragraphs = []
    for p in desc_el.find_all("p", recursive=False):
        text = p.get_text(" ", strip=True)
        if text:
            paragraphs.append(text)
    description = "\n\n".join(paragraphs)

    # Feature groups: an <h3> heading followed by its <ul> of <li> items.
    feature_groups = []
    for h3 in desc_el.find_all("h3"):
        ul = h3.find_next_sibling("ul")
        if not ul:
            continue
        items = []
        for li in ul.find_all("li", recursive=False):
            text = li.get_text(" ", strip=True)
            if text:
                items.append(text)
        if items:
            feature_groups.append({"heading": h3.get_text(strip=True), "items": items})

    return description, feature_groups


def extract_screenshots(soup):
    gallery = soup.select_one(".gallerySlider__container__slider")
    if not gallery:
        return {"has_video": False, "count": 0, "items": []}

    has_video = gallery.select_one(".gallerySlider__container__item__video") is not None
    items = []
    for a in gallery.select(".gallerySlider__container__item:not(.gallerySlider__container__item__video) a"):
        img = a.select_one("img")
        items.append(
            {
                "image_url": a.get("href"),
                "caption_alt_text": img.get("alt") if img else None,
            }
        )
    return {"has_video": has_video, "count": len(items), "items": items}


def extract_pricing(soup):
    price_el = soup.select_one(".info_price")
    price_text = price_el.get_text(" ", strip=True) if price_el else None

    demo_downloads = None
    for div in soup.select(".productDatatable > div"):
        text = div.get_text(" ", strip=True)
        if text.lower().startswith("demo downloaded"):
            m = re.search(r"([\d,\s]+)$", text)
            if m:
                demo_downloads = int(re.sub(r"[,\s]", "", m.group(1)))

    # This product shows exactly one price (no separate rent/subscription
    # tiers on the page); flag it generically in case another product has
    # more than one priced button.
    buy_buttons = soup.select(".product__btn-area .button, .product__btn-area a")
    tier_texts = [b.get_text(" ", strip=True) for b in buy_buttons if b.get_text(strip=True)]

    return {
        "price_text": price_text,
        "has_free_demo": demo_downloads is not None and demo_downloads > 0,
        "demo_download_count": demo_downloads,
        "pricing_tiers_or_buy_buttons_found": tier_texts,
        "note": "Single price shown on page; no separate rent/subscription tier detected." if len(tier_texts) <= 1 else None,
    }


def extract_metadata(soup):
    def datatable_value(label_prefix):
        for div in soup.select(".productDatatable > div"):
            text = div.get_text(" ", strip=True)
            if text.lower().startswith(label_prefix.lower()):
                val_el = div.select_one(".productDatatableValue")
                return val_el.get_text(strip=True) if val_el else text[len(label_prefix):].strip()
        return None

    def info_item(label):
        for li in soup.select(".product-page-info__item"):
            label_el = li.select_one(".product-page-info__label")
            if label_el and label_el.get_text(strip=True).rstrip(":").lower() == label.lower():
                return li.get_text(" ", strip=True).split(":", 1)[-1].strip()
        return None

    reviews_tab = soup.select_one("#tab_p_reviews")
    reviews_count_text = reviews_tab.get_text(" ", strip=True) if reviews_tab else ""
    m = re.search(r"\((\d+)\)", reviews_count_text)
    total_reviews = int(m.group(1)) if m else None

    purchases_el = soup.select_one(".path__purchases_counter")
    purchases_per_month = None
    if purchases_el:
        m2 = re.search(r"(\d+)", purchases_el.get_text())
        purchases_per_month = int(m2.group(1)) if m2 else None

    rating_el = soup.select_one(".product-rating-value")

    return {
        "category": (soup.select_one(".product-page-info__item a") or {}).get("href") and
        soup.select_one(".product-page-info__item a").get_text(strip=True),
        "overall_rating": float(rating_el.get_text(strip=True)) if rating_el else None,
        "total_reviews": total_reviews,
        "purchases_per_month": purchases_per_month,
        "published": datatable_value("Published"),
        "current_version": datatable_value("Current version") or info_item("Version"),
        "last_updated": info_item("Updated"),
        "activations_per_purchase": info_item("Activations"),
        "note": (
            "Version history / changelog ('What's new' tab) lives at a URL "
            "robots.txt disallows (/market/product/*/updates) and was not "
            "fetched. 'current_version' + 'last_updated' above come from the "
            "allowed overview page and are the only update-frequency signal used."
        ),
    }


def star_rating_from_class(el):
    if not el:
        return None
    for cls in el.get("class", []):
        m = re.match(r"g-rating_v(\d+)$", cls)
        if m:
            return int(m.group(1)) / 10
    return None


def extract_reviews(soup, limit=15):
    """MQL5 renders the latest reviews twice: a 3-item "featured preview"
    block (ids topReviewInfo_*/topReviewContentBlock_*) and the real,
    complete chronological list right below it (ids reviewInfo_*/
    reviewContentBlock_*, ~20 items). Only the second is used here -
    selecting on both would silently duplicate the 3 overlapping reviews."""
    reviews = []
    for comment in soup.select(".customerReviews .comment"):
        if not comment.select_one("[id^='reviewInfo_']"):
            continue  # this is a "featured preview" duplicate, skip it

        author_el = comment.select_one(".comment__info .author")
        date_el = comment.select_one(".comment__info > span > span[style]")
        rating_el = comment.select_one(".comment__info .g-rating")
        content_block = comment.select_one("[id^='reviewContentBlock_']")
        text = content_block.get_text(" ", strip=True) if content_block else None

        reviews.append(
            {
                "author": author_el.get_text(strip=True) if author_el else None,
                "date": date_el.get_text(strip=True) if date_el else None,
                "rating": star_rating_from_class(rating_el),
                "text": text,
            }
        )
        if len(reviews) >= limit:
            break
    return reviews


def main():
    rp = load_robots_parser()
    if not rp.can_fetch(HEADERS["User-Agent"], PRODUCT_URL):
        raise SystemExit(f"robots.txt disallows {PRODUCT_URL}")
    for suffix in DISALLOWED_SUFFIXES:
        print(f"(skipping {PRODUCT_URL}{suffix} - disallowed by robots.txt)")

    time.sleep(random.uniform(2, 3))

    resp = requests.get(PRODUCT_URL, headers=HEADERS, timeout=20)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    description, feature_groups = extract_description_and_features(soup)
    screenshots = extract_screenshots(soup)
    pricing = extract_pricing(soup)
    metadata = extract_metadata(soup)
    reviews = extract_reviews(soup, limit=15)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "product_name": (soup.select_one("h1.product-page-title") or {}).get_text(strip=True)
        if soup.select_one("h1.product-page-title") else None,
        "url": PRODUCT_URL,
        "metadata": metadata,
        "description": description,
        "feature_groups": feature_groups,
        "screenshots": screenshots,
        "pricing": pricing,
        "reviews_fetched": len(reviews),
        "reviews": reviews,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"\nProduct: {report['product_name']}")
    print(f"Rating: {metadata['overall_rating']} ({metadata['total_reviews']} reviews) | "
          f"Published {metadata['published']} | v{metadata['current_version']} | Updated {metadata['last_updated']} | "
          f"{metadata['purchases_per_month']} purchases/month")
    print(f"Price: {pricing['price_text']} | Free demo: {pricing['has_free_demo']} "
          f"({pricing['demo_download_count']} downloads)")
    print(f"Screenshots: {screenshots['count']} (+video: {screenshots['has_video']})")
    print(f"Feature groups: {[g['heading'] for g in feature_groups]}")
    print(f"Fetched {len(reviews)} reviews.")
    print(f"\nSaved full report to {OUTPUT_PATH}")
    print("\n===== FULL REPORT =====")
    dump = json.dumps(report, indent=2, ensure_ascii=False)
    import sys
    sys.stdout.buffer.write(dump.encode("utf-8", errors="replace"))
    sys.stdout.buffer.write(b"\n")


if __name__ == "__main__":
    main()
