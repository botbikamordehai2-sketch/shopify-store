"""
Google Trends demand check for forex indicator/EA sub-niches (US vs IL).

RESEARCH_ONLY: this script only reads public Google Trends data and writes
a JSON report under research/. It never touches the live Shopify store.

For each niche (one or two alternate search terms), for each region
(US, IL), it pulls:
  - interest_over_time for the last 12 months -> average interest + trend
  - related_queries ("top") -> top 5 related queries

A 2-3s delay is inserted between every Google Trends network call to stay
polite to the (unofficial) API.
"""
import json
import random
import time
from datetime import datetime, timezone
from pathlib import Path

from pytrends.request import TrendReq

TIMEFRAME = "today 12-m"
GEOS = {"US": "United States", "IL": "Israel"}

NICHES = [
    {
        "id": "smart_money_concepts_order_block",
        "label": "Smart Money Concepts / Order Block Indicator",
        "terms": ["smart money concepts indicator", "order block indicator mt4"],
    },
    {
        "id": "supply_and_demand_indicator",
        "label": "Supply and Demand Indicator (MT4)",
        "terms": ["supply and demand indicator mt4"],
    },
    {
        "id": "forex_ea_robot_download",
        "label": "Forex EA / Robot Free Download",
        "terms": ["forex ea free download", "forex robot mt5"],
    },
    {
        "id": "ict_trading_concepts",
        "label": "ICT Trading Indicator / Concepts",
        "terms": ["ict trading indicator", "ict concepts mt4"],
    },
]

REPO_ROOT = Path(r"C:\Users\User\Projects\shopify-store")
OUTPUT_PATH = REPO_ROOT / "research" / "demand_comparison_forex_indicators.json"


def polite_delay():
    time.sleep(random.uniform(2, 3))


def classify_trend(series):
    """Split a 12-month series in half and compare the two halves' means."""
    values = [v for v in series if v is not None]
    if len(values) < 4 or sum(values) == 0:
        return "no data"
    mid = len(values) // 2
    first_half = sum(values[:mid]) / mid if mid else 0
    second_half = sum(values[mid:]) / (len(values) - mid)
    if first_half == 0:
        return "rising" if second_half > 0 else "stable"
    pct_change = (second_half - first_half) / first_half * 100
    if pct_change > 10:
        return "rising"
    if pct_change < -10:
        return "declining"
    return "stable"


def fetch_region_data(pytrends, terms, geo_code):
    region_result = {"average_interest": None, "trend": None, "top_related_queries": [], "note": None}

    try:
        pytrends.build_payload(kw_list=terms, timeframe=TIMEFRAME, geo=geo_code)
        polite_delay()
        iot = pytrends.interest_over_time()
        polite_delay()
    except Exception as exc:
        region_result["note"] = f"interest_over_time failed: {exc}"
        return region_result

    if iot is None or iot.empty:
        region_result["note"] = "no interest-over-time data returned (volume too low to report)"
        region_result["average_interest"] = 0
        region_result["trend"] = "no data"
    else:
        value_cols = [c for c in iot.columns if c != "isPartial"]
        per_term_avg = {c: round(float(iot[c].mean()), 2) for c in value_cols}
        combined_series = iot[value_cols].mean(axis=1).tolist()
        region_result["average_interest"] = round(sum(combined_series) / len(combined_series), 2)
        region_result["per_term_average"] = per_term_avg
        region_result["trend"] = classify_trend(combined_series)

    try:
        related = pytrends.related_queries()
        polite_delay()
    except Exception as exc:
        region_result["note"] = (region_result["note"] or "") + f" | related_queries failed: {exc}"
        related = {}

    combined_related = {}
    for term in terms:
        term_data = (related or {}).get(term) or {}
        top_df = term_data.get("top")
        if top_df is None or top_df.empty:
            continue
        for _, row in top_df.iterrows():
            q = row["query"]
            v = row["value"]
            if q not in combined_related or v > combined_related[q]:
                combined_related[q] = v

    top5 = sorted(combined_related.items(), key=lambda kv: kv[1], reverse=True)[:5]
    region_result["top_related_queries"] = [{"query": q, "value": v} for q, v in top5]

    return region_result


def compare(us_avg, il_avg):
    if us_avg is None or il_avg is None:
        return {"higher_in": None, "ratio_us_to_il": None}
    if us_avg == il_avg:
        higher = "equal"
    else:
        higher = "US" if us_avg > il_avg else "IL"
    ratio = round(us_avg / il_avg, 2) if il_avg else None
    return {"higher_in": higher, "us_avg": us_avg, "il_avg": il_avg, "ratio_us_to_il": ratio}


def main():
    pytrends = TrendReq(hl="en-US", tz=0, retries=2, backoff_factor=0.5, timeout=(10, 30))

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "timeframe": TIMEFRAME,
        "regions_checked": list(GEOS.keys()),
        "niches": [],
    }

    for niche in NICHES:
        print(f"\n=== {niche['label']} ({', '.join(niche['terms'])}) ===")
        niche_entry = {
            "id": niche["id"],
            "label": niche["label"],
            "terms": niche["terms"],
            "regions": {},
        }

        for geo_code in GEOS:
            print(f"  -> region {geo_code} ...")
            region_data = fetch_region_data(pytrends, niche["terms"], geo_code)
            niche_entry["regions"][geo_code] = region_data
            print(
                f"     avg_interest={region_data['average_interest']} "
                f"trend={region_data['trend']} "
                f"related={[r['query'] for r in region_data['top_related_queries']]}"
            )

        us_avg = niche_entry["regions"].get("US", {}).get("average_interest")
        il_avg = niche_entry["regions"].get("IL", {}).get("average_interest")
        niche_entry["comparison"] = compare(us_avg, il_avg)

        report["niches"].append(niche_entry)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"\nSaved report to {OUTPUT_PATH}")
    print("\n===== FULL REPORT =====")
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
