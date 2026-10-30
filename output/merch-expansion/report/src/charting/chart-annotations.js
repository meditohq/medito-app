import { displayValue, label } from "./chart-theme.js";

export const maxChartAnnotations = 8;
export const annotationChartTypes = Object.freeze(["line", "area", "bar", "horizontalBar"]);

// Axis identity is renderer state, not part of the authored annotation schema.
export function bindChartAnnotationAxes(annotations, rightFields = []) {
  return annotations.map((annotation) => ({ ...annotation,
    valueAxisId: rightFields.includes(annotation.kind === "benchmark" ? annotation.measure
      : annotation.kind === "point" ? annotation.field : undefined) ? "secondary" : 0,
  }));
}

// Give an edge benchmark room for its explanation without changing chart height,
// reviewed rows, or zero. Interior benchmarks and bounded ratios keep their axes.
export function benchmarkAnnotationDomain(values, domain, height, startAtZero = true, ratio = false) {
  domain = domain.filter(Number.isFinite);
  if (ratio || !values.length || !Number.isFinite(height) || !domain.length) return undefined;
  const fraction = Math.min(0.3, 60 / Math.max(1, height - 40));
  const minimum = Math.min(...domain), maximum = Math.max(...domain);
  const low = startAtZero ? Math.min(0, minimum) : minimum;
  const high = startAtZero ? Math.max(0, maximum) : maximum, span = high - low;
  if (!Number.isFinite(span) || span <= 0) return undefined;
  const padding = span * fraction / (1 - fraction);
  const next = [low < 0 && values.some(value => value >= low && value <= low + span * 0.3) ? low - padding : low,
    high > 0 && values.some(value => value <= high && value >= high - span * 0.3) ? high + padding : high];
  return next.every(Number.isFinite) && (next[0] !== low || next[1] !== high) ? next : undefined;
}

const keysByKind = {
  benchmark: ["id", "kind", "label", "field", "measure", "at"],
  event: ["id", "kind", "label", "field", "at"],
  range: ["id", "kind", "label", "at", "end"],
  point: ["id", "kind", "label", "field", "at"],
};
const plainObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value)
  && [Object.prototype, null].includes(Object.getPrototypeOf(value));
const textValue = (value, limit) => typeof value === "string" && value.trim().length > 0
  && value.length <= limit && !/[\u0000-\u001f\u007f]/u.test(value);
const anchorValue = (value) => textValue(value, 300) || (typeof value === "number" && Number.isFinite(value));
const owns = (value, key) => value != null && Object.hasOwn(value, key);
const cell = (row, field) => owns(row, field) ? row[field] : undefined;
const readable = (value, limit = 200) => {
  const text = String(value).replace(/[\u0000-\u001f\u007f]+/gu, " ").trim();
  return text.length > limit ? `${text.slice(0, limit - 3)}...` : text;
};
const exactNumber = (value) => new Intl.NumberFormat(undefined, { maximumSignificantDigits: 21 }).format(value);
const readableAnchor = (value) => readable(displayValue(value));

function temporalValue(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})?)?$/u.test(value)) return null;
  const day = value.slice(0, 10);
  const dayTime = Date.parse(`${day}T00:00:00Z`);
  const time = Date.parse(value);
  return Number.isFinite(dayTime) && new Date(dayTime).toISOString().slice(0, 10) === day
    && Number.isFinite(time) ? time : null;
}

/** A small authored contract: references to reviewed fields, never supplied data values or rows. */
export function normalizeChartAnnotations(value) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > maxChartAnnotations) {
    throw new Error(`Chart annotations must be a list of at most ${maxChartAnnotations} entries.`);
  }
  const ids = new Set();
  return value.map((entry) => {
    if (!plainObject(entry) || typeof entry.kind !== "string" || !owns(keysByKind, entry.kind)) throw new Error("Invalid chart annotation kind.");
    const allowed = keysByKind[entry.kind];
    if (Object.keys(entry).some((key) => !allowed.includes(key))) {
      throw new Error("Chart annotations contain unsupported fields.");
    }
    if (!textValue(entry.id, 100) || !textValue(entry.label, 160)) {
      throw new Error("Chart annotations require bounded, nonempty IDs and labels.");
    }
    const id = entry.id.trim();
    if (ids.has(id)) throw new Error("Chart annotation IDs must be unique.");
    ids.add(id);
    const result = { id, kind: entry.kind, label: entry.label.trim() };
    if (entry.kind !== "range") {
      if (!textValue(entry.field, 200)) throw new Error("Chart annotations require a reviewed field.");
      result.field = entry.field;
    }
    if (entry.kind === "benchmark") {
      if (!textValue(entry.measure, 200)) throw new Error("Chart benchmarks require their plotted measure.");
      result.measure = entry.measure;
    }
    if (entry.kind !== "benchmark" || owns(entry, "at")) {
      if (!anchorValue(entry.at)) throw new Error("Chart annotations require an exact x-domain anchor.");
      result.at = entry.at;
    }
    if (entry.kind === "event" && temporalValue(entry.at) === null) {
      throw new Error("Chart event annotations require an exact temporal anchor.");
    }
    if (entry.kind === "range") {
      const start = temporalValue(entry.at);
      const end = temporalValue(entry.end);
      if (start === null || end === null || end <= start) {
        throw new Error("Chart annotation ranges require ascending, exact temporal anchors.");
      }
      result.end = entry.end;
    }
    return result;
  });
}

