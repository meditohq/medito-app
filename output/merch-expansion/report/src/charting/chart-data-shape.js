import { boxPlotSummaryFields, hasReviewedBoxPlotSummary, waterfallRowFields } from "./chart-transforms.js";
import { ratioMetric } from "./chart-theme.js";
import { projectBarOptions } from "./bar-family.js";
import { chartAnnotationFields, normalizeChartAnnotations } from "./chart-annotations.js";

// Reviewed values supplied with the current rows, independently of edited settings.
export const chartDataInputKeys = Object.freeze(["beginning", "ending"]);

const scalarSpecKeys = [
  "type",
  "presentation",
  "x",
  "y",
  "series",
  "source",
  "target",
  "xLabel",
  "yLabel",
  "rightYAxisLabel",
  "yAxisPosition",
  "xLabelPosition",
  "xTickLabelLayout",
  "axisPercentDigits",
  "showXAxisLabel",
  "showYAxisLabel",
  "showCategoryTicks",
  "startAtZero",
  "showValues",
  "showLegend",
  "showAnnotations",
  "baseColor",
  "valueDecimals",
  "currency",
  "yTickCount",
  "missingValues",
  "reverseRows",
  "colorScaleStartAtZero",
  "hideMissingCells",
  "colorBySign",
  "colorByColumn",
  "sortOrder",
  "centerLabel",
  "centerValue",
  ...chartDataInputKeys,
  "rowHeight",
  "markRadius",
  "markStartRadius",
  "initialVisibleCount",
  "labelMaxLength",
  "penultimateLabelAlignment",
  "sankeyLabelFontSize",
  "sankeyLinkColorMode",
  "sankeyNodeWidth",
  "sankeySortNodes",
  "sankeyTerminalLabelAlignment",
  "sankeyValueFontSize",
  "groupOther",
  "maxCategories",
  "distribution",
  "variant",
  "stackable",
];
const listSpecKeys = [
  "fields",
  "barFields",
  "dashedFields",
  "stages",
  "preserveCategories",
  "categoryOrder",
  "seriesOrder",
  "rightAxisFields",
];

export function isTemporalCategory(value) {
  return typeof value === "string" && (/^\d{4}-(?:0[1-9]|1[0-2])$/u.test(value)
    || /^\d{4}-\d{2}-\d{2}(?:T|$)/u.test(value) && Number.isFinite(Date.parse(value)));
}

/** Calendar order is a display transform, never a mutation of reviewed rows. */
export function orderCalendarRows(rows, field, spec = {}) {
  if (!rows.length || ["ascending", "descending"].includes(spec.sortOrder)) return rows;
  if (spec.categoryOrder?.length) {
    const order = new Map(spec.categoryOrder.map((value, index) => [value, index]));
    return [...rows].sort((a, b) => (order.get(a[field]) ?? order.size) - (order.get(b[field]) ?? order.size));
  }
  if (spec.sortOrder === "original") return rows;
  const weekdays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
  const weekday = (value) => typeof value === "string"
    && /^(?:mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:rs?(?:day)?)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\.?$/iu.test(value.trim())
    ? weekdays.indexOf(value.trim().slice(0, 3).toLowerCase()) : -1;
  const weekdayIndices = rows.map((row) => weekday(row[field]));
  // Repeated weekdays may represent successive weeks, not a categorical week.
  if (weekdayIndices.every((day) => day >= 0) && new Set(weekdayIndices).size === rows.length) {
    return [...rows].sort((a, b) => weekday(a[field]) - weekday(b[field]));
  }
  if (rows.every((row) => isTemporalCategory(row[field]))) {
    return [...rows].sort((a, b) => Date.parse(a[field]) - Date.parse(b[field]));
  }
  return rows;
}

