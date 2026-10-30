import { maximumValue } from "./chart-extrema.js";
import { chromeContrastRatio, parseChromeColor } from "../chrome-contrast.js";
export const chartTypes = [
  "line",
  "area",
  "stackedArea",
  "bar",
  "horizontalBar",
  "stackedBar",
  "stackedBar100",
  "horizontalStackedBar",
  "horizontalStackedBar100",
  "histogram",
  "scatter",
  "heatmap",
  "pie",
  "leaderboard",
  "rankedList",
  "sparkline",
  "funnel",
  "waterfall",
  "boxPlot",
  "sankey",
];

export const colors = Array.from({ length: 8 }, (_, index) => `var(--chart-${index + 1})`);
const categoricalPaletteOrder = [0, 12, 6, 18, 3, 15, 9, 21, 1, 13, 7, 19, 4, 16, 10, 22, 2, 14, 8, 20, 5, 17, 11, 23];
const categoryColors = Array.from(
  { length: categoricalPaletteOrder.length },
  (_, index) => `oklch(from var(--chart-1) l max(c, 0.16) calc(h + ${categoricalPaletteOrder[index] * 15}))`,
);

function reservedConceptColor(value = "") {
  const words = String(value)
    .replace(/([a-z])([A-Z])/gu, "$1 $2")
    .replaceAll("_", " ")
    .trim()
    .toLocaleLowerCase();
  if (/^active\s+(?:users?|accounts?)$/u.test(words)) return colors[0];
  if (/\b(?:resurrected|reactivated|returning)\b/u.test(words)) return colors[2];
  if (/\bretained\b/u.test(words)) return colors[0];
  if (/\bnew(?:\s+users?)?\b/u.test(words)) return colors[4];
  if (/\b(?:churned|churn)\b/u.test(words)) return "var(--negative)";
  if (/^(?:dau|daily active users?)$/u.test(words)) return categoryColors[0];
  if (/^(?:wau|weekly active users?)$/u.test(words)) return categoryColors[1];
  if (/^(?:mau|monthly active users?)$/u.test(words)) return categoryColors[2];
  if (/\bapproved\b/u.test(words)) return "var(--positive)";
  if (/\b(?:denied|rejected)\b/u.test(words)) return "var(--negative)";
  if (/\bfailed\b/u.test(words)) return "color-mix(in oklch, var(--negative) 72%, var(--chart-7))";
  if (/\btimed?\s*out\b/u.test(words)) return "color-mix(in oklch, var(--chart-6) 72%, var(--chart-5))";
  if (/\bdraft\b/u.test(words)) return "var(--secondary)";
  if (/\bopen\b/u.test(words)) return colors[0];
  if (/\bclosed\b/u.test(words)) return colors[2];
  return undefined;
}

/** Keep a concept on the same palette token even when its local series order changes. */
export function semanticColor({ field, dimension, value, index = 0, explicitColor } = {}) {
  if (typeof explicitColor === "string" && explicitColor.trim()) return explicitColor;
  const identity =
    value == null || value === "" ? String(field ?? "") : `${String(dimension ?? field ?? "")}:${String(value)}`;
  if (!identity) return colors[Math.abs(Number(index) || 0) % colors.length];
  let hash = 0;
  for (const character of identity.toLocaleLowerCase()) {
    hash = (Math.imul(31, hash) + character.codePointAt(0)) | 0;
  }
  return colors[(hash >>> 0) % colors.length];
}

