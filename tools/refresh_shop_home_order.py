#!/usr/bin/env python3
"""Weekly refresh of the Fourthwall `app-home` collection order.

Ranks every in-stock product by Bayesian-shrunken add-to-bag rate over the last
28 days of BigQuery data, picks the top N (default 11), and PUTs the result to
the Fourthwall admin API. See tools/shop_home_locks.yaml for editorial locks and
tunables, and docs/shop_home_order.md for the full design note.

Env vars:
  GOOGLE_APPLICATION_CREDENTIALS_JSON   service-account JSON (contents, not path)
  FW_USER, FW_PASS                      Fourthwall "Open API User" credentials
  SLACK_WEBHOOK                         optional; posts a one-line summary
  DRY_RUN=1                             print the plan, skip the PUT

Exit codes: 0 ok (changed or noop), 1 refused (guardrails tripped), 2 error.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import requests
import yaml
from google.cloud import bigquery
from requests.auth import HTTPBasicAuth

ROOT = Path(__file__).resolve().parent.parent
LOCKS_FILE = ROOT / "tools" / "shop_home_locks.yaml"
LOG_FILE = ROOT / "docs" / "shop_home_order_log.md"

BQ_PROJECT = "medito-9165c"
BQ_DATASET = "analytics_451310720"

FW_HOST = "https://api.fourthwall.com/open-api/v1.0"
COLLECTION_SLUG = "app-home"

HOME_PDP_FLOOR = 1500  # skip the run if last-28d Home PDPs are below this
MAX_DROPS_PER_RUN = 3  # cap churn so the list does not thrash
DEFAULT_SIZE = 11       # target number of products in app-home
NEW_PRODUCT_DAYS = 21   # products first seen more recently get the median score
ALPHA = 1.0             # Bayesian prior: pseudo-ATB
BETA = 20.0             # Bayesian prior: pseudo-PDPs


RANKING_SQL = f"""
DECLARE window_days INT64 DEFAULT 28;