/** Separate two measures, not two categories of the same measure. Empty explicit fields opt out. */
export function secondaryAxisFields(spec, rows, fields) {
  if (Array.isArray(spec.rightAxisFields)) {
    const right = fields.filter((field) => spec.rightAxisFields.includes(field));
    return right.length < fields.length ? right : [];
  }
  if (spec.series || spec.barFields?.length || !["line", "bar", "area", "horizontalBar"].includes(spec.type)
    || fields.length < 2) return [];
  if (fields.length !== 2) return [];
  const measureKey = field => String(field).replace(/([a-z])([A-Z])/gu, "$1 $2")
    .replace(/[_·-]/gu, " ").toLowerCase().trim()
    .replace(/^(?:current|latest|recent|previous|prior|preceding)\s+/u, "")
    .replace(/\s+(?:current|latest|recent|previous|prior|preceding)$/u, "");
  if (measureKey(fields[0]) === measureKey(fields[1])) return [];
  const values = fields.map((field) => rows.map((row) => row[field]).filter(Number.isFinite));
  if (values.some((series) => !series.length)) return [];
  const magnitude = values.map((series) => Math.max(...series.map(Math.abs)));
  const differentUnits = ratioMetric(fields[0], values[0]) !== ratioMetric(fields[1], values[1]);
  const differentScales = Math.min(...magnitude) > 0 && Math.max(...magnitude) / Math.min(...magnitude) >= 20;
  return differentUnits || differentScales ? [fields[1]] : [];
}

/** Avoid restating categorical ticks and the chart title; retain axis identity when needed. */
export function axisTitleVisibility(spec, separateAxes = false) {
  const numericPair = spec.type === "scatter";
  return {
    x: spec.showXAxisLabel ?? Boolean(spec.xLabel || numericPair || spec.type === "histogram"),
    y: spec.showYAxisLabel ?? Boolean(spec.yLabel || spec.rightYAxisLabel
      || separateAxes || numericPair || spec.type === "boxPlot"),
  };
}

/** Options consumed by the canonical chart renderer and editor. */
export const chartSpecKeys = Object.freeze([
  ...scalarSpecKeys, ...listSpecKeys, "colors", "lineGradients", "colorDomain", "colorBands", "tooltipFields", "legend", "cellLabel", "hoverHighlight", "barOptions", "annotations",
]);

const scalar = (value) =>
  value == null ||
  typeof value === "string" ||
  typeof value === "boolean" ||
  (typeof value === "number" && Number.isFinite(value));
const record = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

export function lineGradients(value) {
  if (!record(value)) return {};
  return Object.fromEntries(Object.entries(value).flatMap(([field,stops]) => {
    if (!Array.isArray(stops) || stops.length < 2 || stops.length > 16) return [];
    const normalized = stops.map((stop,index) => typeof stop === "string"
      ? {color:stop,offset:index/(stops.length-1)}
      : {color:stop?.color,offset:stop?.offset});
    return normalized.every((stop,index) => typeof stop.color === "string" && Number.isFinite(stop.offset)
      && stop.offset >= 0 && stop.offset <= 1 && (!index || stop.offset >= normalized[index-1].offset))
      ? [[field,normalized]] : [];
  }));
}