/** Collect only distinct dimension values and measure fields, never reviewed rows. */
export function createSemanticColorMetadataAccumulator() {
  const dimensions = new Map();
  const dimensionGroups = [];
  const measureGroups = [];
  const addQuery = (rows, payloadColumns) => {
    const payloadFields = Array.isArray(payloadColumns) ? new Set(payloadColumns) : null;
    const queryDimensions = new Map();
    const queryMeasures = new Set();
    for (const row of rows) {
      for (const [field, value] of Object.entries(row)) {
        if (typeof value === "number" && Number.isFinite(value)) {
          queryMeasures.add(field);
          continue;
        }
        if (
          typeof value !== "string" ||
          payloadFields?.has(field) ||
          !value ||
          value.toLowerCase() === "all" ||
          /^(?:\d{4}-\d{2}-\d{2}|https?:)/u.test(value)
        )
          continue;
        if (!dimensions.has(field)) dimensions.set(field, new Set());
        dimensions.get(field).add(value);
        if (!queryDimensions.has(field)) queryDimensions.set(field, new Set());
        queryDimensions.get(field).add(value);
      }
    }
    dimensionGroups.push(queryDimensions);
    measureGroups.push(queryMeasures);
  };
  const finish = () => {
    const assignments = new Map();
    for (const [dimension] of dimensions) {
      const containsCountries = [...dimensions.get(dimension)].filter((value) => /^[A-Z]{2}$/u.test(value)).length >= 3;
      const palette = semanticCategoryDimension(dimension) || containsCountries ? categoryColors : colors;
      for (const group of dimensionGroups) {
        const values = [...(group.get(dimension) ?? [])].sort((left, right) => left.localeCompare(right));
        const used = new Set(
          values.map((value) => palette.indexOf(assignments.get(`${dimension}:${value}`))).filter((slot) => slot >= 0),
        );
        for (const value of values) {
          const identity = `${dimension}:${value}`;
          if (assignments.has(identity)) continue;
          let slot = colors.indexOf(semanticColor({ dimension, value }));
          if (used.size < palette.length) {
            while (used.has(slot)) slot = (slot + 1) % palette.length;
            used.add(slot);
          }
          assignments.set(identity, palette[slot]);
        }
      }
    }
    const measureAssignments = new Map();
    for (const group of measureGroups) {
      const fields = [...group].sort((left, right) => left.localeCompare(right));
      const used = new Set(
        fields.map((field) => categoryColors.indexOf(measureAssignments.get(field))).filter((slot) => slot >= 0),
      );
      for (const field of fields) {
        if (measureAssignments.has(field)) continue;
        let slot = colors.indexOf(semanticColor({ field }));
        if (used.size < categoryColors.length) {
          while (used.has(slot)) slot = (slot + 1) % categoryColors.length;
          used.add(slot);
        }
        measureAssignments.set(field, categoryColors[slot]);
      }
    }
    const categoryFields = new Map();
    for (const [dimension, values] of dimensions) {
      for (const value of values) {
        categoryFields.set(value, categoryFields.has(value) ? null : assignments.get(`${dimension}:${value}`));
      }
    }
    return { version: 1, assignments: [...assignments], measureAssignments: [...measureAssignments],
      categoryFields: [...categoryFields].filter(([, color]) => color !== null) };
  };
  return { addQuery, finish };
}

export function semanticColorMetadata(queries = {}) {
  const accumulator = createSemanticColorMetadataAccumulator();
  for (const query of Object.values(queries)) accumulator.addQuery(query?.rows ?? [], query?.payloadColumns);
  return accumulator.finish();
}

/** Allocate the same reviewed palette before filtering, including deferred queries. */
export function semanticColorResolver(queries = {}, precomputedMetadata = null) {
  const metadata = precomputedMetadata ?? semanticColorMetadata(queries);
  if (metadata.version !== 1) throw new Error("Unsupported semantic color metadata.");
  const assignments = new Map(metadata.assignments);
  const measureAssignments = new Map(metadata.measureAssignments);
  const categoryFields = new Map(metadata.categoryFields);
  const dynamicAssignments = new Map();
  const dynamicColor = (dimension, value) => {
    const key = `${dimension}:${value}`;
    if (assignments.has(key)) return assignments.get(key);
    if (dynamicAssignments.has(key)) return dynamicAssignments.get(key);
    const palette = semanticCategoryDimension(dimension) ? categoryColors : colors;
    const used = new Set(
      [...assignments, ...dynamicAssignments]
        .filter(([identity]) => identity.startsWith(`${dimension}:`))
        .map(([, color]) => palette.indexOf(color))
        .filter((index) => index >= 0),
    );
    let slot = colors.indexOf(semanticColor({ dimension, value }));
    while (used.has(slot) && used.size < palette.length) slot = (slot + 1) % palette.length;
    const selected = palette[slot];
    dynamicAssignments.set(key, selected);
    return selected;
  };
  return (descriptor = {}) => {
    if (descriptor.explicitColor) return descriptor.explicitColor;
    const reserved = reservedConceptColor(descriptor.value ?? descriptor.field);
    if (reserved) return reserved;
    if (descriptor.value != null && descriptor.value !== "") {
      return dynamicColor(descriptor.dimension ?? descriptor.field ?? "category", descriptor.value);
    }
    return descriptor.field
      ? categoryFields.get(descriptor.field) ??
          measureAssignments.get(descriptor.field) ??
          dynamicColor("category", descriptor.field)
      : semanticColor(descriptor);
  };
}

