import { chartTypes } from "./chart-theme.js";

const fieldName = (value) => typeof value === "string" && value.trim().length > 0;
const wideMeasureTypes = ["line", "sparkline", "area", "stackedArea", "bar", "horizontalBar",
  "horizontal-bar", "stackedBar", "stackedBar100", "horizontalStackedBar", "horizontalStackedBar100"];

/** Validate raw bindings before projection can silently discard malformed values. */
export function getChartSpecError(spec, { id, partial = false } = {}) {
  const invalid = (message) => `Invalid chart${id ? ` ${JSON.stringify(id)}` : ""}: ${message}`;
  if (spec === null || typeof spec !== "object" || Array.isArray(spec)) {
    return invalid("chart must be a configuration object.");
  }
  if ((!partial || Object.hasOwn(spec, "type")) && !chartTypes.includes(spec.type) && spec.type !== "horizontal-bar") {
    return invalid(`chart.type must be one of: ${chartTypes.join(", ")}.`);
  }
  if (Array.isArray(spec.y)) {
    const fields = spec.y.length && spec.y.length <= 40 && spec.y.every(fieldName) ? spec.y : ["measureA", "measureB"];
    return invalid(`chart.y must be a single field name, not an array. For multiple measures, use y: ${JSON.stringify(fields[0])}, fields: ${JSON.stringify(fields)}.`);
  }
  // Existing wide-form charts may bind all measures through fields or a bar recipe.
  const hasMeasureList = wideMeasureTypes.includes(spec.type)
    && (spec.fields?.length || spec.presentation && spec.barOptions?.series?.length);
  if (((!partial && !hasMeasureList) || (Object.hasOwn(spec, "y") && spec.y !== undefined)) && !fieldName(spec.y)) {
    return invalid("chart.y must be a nonempty string field name.");
  }
  const requiresX = !["histogram", "sankey"].includes(spec.type);
  if (((!partial && requiresX) || (spec.x != null && spec.x !== "")) && !fieldName(spec.x)) {
    return invalid("chart.x must be a nonempty string field name.");
  }
  for (const key of ["series", "source", "target"]) {
    if (spec[key] != null && spec[key] !== "" && !fieldName(spec[key])) {
      return invalid(`chart.${key} must be a single string field name.`);
    }
  }
  for (const key of ["fields", "barFields", "stages"]) {
    if (spec[key] == null) continue;
    // An empty combination list clears bars; an empty measure/stage list cannot plot anything.
    if (!Array.isArray(spec[key]) || (key !== "barFields" && !spec[key].length)) {
      return invalid(`chart.${key} must be a field list${key === "barFields" ? "" : " with at least one field"}.`);
    }
    if (!spec[key].every(fieldName)) {
      return invalid(`chart.${key} must contain only nonempty string field names.`);
    }
  }
  if (!partial && spec.type === "sankey" && (spec.stages ?? [spec.source ?? spec.x, spec.target ?? spec.series]).filter(Boolean).length < 2) {
    return invalid("a Sankey chart needs at least two stage fields, using chart.stages or chart.source and chart.target.");
  }
  // This contract is independent of row values: zero, null and empty reviewed data are valid.
  return null;
}

export function assertChartSpec(spec, options) {
  const error = getChartSpecError(spec, options);
  if (error) throw new Error(error);
}