/** Project a separately shareable chart spec without carrying arbitrary extension metadata. */
export function projectChartSpec(spec = {}) {
  const result = {};
  if (record(spec.lineGradients)) result.lineGradients = lineGradients(spec.lineGradients);
  if (record(spec.barOptions)) result.barOptions = projectBarOptions(spec.barOptions);
  for (const key of scalarSpecKeys) {
    if (Object.hasOwn(spec, key) && scalar(spec[key])) result[key] = spec[key];
  }
  if (result.type === "horizontal-bar") result.type = resolvedChartType(result);
  for (const key of listSpecKeys) {
    if (Array.isArray(spec[key])) result[key] = spec[key].filter((field) => typeof field === "string");
  }
  if (record(spec.colors)) {
    result.colors = Object.fromEntries(Object.entries(spec.colors).filter(([, color]) => typeof color === "string"));
  }
  if (Array.isArray(spec.tooltipFields)) result.tooltipFields = spec.tooltipFields.slice(0, 10).flatMap(entry =>
    typeof entry?.field === "string" && typeof entry.label === "string"
      ? [{ field: entry.field.slice(0, 200), label: entry.label.slice(0, 200) }] : []);
  if (Array.isArray(spec.colorDomain)) {
    result.colorDomain = spec.colorDomain.slice(0, 2).map((value) => (Number.isFinite(value) ? value : null));
  }
  if (Array.isArray(spec.colorBands)) {
    result.colorBands = spec.colorBands.slice(0, 24).filter(record).flatMap((band) => {
      if (typeof band.color !== "string") return [];
      return [{
        ...(Number.isFinite(band.max) ? { max: band.max } : {}),
        color: band.color,
        ...(typeof band.label === "string" ? { label: band.label } : {}),
        ...(typeof band.legendGroup === "string" ? { legendGroup: band.legendGroup } : {}),
      }];
    });
  }
  if (record(spec.legend)) {
    const legend = {};
    if (typeof spec.legend.position === "string") legend.position = spec.legend.position;
    if (spec.legend.comparisons === "grouped") legend.comparisons = "grouped";
    if (record(spec.legend.labels)) legend.labels = Object.fromEntries(Object.entries(spec.legend.labels)
      .filter(([field, label]) => field.length <= 200 && typeof label === "string" && label.length <= 200));
    if (Object.keys(legend).length) result.legend = legend;
  }
  if (record(spec.cellLabel)) {
    const cellLabel = {};
    if (typeof spec.cellLabel.text === "string") cellLabel.text = spec.cellLabel.text;
    if (typeof spec.cellLabel.color === "string") cellLabel.color = spec.cellLabel.color;
    if (Number.isFinite(spec.cellLabel.showWhen)) cellLabel.showWhen = spec.cellLabel.showWhen;
    if (Number.isFinite(spec.cellLabel.fontSize)) cellLabel.fontSize = spec.cellLabel.fontSize;
    if (Number.isFinite(spec.cellLabel.fontWeight)) cellLabel.fontWeight = spec.cellLabel.fontWeight;
    if (Object.keys(cellLabel).length) result.cellLabel = cellLabel;
  }
  if (typeof spec.hoverHighlight === "boolean") result.hoverHighlight = spec.hoverHighlight;
  else if (record(spec.hoverHighlight)) {
    const hoverHighlight = {};
    if (typeof spec.hoverHighlight.color === "string") hoverHighlight.color = spec.hoverHighlight.color;
    if (Number.isFinite(spec.hoverHighlight.width) && spec.hoverHighlight.width > 0) {
      hoverHighlight.width = spec.hoverHighlight.width;
    }
    result.hoverHighlight = hoverHighlight;
  }
  if (Object.hasOwn(spec, "annotations")) result.annotations = normalizeChartAnnotations(spec.annotations);
  return result;
}

/** Collapse only a single reviewed, nonnegative additive category measure. */
export function groupAdditiveCategories(
  rows = [],
  { categoryField, valueField, maxCategories = 7, preserveCategories = [], enabled = false } = {},
) {
  const limit = Number(maxCategories);
  if (!enabled || !categoryField || !valueField || !Number.isSafeInteger(limit) || limit < 2 || rows.length <= limit) {
    return rows;
  }

  const measureWords = String(valueField)
    .replace(/([a-z])([A-Z])/gu, "$1 $2")
    .replaceAll("_", " ");
  if (/\b(?:rate|ratio|percent(?:age)?|pct|avg|average|mean|median|share|per)\b/iu.test(measureWords)) return rows;
  const categories = new Set();
  for (const row of rows) {
    const category = row?.[categoryField];
    const value = row?.[valueField];
    if (typeof category !== "string" || !category.trim() || categories.has(category)
      || /^other$/iu.test(category.trim()) || !Number.isFinite(value) || value < 0) return rows;
    categories.add(category);
  }

  const requested = Array.isArray(preserveCategories) ? preserveCategories : [];
  const preserved = new Set(requested.map(String).filter((category) => categories.has(category)));
  if (preserved.size >= limit) return rows;

  const sorted = [...rows].sort((left, right) => right[valueField] - left[valueField]);
  const leading = new Set([
    ...sorted.filter((row) => preserved.has(row[categoryField])),
    ...sorted.filter((row) => !preserved.has(row[categoryField])),
  ].slice(0, limit - 1).map((row) => row[categoryField]));
  const other = sorted.filter((row) => !leading.has(row[categoryField]));
  if (!other.length) return rows;

  return [
    ...sorted.filter((row) => leading.has(row[categoryField])),
    { [categoryField]: "Other", [valueField]: other.reduce((total, row) => total + row[valueField], 0) },
  ];
}