export function semanticCategoryDimension(field = "") {
  const words = String(field)
    .replace(/([a-z])([A-Z])/gu, "$1 $2")
    .replaceAll("_", " ");
  return /\b(?:plans?|products?|segments?|features?|experiences?|cohorts?|channels?|categor(?:y|ies)|dimensions?|buckets?|status(?:es)?|states?|stages?|countr(?:y|ies)|geograph(?:y|ies)|actions?|surfaces?|lifecycles?|drivers?)\b/iu.test(
    words,
  );
}

export function ratioMetric(field = "", values = []) {
  // Relative change can cross zero or exceed 100% without changing its unit.
  const relativeChange = /(?:growth|change|delta|variance).*?(?:rate|ratio|percent|percentage)$/iu.test(String(field));
  return (
    /(?:ratio|rate|conversion|retention|percent|percentage|share|penetration|adoption)$/iu.test(String(field)) &&
    values.some((value) => Number.isFinite(value)) &&
    values.every((value) => !Number.isFinite(value) || relativeChange || (value >= 0 && value <= 1))
  );
}

export function deltaDirection(field, value) {
  const words = String(field)
    .replace(/([a-z])([A-Z])/gu, "$1 $2")
    .replaceAll("_", " ");
  if (!/\b(?:delta|change|variance|growth|difference|diff|movement)(?:\b|\d)/iu.test(words)) return "";
  const normalized =
    typeof value === "number"
      ? value
      : Number(
          String(value)
            .trim()
            .replace(/[,$€£%\s]/gu, "")
            .replace(/^[−–]/u, "-")
            .replace(/[KMBT]$/iu, ""),
        );
  return Number.isFinite(normalized) && normalized !== 0 ? (normalized < 0 ? "negative" : "positive") : "";
}

export const compact = (value) =>
  new Intl.NumberFormat(undefined, {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value);

const numericTickValues = (values) =>
  [...new Set(values.filter(Number.isFinite).map((value) => (value === 0 ? 0 : value)))].sort(
    (left, right) => left - right,
  );

/** Keep all observed tick values until the axis domain or formatting mode changes. */
export function mergeNumericAxisTicks(previous, key, values) {
  const merged = numericTickValues([...(previous?.key === key ? previous.values : []), ...values]);
  const signature = JSON.stringify(merged);
  return previous?.key === key && previous.signature === signature ? previous : { key, values: merged, signature };
}

/** Axis-only precision; KPI, mark, and tooltip formatting remains independent. */
export function numericAxisFormatter(tickValues = [], { percent = false, percentDigits, locale, currency } = {}) {
  const values = numericTickValues(tickValues);
  const style = percent ? { style: "percent" } : /^[A-Z]{3}$/.test(currency ?? "") ? {style:"currency",currency,minimumFractionDigits:0} : {};
  const zero = new Intl.NumberFormat(locale, { ...style, maximumFractionDigits: 0 }).format(0);
  const formatter = (options) => {
    const number = new Intl.NumberFormat(locale, { ...style, signDisplay: "exceptZero", ...options });
    return (value) =>
      !Number.isFinite(value)
        ? ""
        : value === 0
          ? zero
          : number
              .formatToParts(value)
              .filter((part) => part.type !== "plusSign")
              .map((part) => part.value)
              .join("");
  };
  if (percent && Number.isInteger(percentDigits)) {
    return formatter({ minimumFractionDigits: percentDigits, maximumFractionDigits: percentDigits });
  }
  const distinct = (format) => new Set(values.map(format)).size === values.length;
  const readable = (format) => values.every((value) => format(value).length <= 24);
  const exact = formatter({ maximumSignificantDigits: 21 });
  const scientific = formatter({ notation: "scientific", maximumSignificantDigits: 21 });
  // Before Recharts reports its ticks, do not round unknown nearby values together.
  if (values.length < 2)
    return (value) => {
      const label = exact(value);
      return label.length <= 24 ? label : scientific(value);
    };

  const maxAbs = maximumValue(values.map(Math.abs));
  const notation = percent || maxAbs < 10_000 ? "standard" : "compact";
  const maximum = notation === "compact" ? 3 : 12;
  for (let digits = 1; digits <= maximum; digits += 1) {
    const format = formatter({ notation, maximumFractionDigits: digits });
    if (distinct(format) && readable(format)) return format;
  }
  // Narrow large-value domains are clearer as grouped numbers than long compact decimals.
  if (notation === "compact") {
    for (let digits = 0; digits <= 12; digits += 1) {
      const format = formatter({ maximumFractionDigits: digits });
      if (distinct(format) && readable(format)) return format;
    }
  }
  if (distinct(exact) && readable(exact)) return exact;
  for (let digits = 3; digits <= 21; digits += 1) {
    const format = formatter({ notation: "scientific", maximumSignificantDigits: digits });
    if (distinct(format)) return format;
  }
  return scientific;
}

export function wholePercentTicks(domain, tickCount = 5) {
  if (!Array.isArray(domain) || domain.length !== 2 || !domain.every(Number.isFinite)) return [];
  const [minimum, maximum] = [...domain].sort((left, right) => left - right).map((value) => value * 100);
  if (minimum === maximum) return [minimum / 100];
  const target = Math.max(1, (maximum - minimum) / Math.max(1, tickCount - 1));
  const magnitude = 10 ** Math.floor(Math.log10(target));
  const normalized = target / magnitude;
  const multiplier = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 2.5 ? 2.5
    : normalized <= 5 ? 5 : 10;
  const step = Math.max(1, multiplier * magnitude);
  const start = Math.ceil(minimum / step) * step;
  const end = Math.floor(maximum / step) * step;
  const ticks = [];
  for (let value = start; value <= end + step / 100; value += step) ticks.push(value / 100);
  return ticks;
}

export function displayValue(value) {
  if (value == null || value === "") return "—";
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}(?:T|$)/u.test(value)) {
    const date = new Date(value.length === 10 ? `${value}T00:00:00Z` : value);
    if (!Number.isNaN(date.valueOf()))
      return new Intl.DateTimeFormat(undefined, {
        month: "short",
        day: "numeric",
        year: "numeric",
        timeZone: "UTC",
      }).format(date);
  }
  if (typeof value !== "number" || !Number.isFinite(value)) return String(value);
  if (Math.abs(value) >= 10_000) return compact(value);
  return new Intl.NumberFormat(undefined, {
    maximumFractionDigits: 2,
    minimumFractionDigits: Number.isInteger(value) ? 0 : Math.abs(value) < 1 ? 2 : 0,
  }).format(value);
}