WITH ev AS (
  SELECT
    event_name,
    PARSE_DATE('%Y%m%d', event_date) AS d,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'product_slug') AS slug,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source')       AS source
  FROM `{BQ_PROJECT}.{BQ_DATASET}.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL window_days DAY))
                          AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND event_name IN ('shop_product_viewed','shop_add_to_bag')
)
SELECT
  slug,
  COUNTIF(event_name = 'shop_product_viewed' AND source = 'home_card') AS home_pdp,
  COUNTIF(event_name = 'shop_product_viewed' AND source = 'shop_grid') AS grid_pdp,
  COUNTIF(event_name = 'shop_add_to_bag')                              AS atb,
  MIN(d)                                                                AS first_seen
FROM ev
WHERE slug IS NOT NULL
GROUP BY slug
"""


# ---------- data classes ----------

@dataclass
class Product:
    offer_id: str
    slug: str
    name: str
    available: bool


@dataclass
class Score:
    slug: str
    home_pdp: int
    grid_pdp: int
    atb: int
    rate: float  # shrunken ATB rate
    first_seen_days_ago: int | None


# ---------- helpers ----------

def _log(msg: str) -> None:
    print(msg, flush=True)


def _bq_client() -> bigquery.Client:
    key = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON")
    if not key:
        raise SystemExit("GOOGLE_APPLICATION_CREDENTIALS_JSON is not set")
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        f.write(key)
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = f.name
    return bigquery.Client(project=BQ_PROJECT)


def _fw_auth() -> HTTPBasicAuth:
    user = os.environ.get("FW_USER")
    pw = os.environ.get("FW_PASS")
    if not (user and pw):
        raise SystemExit("FW_USER / FW_PASS not set")
    return HTTPBasicAuth(user, pw)


def _fw_get(path: str, auth: HTTPBasicAuth, **params) -> dict:
    r = requests.get(f"{FW_HOST}{path}", auth=auth, params=params, timeout=30)
    r.raise_for_status()
    return r.json()


def shrunken_rate(atb: int, pdps: int) -> float:
    return (atb + ALPHA) / (pdps + ALPHA + BETA)


def load_locks() -> dict:
    if not LOCKS_FILE.exists():
        return {"always_include": [], "never_include": []}
    return yaml.safe_load(LOCKS_FILE.read_text()) or {"always_include": [], "never_include": []}


# ---------- Fourthwall calls ----------

def find_app_home_collection(auth: HTTPBasicAuth) -> dict:
    cols = _fw_get("/collections", auth)
    for c in cols.get("results", cols if isinstance(cols, list) else []):
        if c.get("slug") == COLLECTION_SLUG:
            return c
    raise SystemExit(f"collection '{COLLECTION_SLUG}' not found")


def fetch_collection_offer_ids(auth: HTTPBasicAuth, collection_id: str) -> list[str]:
    data = _fw_get(f"/collections/{collection_id}/products", auth, size=200)
    return [p["id"] for p in data.get("results", data if isinstance(data, list) else [])]


def fetch_all_in_stock_products(auth: HTTPBasicAuth) -> list[Product]:
    out: list[Product] = []
    page = 0
    while True:
        data = _fw_get("/products", auth, page=page, size=100)
        results = data.get("results", [])
        for p in results:
            variants = p.get("variants") or []
            available = any(
                (v.get("availability") or {}).get("inStock", True) for v in variants
            )
            out.append(Product(
                offer_id=p["id"],
                slug=p.get("slug") or p.get("handle") or "",
                name=p.get("name") or p.get("title") or "",
                available=available and p.get("state", "AVAILABLE") == "AVAILABLE",
            ))
        if not data.get("paging", {}).get("hasNextPage"):
            break
        page += 1
    return out


def put_collection_order(auth: HTTPBasicAuth, collection_id: str, offer_ids: list[str]) -> None:
    r = requests.put(
        f"{FW_HOST}/collections/{collection_id}/products",
        auth=auth,
        json={"offerIds": offer_ids},
        timeout=30,
    )
    if r.status_code >= 400:
        raise SystemExit(f"Fourthwall PUT failed: {r.status_code} {r.text}")


# ---------- ranking ----------

def rank(scores: list[Score], products: list[Product], locks: dict, current: list[str]) -> list[str]:
    """Return the new ordered offer-id list."""
    by_slug = {p.slug: p for p in products if p.available}
    scored_by_slug = {s.slug: s for s in scores}

    always = set(locks.get("always_include", []) or [])
    never = set(locks.get("never_include", []) or [])

    # Median rate used as the floor for new products.
    rates = sorted(s.rate for s in scores if s.rate > 0)
    median_rate = rates[len(rates) // 2] if rates else 0.05

    def effective_rate(p: Product) -> float:
        s = scored_by_slug.get(p.slug)
        if s is None:
            return median_rate  # unseen product, neutral score
        if s.first_seen_days_ago is not None and s.first_seen_days_ago < NEW_PRODUCT_DAYS:
            return max(s.rate, median_rate)
        return s.rate

    candidates = [p for p in by_slug.values() if p.slug not in never]
    candidates.sort(key=effective_rate, reverse=True)

    # Top-N, ensuring every always_include is present.
    picked = [p for p in candidates if p.slug in always]
    for p in candidates:
        if p in picked:
            continue
        if len(picked) >= DEFAULT_SIZE:
            break
        picked.append(p)

    # Re-sort picked by effective_rate so slot 1 is the top scorer.
    picked.sort(key=effective_rate, reverse=True)
    proposed = [p.offer_id for p in picked]

    # Enforce max-drops per run.
    current_set = set(current)
    drops = current_set - set(proposed)
    if len(drops) > MAX_DROPS_PER_RUN:
        # Keep the N-MAX_DROPS highest-rated currently-in items, replace the rest.
        keep = [oid for oid in current if oid in set(proposed)][: DEFAULT_SIZE - MAX_DROPS_PER_RUN]
        newcomers = [oid for oid in proposed if oid not in current_set]
        # Fill with the current items we didn't demote, by current position order.
        filler = [oid for oid in current if oid in current_set - set(keep) - drops]
        proposed = keep + newcomers[:MAX_DROPS_PER_RUN] + filler
        proposed = proposed[:DEFAULT_SIZE]

    return proposed


# ---------- logging ----------

def changelog_entry(when: datetime, old: list[Product], new: list[Product]) -> str:
    def row(p: Product) -> str:
        return f"| {p.slug} | {p.name} |"
    lines = [f"\n### {when.isoformat(timespec='minutes')}"]
    lines.append("")
    lines.append("| # | old | new |")
    lines.append("|---|-----|-----|")
    for i in range(max(len(old), len(new))):
        oslug = old[i].slug if i < len(old) else "·"
        nslug = new[i].slug if i < len(new) else "·"
        marker = "←" if oslug != nslug else " "
        lines.append(f"| {i + 1} | {oslug} | {marker} {nslug} |")
    return "\n".join(lines) + "\n"


def post_slack(webhook: str, msg: str) -> None:
    try:
        requests.post(webhook, json={"text": msg}, timeout=10)
    except Exception as e:  # noqa: BLE001
        _log(f"slack post failed: {e}")


# ---------- main ----------

def main() -> int:
    dry_run = os.environ.get("DRY_RUN") in {"1", "true", "True"}
    auth = _fw_auth()

    # 1. Rank from BQ.
    _log("querying BigQuery…")
    bq = _bq_client()
    rows = list(bq.query(RANKING_SQL).result())
    today = datetime.now(timezone.utc).date()
    scores: list[Score] = []
    total_home_pdp = 0
    for r in rows:
        total_home_pdp += r["home_pdp"]
        pdps = (r["home_pdp"] or 0) + (r["grid_pdp"] or 0)
        first_seen = r["first_seen"]
        scores.append(Score(
            slug=r["slug"],
            home_pdp=r["home_pdp"] or 0,
            grid_pdp=r["grid_pdp"] or 0,
            atb=r["atb"] or 0,
            rate=shrunken_rate(r["atb"] or 0, pdps),
            first_seen_days_ago=(today - first_seen).days if first_seen else None,
        ))
    _log(f"scored {len(scores)} products; total Home PDPs = {total_home_pdp}")

    if total_home_pdp < HOME_PDP_FLOOR:
        _log(f"below Home PDP floor ({HOME_PDP_FLOOR}); skipping run")
        return 0

    # 2. Pull Fourthwall state.
    _log("fetching Fourthwall collection + catalogue…")
    coll = find_app_home_collection(auth)
    current_ids = fetch_collection_offer_ids(auth, coll["id"])
    all_products = fetch_all_in_stock_products(auth)
    by_id = {p.offer_id: p for p in all_products}
    current = [by_id[oid] for oid in current_ids if oid in by_id]

    # 3. Compute proposed order.
    locks = load_locks()
    proposed_ids = rank(scores, all_products, locks, current_ids)
    proposed = [by_id[oid] for oid in proposed_ids]

    if proposed_ids == current_ids:
        _log("no change; exiting")
        return 0

    _log("\nproposed order:")
    for i, p in enumerate(proposed, 1):
        mark = " " if p.offer_id in set(current_ids) else "+"
        _log(f"  {i:2d} {mark} {p.slug}  ({p.name})")

    # 4. PUT the new order.
    if dry_run:
        _log("\nDRY_RUN=1 → not calling Fourthwall")
    else:
        _log("\nPUT /collections/{id}/products …")
        put_collection_order(auth, coll["id"], proposed_ids)
        _log("OK")

    # 5. Changelog + Slack.
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    entry = changelog_entry(datetime.now(timezone.utc), current, proposed)
    if dry_run:
        _log("\n" + entry)
    else:
        if LOG_FILE.exists():
            LOG_FILE.write_text(LOG_FILE.read_text() + entry)
        else:
            LOG_FILE.write_text("# app-home order — change log\n" + entry)

    webhook = os.environ.get("SLACK_WEBHOOK")
    if webhook and not dry_run:
        drops = [p.slug for p in current if p.offer_id not in set(proposed_ids)]
        adds = [p.slug for p in proposed if p.offer_id not in set(current_ids)]
        post_slack(
            webhook,
            f"app-home refreshed — +{', '.join(adds) or 'none'}  −{', '.join(drops) or 'none'}  "
            f"(slot 1 = {proposed[0].slug if proposed else '—'})",
        )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001
        _log(f"ERROR: {e}")
        sys.exit(2)
