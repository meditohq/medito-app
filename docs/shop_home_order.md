# Home shop widget — automatic reorder

A weekly GitHub Actions job (`.github/workflows/refresh-shop-home-order.yml`)
re-ranks the `app-home` Fourthwall collection from the last 28 days of app
BigQuery data and PUTs the new order to the Fourthwall admin API. The widget
already pins the first product and rotates the rest daily
(`homeProductsForDay` in `lib/views/home/widgets/products/home_products_section.dart`),
so moving a product to slot 1 is how the top scorer gets more exposure.

## Score

For each product with ≥1 shop event in the window:

```
score = (add_to_bag + 1) / (home_pdp + grid_pdp + 1 + 20)
```

Shrinkage prior (α=1, β=20) means a product with 0 PDPs scores ~4.8%, a product
with 20 PDPs / 5 ATB scores ~15%, a product with 1,000 PDPs / 40 ATB scores ~4%.
New products aren't buried; established low-converters fall.

Products first seen in BQ < 21 days ago get at least the median score, so a
launch doesn't get punished for small-n noise.

## Guardrails

- **Floor:** skip the run if last-28d Home PDPs are below 1,500.
- **Editorial locks** (`tools/shop_home_locks.yaml`):
  `always_include` are never dropped; `never_include` are never added.
- **Max 3 swaps per run**, so the row doesn't thrash.
- Dry-run (`workflow_dispatch` input, or `DRY_RUN=1` locally) prints the
  proposed order without calling Fourthwall.
- The job commits a one-section append to `docs/shop_home_order_log.md`
  (old vs new table), so `git log` is the audit trail.

## Secrets (repo settings → Actions → Secrets)

| name | what |
|---|---|
| `BQ_READONLY_SA` | JSON key for a GCP service account with `bigquery.jobUser` on `medito-9165c` and `bigquery.dataViewer` on `analytics_451310720`. |
| `FOURTHWALL_API_USER` | Username of an "Open API User" created at `https://my-shop.fourthwall.com/admin/dashboard/settings/for-developers` (SUPER ADMIN only). |
| `FOURTHWALL_API_PASS` | Password for that same user. |
| `SLACK_SHOP_WEBHOOK` | Optional; one-line summary of every non-dry-run change. |

## Trying it before enabling

Run once from the Actions tab:

> **refresh-shop-home-order** → Run workflow → `dry_run: true`

The log will show the proposed order and the full table that would be appended
to `docs/shop_home_order_log.md`. No Fourthwall call is made.

## Running locally

```bash
GOOGLE_APPLICATION_CREDENTIALS_JSON="$(cat ~/keys/bq-sa.json)" \
FW_USER=…  FW_PASS=…  DRY_RUN=1 \
python tools/refresh_shop_home_order.py
```