export const percentage = (value) =>
  new Intl.NumberFormat(undefined, {
    style: "percent",
    maximumFractionDigits: 1,
    signDisplay: "exceptZero",
  }).format(value);

export function periodComparison(
  current,
  previous,
  { percentagePoints = false, lowerIsBetter = false, previousPeriod = "previous reporting period", includePeriod = true } = {},
) {
  if (!Number.isFinite(current) || !Number.isFinite(previous) || (!percentagePoints && previous === 0)) return {};
  const change = percentagePoints ? current - previous : (current - previous) / Math.abs(previous);
  const formatted = percentagePoints
    ? `${new Intl.NumberFormat(undefined, {
        maximumFractionDigits: 1,
        signDisplay: "exceptZero",
      }).format(change * 100)} pp`
    : percentage(change);
  return {
    comparison: includePeriod ? `${formatted} vs. ${dateValue(previousPeriod) ? shortDate(previousPeriod) : previousPeriod}` : formatted,
    negative: lowerIsBetter ? change > 0 : change < 0,
  };
}

function dateValue(value) {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}(?:T|$)/u.test(value);
}

export const shortDate = (value) =>
  new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  }).format(new Date(value));

export const label = (field = "") =>
  String(field)
    .replace(/([a-z\d])([A-Z])/gu, "$1 $2")
    .replaceAll("_", " ")
    .replace(/\b(?:arr|mau|wau|dau|api|sql|kpi|cli|ide|mcp|p50|p95|p99)\b/giu, (abbreviation) =>
      abbreviation.toUpperCase(),
    )
    .replace(/^./u, (character) => character.toUpperCase());