/** Declared field dependencies; pivoted point-series names need mapping by chartDataShape. */
export function chartAnnotationFields(value) {
  return [...new Set(normalizeChartAnnotations(value).map((entry) => entry.field).filter(Boolean))];
}

function uniqueNumber(rows, field) {
  if (!rows.length) return undefined;
  const values = rows.map((row) => cell(row, field));
  const first = values[0];
  return Number.isFinite(first) && values.every((value) => value === first) ? first : undefined;
}

/**
 * Resolve against the exact current reviewed rows and rendered data. Missing or
 * ambiguous evidence omits the mark; it never picks a nearby date or invents a value.
 */
export function resolveChartAnnotations(spec, reviewedRows, { data = reviewedRows, visibleFields } = {}) {
  const annotations = normalizeChartAnnotations(spec.annotations);
  if (spec.showAnnotations === false || !annotationChartTypes.includes(spec.type) || !annotations.length || !data.length) return [];
  const xField = spec.x;
  const xDomain = new Set(data.map((row) => cell(row, xField)).filter(anchorValue));
  const allSeries = spec.series
    ? [...new Set(reviewedRows.map((row) => cell(row, spec.series)).filter((value) => value != null))]
    : [];
  const plottedFields = allSeries.length ? allSeries : spec.fields ?? [spec.y];
  const visible = new Set((visibleFields ?? plottedFields).map(String));
  if (!visible.size) return [];
  const rows = reviewedRows.filter((row) => xDomain.has(cell(row, xField))
    && (!allSeries.length || visible.has(String(cell(row, spec.series)))));
  const atRows = (at) => rows.filter((row) => cell(row, xField) === at);
  const resolved = [];

  for (const annotation of annotations) {
    const { kind, field, at } = annotation;
    if (owns(annotation, "at") && !xDomain.has(at)) continue;
    if (kind === "benchmark") {
      if (!visible.has(annotation.measure) || !plottedFields.some((value) => String(value) === annotation.measure)
        || spec.type === "line" && spec.barFields?.includes(annotation.measure)) continue;
      const evidenceRows = owns(annotation, "at") ? atRows(at) : rows;
      const value = uniqueNumber(evidenceRows, field);
      if (value === undefined) continue;
      resolved.push({ ...annotation, y: value, evidence: `${label(field)} = ${exactNumber(value)}${owns(annotation, "at") ? ` at ${readableAnchor(at)}` : " across the plotted reviewed rows"}` });
    } else if (kind === "event") {
      const evidenceValues = atRows(at).map((row) => cell(row, field))
        .filter((value) => value === true || (typeof value === "string" && value.trim()));
      if (!evidenceValues.length) continue;
      const values = [...new Set(evidenceValues.map((value) => typeof value === "string" ? value.trim() : value))];
      if (values.length !== 1) continue;
      const detail = values[0] === true ? "Confirmed" : readable(values[0]);
      resolved.push({ ...annotation, x: at, evidence: `${label(field)} at ${readableAnchor(at)}: ${detail}` });
    } else if (kind === "range") {
      const domain = [...xDomain];
      const times = domain.map(temporalValue);
      if (["bar", "horizontalBar"].includes(spec.type) && ["ascending", "descending"].includes(spec.sortOrder)) continue;
      // Categorical marks keep input order; a shuffled date must not enter the shaded interval.
      if (!xDomain.has(annotation.end) || !times.every((value, index) => value !== null && (!index || value >= times[index - 1]))
        || domain.indexOf(at) >= domain.indexOf(annotation.end)) continue;
      resolved.push({ ...annotation, x: at, xEnd: annotation.end, evidence: `${label(xField)}: ${readableAnchor(at)} to ${readableAnchor(annotation.end)}` });
    } else if (kind === "point") {
      if (!visible.has(String(field)) || !plottedFields.some((value) => String(value) === field)) continue;
      if (["bar", "horizontalBar"].includes(spec.type) && visible.size !== 1) continue;
      if (spec.type === "line" && spec.barFields?.includes(field)) continue;
      const evidenceRows = allSeries.length
        ? atRows(at).filter((row) => String(cell(row, spec.series)) === field)
        : atRows(at);
      const value = uniqueNumber(evidenceRows, allSeries.length ? spec.y : field);
      if (value === undefined || uniqueNumber(data.filter((row) => cell(row, xField) === at), field) !== value) continue;
      resolved.push({ ...annotation, x: at, y: value, evidence: `${label(field)} = ${exactNumber(value)} at ${readableAnchor(at)}` });
    }
  }
  return resolved;
}
