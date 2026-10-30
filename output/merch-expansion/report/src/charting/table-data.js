export function numericValue(value) {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value !== "string" || !value.trim()) return null;
  const text = value.trim().replace(/^[−–]/u, "-");
  const match = text.match(/^([+-]?)\s*[$€£]?\s*((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?|\.\d+)\s*(%)?$/u);
  const number = match ? Number(`${match[1]}${match[2].replaceAll(",", "")}`) / (match[3] ? 100 : 1) : NaN;
  return Number.isFinite(number) ? number : null;
}

/** Compare numeric values before formatting; keep missing values last in either direction. */
export function compareTableValues(left, right, descending = false) {
  const missing = (value) => value == null || value === "" || typeof value === "number" && !Number.isFinite(value);
  if (missing(left) || missing(right)) return Number(missing(left)) - Number(missing(right));
  const a = numericValue(left);
  const b = numericValue(right);
  const comparison = a !== null && b !== null ? a - b
    : String(left).localeCompare(String(right), undefined, { numeric: true });
  return comparison * (descending ? -1 : 1);
}

// Color is an authored interpretation, separate from a value's numeric sign.
// An invalid explicit interpretation must not fall back to sign-based coloring.
export function resolveDeltaTone(tone, value, row, fallback) {
  if (tone === undefined) return fallback;
  try {
    const resolved = typeof tone === "function" ? tone(value, row) : tone;
    return ["positive", "negative", "neutral"].includes(resolved) ? resolved : "neutral";
  } catch {
    return "neutral";
  }
}

export function statusTone(value) {
  const status = String(value ?? "").toLowerCase();
  if (/\b(?:low|no)\s+risk\b|\brisk[ -]free\b/u.test(status)) return "positive";
  if (/\b(?:moderate|medium|warning|slipping)\b/u.test(status) || /^(?:due soon|investigating|mitigating)$/u.test(status)) return "warning";
  if (/\b(?:elevated|high|critical|risk|lost|churned|failed|cancelled|canceled|overdue)\b/u.test(status)) return "negative";
  if (/^(?:new|pending|monitoring)$/u.test(status)) return "info";
  return /^(?:low|retained|active|paid|healthy|complete|completed|success|stable|on track|using|used|resolved)$/u.test(status) ? "positive" : "neutral";
}

export function distributionBuckets(rows, field, maximum = 100) {
  const counts = Array(12).fill(0);
  for (const row of rows) {
    const value = numericValue(row[field]);
    if (value === null || value < 0 || value > maximum || maximum <= 0) continue;
    counts[Math.min(11, Math.floor(value / maximum * 12))] += 1;
  }
  const peak = Math.max(1, ...counts);
  return counts.map((count) => Math.max(10, count / peak * 100));
}

/** Right-inclusive percentile ranks, keyed by the original finite reviewed cell value. */
export function distributionPercentiles(rows, field) {
  const values = rows.map((row) => [row[field], numericValue(row[field])])
    .filter(([, value]) => value !== null).sort((a, b) => a[1] - b[1]);
  const ranks = new Map(values.map(([, value], index) =>
    [value, Math.round((index + 1) / values.length * 100)]));
  return new Map(values.map(([original, value]) => [original, ranks.get(value)]));
}