/** Group only independently additive, mutually exclusive series at each reviewed x value. */
export function groupAdditiveSeries(
  rows = [],
  { groupField, categoryField, valueField, maxCategories = 7, preserveCategories = [], enabled = false } = {},
) {
  if (!enabled || !groupField || !categoryField || !valueField || !rows.length) return rows;

  const groups = new Map();
  const categories = new Set();
  for (const row of rows) {
    const group = row?.[groupField];
    const category = row?.[categoryField];
    const value = row?.[valueField];
    if (group == null || typeof category !== "string" || !category.trim()
      || /^other$/iu.test(category.trim()) || !Number.isFinite(value) || value < 0) return rows;
    if (!groups.has(group)) groups.set(group, new Map());
    const current = groups.get(group);
    if (current.has(category)) return rows;
    current.set(category, row);
    categories.add(category);
  }

  const reference = [...categories].map((category) => ({
    [categoryField]: category,
    [valueField]: [...groups.values()]
      .reduce((peak, period) => Math.max(peak, period.get(category)?.[valueField] ?? 0), 0),
  }));
  const grouped = groupAdditiveCategories(reference, {
    categoryField,
    valueField,
    maxCategories,
    preserveCategories,
    enabled: true,
  });
  if (grouped === reference) return rows;

  const leading = new Set(grouped.filter((row) => row[categoryField] !== "Other")
    .map((row) => row[categoryField]));
  return [...groups].flatMap(([group, current]) => {
    const prominent = [...current.values()].filter((row) => leading.has(row[categoryField]));
    const remaining = [...current.values()].filter((row) => !leading.has(row[categoryField]));
    if (!remaining.length) return prominent;
    return [
      ...prominent,
      {
        [groupField]: group,
        [categoryField]: "Other",
        [valueField]: remaining.reduce((total, row) => total + row[valueField], 0),
      },
    ];
  });
}

/** Reconcile grouped totals with the reviewed source categories that remain visible. */
export function visibleGroupedCategories(
  rows = [],
  grouped = [],
  { categoryField, valueField, groupField, visibleCategories } = {},
) {
  if (!visibleCategories || !grouped.some((row) => row[categoryField] === "Other")) return grouped;
  const visible = new Set([...visibleCategories].map(String));
  const leading = new Set(grouped.filter((row) => row[categoryField] !== "Other")
    .map((row) => String(row[categoryField])));
  return grouped.map((row) => row[categoryField] === "Other"
    ? {
        ...row,
        [valueField]: rows.reduce((total, source) => {
          const category = String(source[categoryField]);
          return !leading.has(category) && visible.has(category)
            && (!groupField || source[groupField] === row[groupField])
            ? total + source[valueField]
            : total;
        }, 0),
      }
    : row);
}

/** Recognize ordered numeric or time buckets without collapsing ordinary categories. */
export function orderedDistribution(spec = {}, rows = []) {
  if (typeof spec.distribution === "boolean") return spec.distribution;
  const words = String(spec.x ?? "")
    .replace(/([a-z])([A-Z])/gu, "$1 $2")
    .replaceAll("_", " ");
  if (!/\b(?:bands?|buckets?|bins?|intervals?)\b/iu.test(words)) return false;
  const values = [...new Set(rows.map((row) => row?.[spec.x]).filter((value) => value != null))];
  return values.length >= 3 && values.every((value) => typeof value === "number" && Number.isFinite(value)
    || typeof value === "string" && (/^\d{1,2}:\d{2}(?::\d{2})?$/u.test(value.trim())
      || /^(?:[<>≤≥]\s*)?\d+(?:[.,]\d+)?(?:\s*(?:-|–|—|to)\s*\d+(?:[.,]\d+)?)?\+?(?:\s*(?:m(?:in(?:ute)?s?)?|h(?:ours?)?|days?|weeks?|months?|years?))?$/iu.test(value.trim())));
}

