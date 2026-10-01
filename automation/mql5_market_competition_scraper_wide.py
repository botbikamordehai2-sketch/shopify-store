"""
MQL5 Market competition scan — wide pass, 10 new niches.

RESEARCH_ONLY: reads public mql5.com Market search-result pages and writes
a JSON report under research/. Never touches the live Shopify store.

Reuses mql5_market_competition_scraper.py's fetch/parse/merge/summarize
logic (run_scan) against a different, deliberately non-overlapping set of
10 niches (the first pass already covered smart money concepts / order
block / supply and demand / ICT). Several niches here list two alternate
phrasings; run_scan's fetch_niche() queries each phrasing separately (with
the usual 2-3s delay between every request) and merges the results.

After the scan, builds one comparison table across all 10 niches: a
Low/Medium/High competition label (from the page-count-based competitor
estimate), price range, % free among the top-10 leaders, and a rank from
"most promising" to "least promising" — promising meaning low competition
AND at least one paid product in the top 10 with real reviews (proof
people already pay for a product in this niche, without the niche being
saturated).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mql5_market_competition_scraper as base  # noqa: E402

REPO_ROOT = Path(r"C:\Users\User\Projects\shopify-store")
OUTPUT_PATH = REPO_ROOT / "research" / "mql5_competition_analysis_wide.json"

NICHES = [
    {"id": "position_size_calculator", "label": "Position Size Calculator", "terms": ["position size calculator"]},
    {"id": "trade_journal", "label": "Trade Journal", "terms": ["trade journal"]},
    {"id": "news_filter", "label": "News Filter", "terms": ["news filter"]},
    {"id": "grid_martingale_ea", "label": "Grid / Martingale EA", "terms": ["grid"]},
    {"id": "copy_trading_signal_copier", "label": "Copy Trading / Signal Copier", "terms": ["copy trading", "signal copier"]},
    {"id": "scalping", "label": "Scalping", "terms": ["scalping"]},
    {"id": "trend_following", "label": "Trend Following", "terms": ["trend following"]},
    {"id": "multi_timeframe_dashboard", "label": "Multi Timeframe Dashboard", "terms": ["multi timeframe dashboard"]},
    {"id": "backtesting_strategy_tester", "label": "Backtesting / Strategy Tester", "terms": ["backtesting", "strategy tester"]},
    {"id": "prop_firm_ftmo", "label": "Prop Firm / FTMO", "terms": ["prop firm", "ftmo"]},
]

# Thresholds for the competitor_count_estimate (page_size * last_page,
# an upper bound - see base.fetch_term). Chosen from the first pass's
# range (560-1,260 for 4 very common terms) so "Low" means genuinely
# thin, not just thinner-than-ICT.
LOW_MAX = 200
MEDIUM_MAX = 600


def competition_level(estimate_value):
    if estimate_value is None:
        return "unknown"
    if estimate_value < LOW_MAX:
        return "Low"
    if estimate_value < MEDIUM_MAX:
        return "Medium"
    return "High"


def build_comparison_table(report):
    level_rank = {"Low": 0, "Medium": 1, "High": 2, "unknown": 3}
    rows = []

    for niche in report["niches"]:
        summary = niche.get("summary")
        if not summary:
            rows.append(
                {
                    "id": niche["id"],
                    "label": niche["label"],
                    "competition_level": "unknown",
                    "competitor_count_estimate": None,
                    "price_range_usd": None,
                    "percent_free_in_top10": None,
                    "paid_products_with_reviews_in_top10": 0,
                    "max_reviews_on_a_paid_product": 0,
                    "note": "fetch error - see niches[].errors",
                }
            )
            continue

        estimate = summary["competitor_count_estimate"]
        estimate_value = estimate["value"] if estimate else None
        level = competition_level(estimate_value)

        top10 = niche.get("top_results") or []
        paid_with_reviews = [
            p for p in top10
            if p.get("price") and p["price"]["amount"] not in (None, 0) and (p.get("review_count") or 0) > 0
        ]
        max_paid_reviews = max((p["review_count"] for p in paid_with_reviews), default=0)

        rows.append(
            {
                "id": niche["id"],
                "label": niche["label"],
                "competition_level": level,
                "competitor_count_estimate": estimate_value,
                "price_range_usd": summary["price_range_usd"],
                "percent_free_in_top10": summary["free_vs_paid_in_top10"]["percent_free"],
                "paid_products_with_reviews_in_top10": len(paid_with_reviews),
                "max_reviews_on_a_paid_product": max_paid_reviews,
                "note": None,
            }
        )

    rows.sort(
        key=lambda r: (
            level_rank[r["competition_level"]],
            -r["paid_products_with_reviews_in_top10"],
            -r["max_reviews_on_a_paid_product"],
            r["competitor_count_estimate"] if r["competitor_count_estimate"] is not None else 10**9,
        )
    )
    for i, row in enumerate(rows, start=1):
        row["rank_most_to_least_promising"] = i

    return rows


def main():
    report = base.run_scan(NICHES, OUTPUT_PATH, source_label=base.SEARCH_BASE)

    comparison = build_comparison_table(report)
    report["comparison_table"] = comparison
    report["comparison_table_method"] = (
        f"competition_level: Low < {LOW_MAX}, Medium < {MEDIUM_MAX}, else High "
        "(estimate = page_size x last_page_number, an upper bound). "
        "Ranked by competition_level asc, then by count of top-10 paid products "
        "with real reviews desc (proof of paid demand), then by the biggest such "
        "product's review count desc, then by competitor estimate asc."
    )
    OUTPUT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print("\n===== COMPARISON TABLE (most -> least promising) =====")
    header = f"{'#':<3} {'Niche':<32} {'Competition':<10} {'~Competitors':<12} {'Price USD':<14} {'% Free':<8} {'Paid w/ reviews':<16}"
    print(header)
    print("-" * len(header))
    for row in comparison:
        price = (
            f"{row['price_range_usd']['min']:.0f}-{row['price_range_usd']['max']:.0f}"
            if row["price_range_usd"] else "n/a"
        )
        pct_free = f"{row['percent_free_in_top10']}%" if row["percent_free_in_top10"] is not None else "n/a"
        print(
            f"{row['rank_most_to_least_promising']:<3} {row['label']:<32} {row['competition_level']:<10} "
            f"{str(row['competitor_count_estimate']):<12} {price:<14} {pct_free:<8} {row['paid_products_with_reviews_in_top10']:<16}"
        )

    print(f"\nSaved full report + comparison table to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