export function categoryLabel(field = "", value = "") {
  const raw = String(value);
  const dimension = String(field)
    .replace(/([a-z])([A-Z])/gu, "$1 $2")
    .replaceAll("_", " ");
  if (/\b(?:country|countries|geography)\b/iu.test(dimension) && /^[A-Z]{2}$/u.test(raw)) {
    try {
      return new Intl.DisplayNames(undefined, { type: "region" }).of(raw) ?? raw;
    } catch {
      return raw;
    }
  }
  if (dateValue(raw)) return shortDate(raw);
  // Humanize identifiers, but preserve display-ready category casing (iOS, ChatGPT, etc.).
  const reviewed = (raw.includes("_") || raw === raw.toLowerCase() ? label(raw) : raw)
    .replace(/\bSelf serve\b/iu, "Self-serve")
    .replace(/\busage based\b/iu, "usage-based")
    .replace(/\bEdu\b/iu, "Education")
    .replace(/\bCbp\s+/iu, "");
  return /\bskill\b/iu.test(dimension) ? reviewed.replace(/^Data-analytics:/iu, "") : reviewed;
}

export const tick = (value, { includeYear = false } = {}) => {
  if (typeof value !== "string") return value;
  const month = /^\d{4}-(?:0[1-9]|1[0-2])$/u.test(value);
  if (!month && !/^\d{4}-\d{2}-\d{2}(?:T|$)/u.test(value)) return value;
  const date = new Date(month ? `${value}-01T00:00:00Z` : value);
  if (!Number.isFinite(date.getTime())) return value;
  return date.toLocaleDateString("en-US", { month: "short", ...(month ? {} : { day: "numeric" }),
    ...(month || includeYear ? { year: "numeric" } : {}), timeZone: "UTC" });
};
// Anchor the first stage to the unmodified core hue; tint only later stages.
export function funnelStageColor(color, index, count, active = false) {
  if (index === 0) return active ? `color-mix(in srgb, ${color} 92%, var(--text))` : color;
  const strength = Math.min(100, Math.round(100 - index / Math.max(1, count - 1) * 76) + (active ? 8 : 0));
  return `color-mix(in srgb, ${color} ${strength}%, var(--surface))`;
}


export function percentageAxisMode(fields, rows) {
  if (fields.length && fields.every(field => /\(%\)$/.test(field))) return "points";
  return fields.length > 0 && fields.every(field => ratioMetric(field, rows.map(row => row[field])));
}

export function formatChartValue(value, field, { ratio = false, compactValue = false, decimals = 1, currency } = {}) {
  if (value == null || value === "" || !Number.isFinite(Number(value))) return "—";
  const points = /\(%\)$/.test(field);
  if (points || ratio) return new Intl.NumberFormat(undefined, { style: "percent", maximumFractionDigits: decimals })
    .format(Number(value) / (points ? 100 : 1));
  if (/^[A-Z]{3}$/.test(currency ?? "") || /(?:Usd|\(USD\))$/i.test(field)) return new Intl.NumberFormat(undefined, { style: "currency", currency: /^[A-Z]{3}$/.test(currency ?? "") ? currency : "USD",
    notation: compactValue ? "compact" : "standard", maximumFractionDigits: compactValue ? 1 : currency ? decimals : 0 }).format(Number(value));
  return compactValue ? compact(Number(value)) : displayValue(value);
}

export function comparisonSeriesBase(field, fields) {
  const plain = String(field).replace(/^previous\s*/i, "").replace(/\s*[·-]?\s*previous$/i, "");
  return fields.find(candidate => String(candidate).toLowerCase() === plain.toLowerCase()) ?? field;
}

export function heatmapTextColor(fill) {
  const color = parseChromeColor(fill);
  if (!color) return "var(--text)";
  return chromeContrastRatio([255,255,255,1], color) > chromeContrastRatio([0,0,0,1], color) ? "white" : "black";
}


export function compactChartLabel(field) {
  return label(String(field).replace(/^previous\s*/i, "").replace(/\s*[·-]?\s*previous$/i, ""))
    .replace(/\s*\((?:USD|%)\)$/i, "");
}
export function heatmapFill(base, intensity) {
  return `color-mix(in srgb, ${base} ${Math.max(12, intensity * 100)}%, var(--surface))`;
}

export function compactAxisCategory(value, capacity) {
  if (value.length <= capacity) return value;
  const words = value.split(/\s+/u);
  if (words.length > 1) {
    const prefix = words.slice(0, -1).map((word) => `${word[0]}.`).join(" ") + " ";
    const suffix = words.at(-1);
    const combined = prefix + suffix;
    if (combined.length <= capacity) return combined;
    if (capacity - prefix.length >= 3) return `${prefix}${suffix.slice(0, capacity - prefix.length - 1)}…`;
  }
  return `${value.slice(0, capacity - 1).trimEnd()}…`;
}
