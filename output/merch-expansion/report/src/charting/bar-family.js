// Serializable options for the bar presentations; rendering stays in the shared chart pipeline.
export const barPresentations = Object.freeze(["plot", "bullet", "segmented", "groupedList", "rankedList", "progress", "comparison", "rangePosition"]);
const optionKeys = ["orientation", "annotations", "target", "projection", "sort", "visibleRows", "expandable",
  "grid", "barCategoryGap", "categoryWidth", "valueWidth", "rangeLabelField", "unitField", "detailField"];
const styleKeys = ["color", "colorField", "textColor", "textColorField", "thickness", "thicknessField",
  "fontSize", "gap", "radius", "segmentGap", "roundedSegments", "segments"];
const labelKeys = ["value", "position", "align", "primary", "secondary", "suffix"];
const seriesKeys = ["key", "label", "color", "comparisonColor", "textColor", "stackId"];
const formatKeys = ["style", "currency", "notation", "minimumFractionDigits", "maximumFractionDigits"];
const scalar = value => typeof value === "string" || typeof value === "boolean" || Number.isFinite(value);
const record = value => value && typeof value === "object" && !Array.isArray(value);
const pick = (source, keys) => Object.fromEntries(keys.flatMap(key =>
  scalar(source?.[key]) ? [[key, source[key]]] : []));
const strings = (value, limit = 100) => Array.isArray(value) ? value.filter(item => typeof item === "string").slice(0, limit) : [];

export function projectBarOptions(options = {}) {
  const result = pick(options, optionKeys);
  for (const [key, keys] of [["style", styleKeys], ["labels", labelKeys], ["axes", ["category", "value"]],
    ["interaction", ["tooltip"]], ["format", formatKeys], ["track", ["max", "color"]]]) {
    if (record(options[key])) result[key] = pick(options[key], keys);
  }
  for (const key of ["axes", "track", "comparison"]) if (typeof options[key] === "boolean") result[key] = options[key];
  if (record(options.comparison)) result.comparison = { colors: strings(options.comparison.colors, 24) };
  if (Array.isArray(options.series)) result.series = options.series.slice(0, 24).map(series => ({
    ...pick(typeof series === "string" ? { key: series } : series, seriesKeys),
    ...(Array.isArray(series.colors) ? { colors: strings(series.colors) } : {}),
    ...(Array.isArray(series.textColors) ? { textColors: strings(series.textColors) } : {}),
  })).filter(series => series.key);
  if (Array.isArray(options.markers)) result.markers = options.markers.slice(0, 24)
    .filter(marker => Number.isFinite(marker?.value)).map(marker => pick(marker, ["value", "label", "color", "width"]));
  if (Array.isArray(options.tooltipFields)) result.tooltipFields = options.tooltipFields.slice(0, 10)
    .map(field => pick(field, ["key", "label", "color"])).filter(field => field.key);
  if (Array.isArray(options.range)) result.range = strings(options.range, 2);
  if (Array.isArray(options.domain) && options.domain.length === 2) {
    result.domain = options.domain.map(value => Number.isFinite(value) || ["auto", "dataMin", "dataMax"].includes(value) ? value : "auto");
  }
  return result;
}

/** Translate the original bar-family recipe vocabulary without changing its layout. */
export function barChartSpec(recipe = {}) {
  if (recipe.barOptions) return recipe;
  const { category, value, presentation = "plot", type, x, y, xLabel, ...options } = recipe;
  const barOptions = projectBarOptions(options);
  return { type: type ?? (options.orientation === "horizontal" ? "horizontalBar" : "bar"),
    x: x ?? category, y: y ?? value ?? barOptions.series?.[0]?.key,
    presentation, barOptions, ...(xLabel ? { xLabel } : {}) };
}

export function barValue(row, field) {
  const value = typeof field === "function" ? field(row) : row?.[field];
  return value == null || value === "" || !Number.isFinite(Number(value)) ? null : Number(value);
}

export function rangePosition(low, high, value) {
  if (![low, high, value].every(Number.isFinite) || high < low) return null;
  if (high === low) return value === low ? 50 : value < low ? 0 : 100;
  return Math.max(0, Math.min(100, (value - low) / (high - low) * 100));
}

// Check every proportional column, not just the overall chart width: even a wide
// chart can have a tiny segment or a long label that cannot fit its annotation.
export function segmentCalloutsFit(measurements) {
  return measurements.length > 0 && measurements.every(({ width, labelWidth, valueWidth }) =>
    width > 0 && labelWidth <= width && valueWidth <= width);
}

export function barPresentationIssue(rows, spec) {
  if (!barPresentations.includes(spec.presentation)) return "Unsupported bar presentation";
  const options = spec.barOptions ?? {};
  if (options.range && (options.range.length !== 2 || rows.some(row => {
    const [start, end] = options.range.map(field => barValue(row, field));
    return start != null && end != null && start > end;
  }))) return "Ranges require ordered start and end values";
  if (spec.presentation === "plot") return null;
  if (spec.presentation === "rangePosition") return options.range?.length === 2 ? null : "Range position requires low and high fields";
  if (options.style?.segments != null && (!Number.isInteger(options.style.segments) || options.style.segments < 2 || options.style.segments > 40)) return "Segment count must be an integer from 2 to 40";
  const fields = options.series?.length ? options.series.map(series => series.key) : [spec.y];
  if (spec.presentation === "bullet") fields.push(options.target, options.projection);
  if (rows.some(row => fields.some(field => barValue(row, field) < 0))) return "Use a bar plot for signed values";
  if (spec.presentation === "segmented" && rows.some(row => fields.some(field => barValue(row, field) === null))) {
    return "Composition requires complete segment values";
  }
  if (spec.presentation === "progress" && (!options.track?.max
    || rows.some(row => !(barValue(row, options.track.max) > 0)))) return "Progress requires a positive goal for each row";
  return null;
}
