import { chartTypes } from "./chart-theme.js";

const continuousFields = new Set(["xLabel", "yLabel", "title", "description"]);
const record = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

function copy(value) {
  if (Array.isArray(value)) return value.map(copy);
  if (record(value)) return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, copy(child)]));
  return value;
}

function ordered(value) {
  if (Array.isArray(value)) return value.map(ordered);
  if (record(value))
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, ordered(value[key])]),
    );
  return value;
}

// Expand defaults only for comparison. The stored draft and reset value retain
// the exact authored chart spec, including deliberately omitted properties.
export function normalizeChartEditorSpec(chart = {}) {
  return {
    ...chart,
    fields: chart.fields ?? [chart.y].filter(Boolean),
    series: chart.series ?? "",
    showXAxisLabel: chart.showXAxisLabel ?? true,
    showYAxisLabel: chart.showYAxisLabel ?? true,
    startAtZero: chart.startAtZero ?? true,
    showValues: chart.showValues ?? false,
    showLegend: chart.showLegend ?? true,
    sortOrder: chart.sortOrder ?? (["leaderboard", "rankedList"].includes(chart.type) ? "descending" : "original"),
    colors: chart.colors ?? {},
  };
}

export function chartEditorSpecsEqual(left, right) {
  return (
    JSON.stringify(ordered(normalizeChartEditorSpec(left))) === JSON.stringify(ordered(normalizeChartEditorSpec(right)))
  );
}

export function changeChartEditorSpec(spec, field, value, { columns } = {}) {
  const clearsSeries = field === "x" && value === spec.series;
  const changesSeries = clearsSeries || (field === "series" && value !== (spec.series ?? ""));
  // A split temporarily hides wide-form measures. Keep their entire authored
  // list only when every name is a real reviewed column; partial matches may
  // instead be coincidentally named pivot labels from a long-form chart.
  const retainedFields =
    changesSeries &&
    Array.isArray(columns) &&
    Array.isArray(spec.fields) &&
    spec.fields.length > 0 &&
    spec.fields.every((candidate) => columns.includes(candidate))
      ? spec.fields
      : [spec.y];
  return {
    ...spec,
    [field]: value,
    ...(field === "y" ? { fields: [value] } : {}),
    ...(changesSeries ? { fields: retainedFields } : {}),
    ...(clearsSeries ? { series: "" } : {}),
    ...(field === "xLabel" ? { showXAxisLabel: Boolean(value.trim()) } : {}),
    ...(field === "yLabel" ? { showYAxisLabel: Boolean(value.trim()) } : {}),
  };
}

export function availableChartTypes(chart) {
  return chartTypes.filter((type) => type !== "leaderboard"
    && (chart.stackable !== false || type === chart.type || !type.toLowerCase().includes("stacked")));
}

export function chartEditorChoices(originalChart, spec, { columns, numeric }, capabilities = {}) {
  const restrict = (choices, allowed) =>
    allowed === undefined
      ? choices
      : Array.isArray(allowed)
        ? choices.filter((choice) => allowed.includes(choice))
        : [];
  const categorical = columns.filter((field) => !numeric.includes(field));
  const supportedTypes = availableChartTypes(originalChart);
  return {
    availableTypes: restrict(supportedTypes, capabilities.types),
    fieldsEditable: capabilities.fieldsEditable !== false,
    xFields: restrict(columns, capabilities.xFields),
    // Explicit policies know the authored roles, including all-null measures
    // and numeric categories. Still intersect them with approved row columns.
    yFields: restrict(capabilities.yFields === undefined ? numeric : columns, capabilities.yFields),
    seriesFields: restrict(
      capabilities.seriesFields === undefined
        ? ["", ...categorical.filter((field) => field !== spec.x)]
        : ["", ...columns],
      capabilities.seriesFields,
    ),
  };
}

export function copyChartEditorPresentation({ chart, title, description = "" }) {
  return { chart: copy(chart), title, description: description ?? "" };
}

function checkedMetadata(presentation) {
  if (typeof presentation.title !== "string" || !presentation.title.trim() || presentation.title.length > 500) {
    throw new Error("Chart title must contain 1–500 characters.");
  }
  if (typeof presentation.description !== "string" || presentation.description.length > 2_000) {
    throw new Error("Chart description must contain at most 2,000 characters.");
  }
  return { title: presentation.title.trim(), description: presentation.description.trim() };
}

export async function saveChartEditorPresentation(
  presentation,
  { rows, editMetadata = false, validatePresentation, onSave } = {},
) {
  const candidate = copyChartEditorPresentation(presentation);
  const checked = validatePresentation ? await validatePresentation(candidate, rows) : candidate;
  if (!record(checked) || !record(checked.chart)) throw new Error("Chart presentation is invalid.");
  const accepted = copyChartEditorPresentation(checked);
  if (typeof onSave !== "function") throw new Error("Chart edits cannot be saved here.");
  if (editMetadata) await onSave(accepted.chart, checkedMetadata(accepted));
  else await onSave(accepted.chart);
  return accepted;
}

export function chartEditorPresentationsEqual(left, right) {
  return (
    left.title === right.title &&
    (left.description ?? "") === (right.description ?? "") &&
    chartEditorSpecsEqual(left.chart, right.chart)
  );
}

export function createChartEditorState(presentation) {
  const initial = copyChartEditorPresentation(presentation);
  return {
    initial,
    draft: initial,
    history: [initial],
    historyIndex: 0,
    dirty: false,
    lastField: null,
  };
}

export function changeChartEditorState(current, presentation, field) {
  const draft = copyChartEditorPresentation(presentation);
  const dirty = !chartEditorPresentationsEqual(draft, current.initial);
  if (chartEditorPresentationsEqual(draft, current.draft)) {
    const history = [...current.history];
    history[current.historyIndex] = draft;
    return { ...current, draft, history, dirty, lastField: null };
  }
  const continuous = current.historyIndex > 0 && continuousFields.has(field) && current.lastField === field;
  const history = [...current.history.slice(0, current.historyIndex + (continuous ? 0 : 1)), draft];
  return { ...current, draft, history, historyIndex: history.length - 1, dirty, lastField: field ?? null };
}

export function stepChartEditorHistory(current, direction) {
  const historyIndex = current.historyIndex + direction;
  if (historyIndex < 0 || historyIndex >= current.history.length) return current;
  const draft = current.history[historyIndex];
  return {
    ...current,
    draft,
    historyIndex,
    dirty: !chartEditorPresentationsEqual(draft, current.initial),
    lastField: null,
  };
}

export function resetChartEditorState(current, presentation) {
  return changeChartEditorState(current, presentation, "reset");
}

export function chartEditorShortcut(event) {
  if (event.defaultPrevented || event.altKey || !(event.metaKey || event.ctrlKey)) return null;
  const key = event.key?.toLowerCase();
  if (key === "z") return event.shiftKey ? "redo" : "undo";
  return key === "s" ? "save" : null;
}

export function chartEditorPreviewState(original, draft, { visibleSeries, zoomRange } = {}) {
  const before = normalizeChartEditorSpec(original);
  const after = normalizeChartEditorSpec(draft);
  const remapped =
    before.type !== after.type ||
    before.x !== after.x ||
    before.y !== after.y ||
    before.series !== after.series ||
    JSON.stringify(before.fields) !== JSON.stringify(after.fields);
  return {
    visibleSeries: remapped ? undefined : visibleSeries,
    zoomRange: remapped ? undefined : zoomRange,
  };
}