/** Label every Nth bucket. Do not append an endpoint that breaks the cadence. */
export function temporalAxisTicks(values = [], { maxTicks = 6 } = {}) {
  const reviewed = [...new Set(values.filter(value => value != null))];
  const limit = Math.max(1, Number.isSafeInteger(maxTicks) ? maxTicks : 6);
  if (reviewed.length <= limit) return reviewed;
  if (limit === 1) return [reviewed.at(-1)];
  const stride = Math.ceil(reviewed.length / limit);
  return reviewed.filter((_, index) => index % stride === 0);
}

const dayMilliseconds = 86_400_000;

/** Follow the observed cadence when it is regular. Only irregular series need
 * independent calendar ticks; neither mode synthesizes or moves observations. */
export function temporalTimeTicks(values = [], { maxTicks = 6 } = {}) {
  const times = [...new Set(values.map(value => Date.parse(value)).filter(Number.isFinite))].sort((a,b)=>a-b);
  if (!times.length) return [];
  const start = Math.min(...times), end = Math.max(...times);
  const limit = Math.max(1, maxTicks);
  if (start === end) return [start];
  if (limit === 1) return [end];
  const step = times[1] - times[0];
  const regularTime = times.every((time,index)=>!index || time-times[index-1]===step);
  const dates = times.map(time=>new Date(time));
  const months = dates.map(date=>date.getUTCFullYear()*12+date.getUTCMonth());
  const monthStep = months[1]-months[0];
  const monthEnd = date=>date.getUTCDate()===new Date(Date.UTC(date.getUTCFullYear(),date.getUTCMonth()+1,0)).getUTCDate();
  const regularMonths = monthStep>0 && months.every((month,index)=>!index || month-months[index-1]===monthStep)
    && times.every(time=>time%dayMilliseconds===times[0]%dayMilliseconds)
    && (dates.every(date=>date.getUTCDate()===dates[0].getUTCDate()) || dates.every(monthEnd));
  if (regularTime || regularMonths) return temporalAxisTicks(times,{maxTicks:limit});
  const fixed = [1, 5, 10, 50, 100, 250, 500, 1000, 5000, 15000, 30000,
    60000, 300000, 900000, 1800000, 3600000, 10800000, 21600000, 43200000,
    dayMilliseconds, 2 * dayMilliseconds, 3 * dayMilliseconds, 5 * dayMilliseconds,
    7 * dayMilliseconds, 14 * dayMilliseconds];
  const minimumStep = times.every(time => time % dayMilliseconds === 0) ? dayMilliseconds : 1;
  for (const step of fixed) {
    if (step < minimumStep) continue;
    // Weekly ticks use Mondays, including across month/year boundaries.
    const origin = step >= 7 * dayMilliseconds ? 4 * dayMilliseconds : 0;
    const first = Math.ceil((start - origin) / step) * step + origin;
    const count = Math.floor((end - first) / step) + 1;
    if (count >= 2 && count <= limit) return Array.from({ length: count }, (_, i) => first + i * step);
  }
  const firstDate = new Date(start), lastDate = new Date(end);
  const firstMonth = firstDate.getUTCFullYear() * 12 + firstDate.getUTCMonth();
  const lastMonth = lastDate.getUTCFullYear() * 12 + lastDate.getUTCMonth();
  const yearPower = 10 ** Math.max(0, Math.floor(Math.log10(Math.max(1, (lastMonth - firstMonth) / 12 / limit))));
  for (const step of [...new Set([1, 2, 3, 6, 12, ...[1, 2, 5, 10, 20].map(n => n * yearPower * 12)])].sort((a,b)=>a-b)) {
    const ticks = [];
    for (let month = Math.ceil(firstMonth / step) * step; month <= lastMonth; month += step) {
      const time = Date.UTC(Math.floor(month / 12), month % 12, 1);
      if (time >= start) ticks.push(time);
      if (ticks.length > limit) break;
    }
    if (ticks.length >= 2 && ticks.length <= limit) return ticks;
  }
  return [end];
}

/** Plan labels against actual plot and measured text. Continuous trends use time;
 * bucketed bars keep band centers and a constant index stride. */
export function temporalAxisLayout(values = [], { plotWidth = 0, leftRoom = 0, rightRoom = 0,
  measureLabel = value => String(value).length * 8, maxTicks, gap = 12, edgeGap = 4, banded = false, continuous = false } = {}) {
  const reviewed = [...new Set(values.filter(value => value != null))];
  if (!reviewed.length) return { ticks: [], padding: { left: 0, right: 0 }, bounds: [] };
  const width = Math.max(0, Number(plotWidth) || 0);
  const times = continuous ? reviewed.map(value => Date.parse(value)) : [];
  const domain = continuous ? [Math.min(...times), Math.max(...times)] : undefined;
  const measure = value => Math.max(0, Number(measureLabel(value)) || 0);
  const estimatedWidth = Math.max(1, ...reviewed.map(value => measure(continuous ? Date.parse(value) : value)));
  const limit = Number.isSafeInteger(maxTicks) ? Math.max(1, maxTicks)
    : Math.max(1, Math.floor(width / (estimatedWidth + gap)) + 1);
  for (let count=continuous ? limit : Math.min(reviewed.length,limit);count>=1;count--) {
    const ticks = (continuous ? temporalTimeTicks : temporalAxisTicks)(reviewed,{maxTicks:count});
    const half = Math.max(0,...ticks.map(measure)) / 2 + edgeGap;
    const padding = { left:Math.min(width/2,Math.max(0,half-leftRoom)), right:Math.min(width/2,Math.max(0,half-rightRoom)) };
    const available = Math.max(0,width-padding.left-padding.right);
    const bounds = ticks.map(value => {
      const index = reviewed.indexOf(value);
      const fraction = reviewed.length === 1 || continuous && domain[0] === domain[1] ? .5
        : continuous ? (value-domain[0])/(domain[1]-domain[0])
        : banded ? (index+.5)/reviewed.length : index/(reviewed.length-1);
      return {value,x:padding.left+available*fraction,width:measure(value)};
    });
    if (bounds.every((label,index) => label.x-label.width/2 >= -leftRoom+edgeGap
      && label.x+label.width/2 <= width+rightRoom-edgeGap
      && (!index || label.x-label.width/2 >= bounds[index-1].x+bounds[index-1].width/2+gap))) {
      return {ticks,padding,bounds};
    }
  }
  return {ticks:[],padding:{left:0,right:0},bounds:[]};
}

/** Prefer horizontal labels; reserve diagonal treatment for genuinely crowded named categories. */
export function categoryAxisLayout(values = [], { preference = "auto", minimumAngledCount = 8 } = {}) {
  const labels = [...new Set(values.filter((value) => value != null).map(String))];
  if (labels.length && labels.every((value) => /^\d{4}-\d{2}-\d{2}(?:T|$)/u.test(value)
    || /^\d{1,2}:\d{2}(?::\d{2})?$/u.test(value)
    || /^-?\d+(?:\.\d+)?$/u.test(value))) return "horizontal";
  if (["horizontal", "wrapped", "angled"].includes(preference)) return preference;
  if (labels.length < minimumAngledCount) return "wrapped";
  return labels.some((value) => value.length > 8) ? "angled" : "wrapped";
}

/** Keep authored chart types explicit while supporting the legacy leaderboard name. */
export function resolvedChartType(spec = {}) {
  if (spec.type === "leaderboard") return "rankedList";
  // Accept the common spelling at the public boundary instead of silently
  // falling through to a vertical chart with unrelated category-tick rules.
  return spec.type === "horizontal-bar" ? "horizontalBar" : spec.type;
}

/** Tile hit areas exactly, while preserving a visual gap even in dense heatmaps. */
export function heatmapCellSize(plotWidth, plotHeight, columns, rows) {
  const pitchX = Math.max(0, plotWidth) / Math.max(1, columns);
  const pitchY = Math.max(0, plotHeight) / Math.max(1, rows);
  return { pitchX, pitchY, width: pitchX - Math.min(5, pitchX / 4), height: pitchY - Math.min(5, pitchY / 4) };
}

/** Keep the compact baseline while revealing additional reviewed rows that genuinely fit. */
export function rankedListCapacity({ availableHeight, rowHeight, rowGap = 0, minimumCount = 5, totalCount }) {
  const minimum = Math.max(1, Number(minimumCount) || 5);
  const total = Math.max(minimum, Number(totalCount) || minimum);
  if (!(availableHeight > 0) || !(rowHeight > 0)) return Math.min(minimum, total);
  const visible = Math.floor((availableHeight + rowGap) / (rowHeight + rowGap));
  return Math.min(total, Math.max(minimum, visible));
}

const scatterIdentityFields = [
  "featureName",
  "feature",
  "name",
  "label",
  "account",
  "plan",
  "country",
  "action",
  "product",
  "surface",
  "segment",
  "status",
];

export function scatterTooltipIdentityField(row) {
  return scatterIdentityFields.find((field) => typeof row?.[field] === "string" && row[field]);
}

const fieldNames = (values) => [...new Set(values.filter((field) => typeof field === "string" && field.length > 0))];

/**
 * Resolve the renderer's real data shape before projecting raw rows. Series values
 * become output columns after pivoting; they are not raw field dependencies.
 */
export function chartDataShape(spec, rows) {
  const { type, x, y, series = "" } = spec;
  const columns = [...new Set(rows.flatMap(Object.keys))];
  const numeric = columns.filter((column) => rows.some((row) => Number.isFinite(row[column])));
  const seriesValues = series ? [...new Set(rows.map((row) => row[series]).filter((value) => value != null))] : [];
  const fields = spec.presentation && spec.barOptions?.series?.length ? spec.barOptions.series.map(item => item.key)
    : seriesValues.length ? seriesValues : spec.fields ?? [y];
  const barFields = type === "line" && Array.isArray(spec.barFields) ? spec.barFields : [];
  const heatmapGroup = series || columns.find((column) => column !== x && !numeric.includes(column)) || x;
  const sankeyStages =
    type === "sankey" ? (spec.stages ?? [spec.source ?? x, spec.target ?? series]).filter(Boolean) : [];
  const longForm = seriesValues.length > 0;
  const reviewedBoxPlot = type === "boxPlot" && hasReviewedBoxPlotSummary(rows);
  const requiresX = type !== "histogram" && type !== "sankey";
  const wideFields = longForm ? [] : [...fields, ...barFields];

  let required = [requiresX ? x : null, y, ...(longForm ? [series] : wideFields)];
  if (type === "histogram") required = [y];
  if (type === "sankey") required = [y, ...sankeyStages];
  if (type === "boxPlot") required = reviewedBoxPlot ? [x, ...boxPlotSummaryFields] : [x, y];
  if (type === "heatmap") required = [x, y, heatmapGroup];
  if (spec.presentation && spec.barOptions) required = [x, ...fields, ...(spec.barOptions.range ?? []),
    spec.barOptions.target, spec.barOptions.projection, spec.barOptions.track?.max];

  const requiredRowFields = fieldNames(required);
  const optional = [x, y, series, ...wideFields, ...(spec.tooltipFields ?? []).map(item => item.field)];
  if (spec.presentation && spec.barOptions) optional.push(spec.barOptions.rangeLabelField, spec.barOptions.unitField, spec.barOptions.detailField,
    spec.barOptions.style?.colorField, spec.barOptions.style?.textColorField, spec.barOptions.style?.thicknessField,
    ...(spec.barOptions.tooltipFields ?? []).map(item => item.key));
  const annotations = normalizeChartAnnotations(spec.annotations);
  optional.push(...chartAnnotationFields(annotations.filter((entry) => entry.kind !== "point" || !longForm)));
  if (type === "waterfall") optional.push(...waterfallRowFields(rows, x));
  if (type === "scatter") optional.push(...rows.map(scatterTooltipIdentityField));
  const requiredSet = new Set(requiredRowFields);
  const optionalRowFields = fieldNames(optional).filter((field) => columns.includes(field) && !requiredSet.has(field));
  const retained = new Set([...requiredRowFields, ...optionalRowFields]);

  return {
    columns,
    numeric,
    seriesValues,
    fields,
    barFields,
    heatmapGroup,
    sankeyStages,
    longForm,
    reviewedBoxPlot,
    requiresX,
    requiredRowFields,
    optionalRowFields,
    // Preserve source order so a second shape inference selects the same heatmap dimension.
    rowFields: columns.filter((field) => retained.has(field)),
  };
}
