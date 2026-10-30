import React, {
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ComposedChart,
  Dot,
  LabelList,
  Line,
  LineChart,
  Rectangle,
  ReferenceArea,
  Scatter,
  ScatterChart,
  getNiceTickValues,
  XAxis,
  YAxis,
  ZAxis,
} from "recharts";

import { maximumValue, minimumValue } from "./chart-extrema.js";
import { CategoryAxisTick } from "./CategoryAxisTick.jsx";
import { HeatmapRenderer } from "./HeatmapRenderer.jsx";
import { PieRenderer } from "./PieRenderer.jsx";
import { SankeyRenderer } from "./SankeyRenderer.jsx";
import { exploreMarkKey } from "./chart-mark-interactions.js";
import { BarFamilyRenderer } from "./BarFamilyRenderer.jsx";
import { ComponentState } from "./ChartState.jsx";
import { getChartSpecError } from "./chart-spec-validation.js";
import { NumericXAxis, NumericYAxis } from "./NumericAxes.jsx";
import { captureChartHoverCard } from "./ChartMark.jsx";
import { ChartFrame } from "./ChartFrame.jsx";
import { ChartTooltip, PointerChartTooltip } from "./ChartTooltip.jsx";
import { TemporalXAxis } from "./TemporalXAxis.jsx";
import { chartAnnotationMarks, ChartAnnotationLayer, ChartAnnotationNotes } from "./ChartAnnotations.jsx";
import { benchmarkAnnotationDomain, bindChartAnnotationAxes, resolveChartAnnotations } from "./chart-annotations.js";
import { FunnelRenderer } from "./FunnelRenderer.jsx";
import {
  axisTitleVisibility,
  categoryAxisLayout,
  chartDataShape,
  groupAdditiveCategories,
  groupAdditiveSeries,
  isTemporalCategory,
  orderCalendarRows,
  orderedDistribution,
  rankedListCapacity,
  lineGradients,
  resolvedChartType,
  secondaryAxisFields,
  visibleGroupedCategories,
} from "./chart-data-shape.js";
import { useDashboardAsk } from "../components/DashboardAsk.jsx";
import {
  boxPlots,
  heatmap,
  histogram,
  isolatedPointIndexes,
  normalizeZoomRange,
  pivot,
  stackedMarkBounds,
  waterfall,
  waterfallValueDomain,
} from "./chart-transforms.js";
import {
  categoryLabel,
  colors,
  compact,
  displayValue,
  label,
  numericAxisFormatter,
  ratioMetric,
  semanticCategoryDimension,
  semanticColor,
  formatChartValue, percentageAxisMode, comparisonSeriesBase, compactChartLabel,
  tick,
  wholePercentTicks,
} from "./chart-theme.js";

const grid = <CartesianGrid stroke="var(--border)" strokeWidth={0.5} vertical={false} />;
const margin = { top: 10, right: 14, bottom: 8, left: 9 };
// Recharts shallow-compares label settings. A fresh nested style resets the
// measured auto axis width on each annotation update and can oscillate layout.
const valueAxisLabelStyle = { fill: "var(--secondary)", fontSize: 12, textAnchor: "middle" };

function useBenchmarkAnnotationDomain(annotations, data, fields, axisId, height, startAtZero, ratio) {
  const benchmarks = annotations.filter((entry) => entry.kind === "benchmark" && entry.valueAxisId === axisId)
    .map(({ y }) => y);
  const values = benchmarks.length ? data.flatMap((row) => fields.map((field) => row[field])).filter(Number.isFinite) : [];
  const benchmarkKey = JSON.stringify(benchmarks);
  const domainLow = minimumValue(values, minimumValue(benchmarks)), domainHigh = maximumValue(values, maximumValue(benchmarks));
  return useMemo(() => {
    const domain = benchmarkAnnotationDomain(JSON.parse(benchmarkKey), [domainLow, domainHigh], height, startAtZero, ratio);
    if (!domain) return undefined;
    const ticks = getNiceTickValues(domain, 6), step = ticks[1] - ticks[0];
    const rounded = domain.map((value) => value < domainLow ? Math.floor(value / step) * step
      : value > domainHigh ? Math.ceil(value / step) * step : value);
    return rounded.every(Number.isFinite) ? rounded : domain;
  }, [benchmarkKey, domainLow, domainHigh, height, startAtZero, ratio]);
}

function tooltipLabel(value) {
  return tick(value);
}

function ExploreDot({ cx, cy, payload, index, first, firstIndex, isolated, label, onSelect, stroke }) {
  if (!Number.isFinite(cx) || !Number.isFinite(cy)) return null;
  return <g className="chart-explore-mark recharts-dot" data-isolated-point={isolated?.has(index) || undefined} role="button" tabIndex={first && index === firstIndex ? 0 : -1}
    aria-label={label(payload)} onKeyDown={event => exploreMarkKey(event, event => onSelect(payload, event))}>
    <circle cx={cx} cy={cy} r={5} fill="var(--surface)" stroke={stroke} strokeWidth={2} />
  </g>;
}

function ExploreBar({ payload, index, label, onSelect, ...shape }) {
  return <g className="chart-explore-mark" role="button" tabIndex={index === 0 ? 0 : -1}
    aria-label={label(payload)} onKeyDown={event => exploreMarkKey(event, event => onSelect(payload, event))}>
    <Rectangle {...shape} />
  </g>;
}

const axisTickFontSize = 12;

function StackedMarkShape({ x, y, width, height, fill, payload, fields, field, horizontal, radius }) {
  const clipId = useId().replaceAll(":", "");
  const bounds = stackedMarkBounds(payload, fields, field, { x, y, width, height, horizontal });
  if (!bounds) return null;
  const rounded = Math.min(radius, bounds.width / 2, bounds.height / 2);
  // Let the whole-stack clip paint each outer edge once; coincident fill edges
  // otherwise multiply antialias coverage and make adjacent segments look uneven.
  const paint = horizontal ? { x, y: y - 1, width, height: height + 2 }
    : { x: x - 1, y, width: width + 2, height };
  return (
    <g data-stack-sign={Number(payload[field]) < 0 ? "negative" : "positive"}>
      <defs>
        <clipPath id={clipId}>
          <Rectangle {...bounds} radius={[rounded, rounded, rounded, rounded]} />
        </clipPath>
      </defs>
      <Rectangle {...paint} fill={fill} clipPath={`url(#${clipId})`} />
    </g>
  );
}

function BoxShape({ x, y, width, height, payload, fill }) {
  const ratio = height / Math.max(1, payload.upperQuartile - payload.lowerQuartile);
  const center = x + width / 2;
  const cap = Math.min(12, width * 0.28);
  const top = y - (payload.maximum - payload.upperQuartile) * ratio;
  const bottom = y + height + (payload.lowerQuartile - payload.minimum) * ratio;
  const median = y + (payload.upperQuartile - payload.median) * ratio;
  const color = fill ?? colors[0];
  return (
    <g className="chart-box-plot" stroke={color} strokeWidth={1.5}>
      <line x1={center} x2={center} y1={top} y2={bottom} strokeOpacity={0.75} />
      <line x1={center - cap} x2={center + cap} y1={top} y2={top} />
      <line x1={center - cap} x2={center + cap} y1={bottom} y2={bottom} />
      <rect
        x={x}
        y={y}
        width={width}
        height={height}
        rx={Math.min(6, width / 8)}
        fill={"color-mix(in srgb, " + color + " 16%, var(--surface))"}
      />
      <line x1={x + 1} x2={x + width - 1} y1={median} y2={median} strokeWidth={2.5} />
    </g>
  );
}

function WaterfallShape({ x, y, width, height, fill, radius }) {
  return <Rectangle x={x} y={y} width={width} height={height} radius={radius} fill={fill} />;
}

// Keep negative values inside the plot, away from left-side category labels.
function SignedHorizontalValueLabel({ x, y, width, height, value, formatValue }) {
  if (![x, y, width, height].every(Number.isFinite)) return null;
  return <text x={Math.max(x, x + width) + 5} y={y + height / 2}
    textAnchor="start" dominantBaseline="central" fontSize={12}
    fill={Number(value) < 0 ? "var(--negative)" : Number(value) > 0 ? "var(--positive)" : "var(--secondary)"}>
    {formatValue(value)}
  </text>;
}

function SparseValueLabel({ x, y, width = 0, value, index, count }) {
  const interval = Math.max(1, Math.ceil(count / 8));
  if (index % interval !== 0 && index !== count - 1) return null;
  if (!Number.isFinite(Number(value))) return null;
  return (
    <text x={Number(x) + Number(width) / 2} y={Number(y) - 8} fill="var(--secondary)" fontSize={12} textAnchor="middle">
      {compact(Number(value))}
    </text>
  );
}

function IsolatedLineDot({ indexes, index, cx, cy, stroke, fill, strokeWidth, strokeOpacity, className }) {
  if (!indexes.has(index)) return null;
  return (
    <Dot
      cx={cx}
      cy={cy}
      r={3}
      stroke={stroke}
      fill={stroke ?? fill}
      strokeWidth={strokeWidth}
      strokeOpacity={strokeOpacity}
      fillOpacity={strokeOpacity}
      className={["recharts-line-dot", className].filter(Boolean).join(" ")}
      data-isolated-point="true"
    />
  );
}

const dateValue = isTemporalCategory;

function zeroAnchoredDomain([minimum, maximum]) {
  return [Math.min(0, minimum), Math.max(0, maximum)];
}

// Defined only for release-time inline targets. Source builds and full dashboards
// retain every branch; inline bundles share these exact implementations.
const cartesianEnabled = typeof __DATA_INLINE_CHART_FAMILY__ === "undefined" || __DATA_INLINE_CHART_FAMILY__ === "cartesian";
// Conventional chart edits can cross between trend and bar presentations.
const trendEnabled = typeof __DATA_INLINE_CHART_FAMILY__ === "undefined"
  || __DATA_INLINE_CHART_FAMILY__ === "trend" || __DATA_INLINE_CHART_FAMILY__ === "cartesian";
const barsEnabled = cartesianEnabled || trendEnabled;
const categoricalEnabled = typeof __DATA_INLINE_CHART_FAMILY__ === "undefined" || __DATA_INLINE_CHART_FAMILY__ === "categorical";
const flowEnabled = typeof __DATA_INLINE_CHART_FAMILY__ === "undefined" || __DATA_INLINE_CHART_FAMILY__ === "flow";

export function ChartRenderer(props) {
  // Inline inputs and presentation edits are validated by their host before projection.
  // Keep their byte budget for reviewed rows; source/full-app charts validate here.
  const configurationError = typeof __DATA_INLINE_CHART__ !== "undefined" && __DATA_INLINE_CHART__
    ? null : getChartSpecError(props.spec, { id: props.chartId });
  if (configurationError) return <div className="component-data-state" role="alert"
    data-chart-config-error="true" data-chart-id={props.chartId} style={{ minHeight: props.height ?? 240 }}>
    <strong>Chart configuration error</strong>
    <p>{configurationError}</p>
  </div>;
  if (!props.rows?.length) return <ComponentState height={props.height ?? 240} />;
  const type = resolvedChartType(props.spec);
  return cartesianEnabled && props.spec?.presentation && ["bar", "horizontalBar"].includes(type)
    ? <BarFamilyRenderer {...props} spec={{ ...props.spec, type }} /> : <StandardChartRenderer {...props} />;
}

function StandardChartRenderer({
  spec,
  rows,
  accessibleLabel,
  height = 240,
  chartId,
  resolveColor,
  themeRoot,
  visibleSeries,
  onVisibleSeriesChange,
  zoomRange,
  onZoomChange,
  getMarkActions,
  onSankeySelection,
  tooltipContent,
  fixedAxisWidths = false,
}) {
  const { selectChartMark, selectChartSection, selectionEnabled } = useDashboardAsk();
  const [hiddenSeries, setHiddenSeries] = useState(() => new Set());
  const [localZoom, setLocalZoom] = useState(null);
  const [selection, setSelection] = useState(null);
  const latestHover = useRef(null);
  const frameRef = useRef(null);
  const gradientId = useId().replaceAll(":", "");
  const gradients = useMemo(() => lineGradients(spec.lineGradients), [spec.lineGradients]);
  const [heatHover, setHeatHover] = useState(false);
  useEffect(() => setHeatHover(false), [rows, spec]);
  const captureHoverCard = (event, row) => {
    const element = event?.target?.closest?.(".recharts-wrapper");
    const tooltip = element?.querySelector(".recharts-tooltip-wrapper .chart-tooltip");
    const hover = latestHover.current;
    if (!tooltip || !hover || hover.row?.[spec.x] !== row?.[spec.x]) return undefined;
    return captureChartHoverCard(element, tooltip);
  };
  const [rankingExpanded, setRankingExpanded] = useState(false);
  const [placedAnnotationIds, setPlacedAnnotationIds] = useState([]);
  const rankingListRef = useRef(null);
  const minimumRankingRows = Math.max(1, Number(spec.initialVisibleCount) || 5);
  const [fittedRankingRows, setFittedRankingRows] = useState(minimumRankingRows);
  const type = resolvedChartType(spec, rows);
  const { x, y, series = "" } = spec;
  const controlledVisible = visibleSeries == null ? null : new Set([...visibleSeries].map(String));
  const groupedField = type === "pie" ? x : series;
  const visibleSourceCategories = controlledVisible
    ?? new Set(rows.map((row) => String(row[groupedField])).filter((category) => !hiddenSeries.has(category)));
  const groupedSeriesRows = series && ["line", "area", "stackedArea", "bar", "stackedBar", "stackedBar100",
    "horizontalStackedBar", "horizontalStackedBar100"].includes(type)
    ? groupAdditiveSeries(rows, {
        groupField: x,
        categoryField: series,
        valueField: y,
        maxCategories: spec.maxCategories ?? 7,
        preserveCategories: spec.preserveCategories ?? [],
        enabled: spec.groupOther === true,
      })
    : rows;
  const seriesRows = visibleGroupedCategories(rows, groupedSeriesRows, {
    categoryField: series, valueField: y, groupField: x, visibleCategories: visibleSourceCategories,
  });
  const groupedPieRows = type === "pie"
    ? groupAdditiveCategories(rows, {
        categoryField: x,
        valueField: y,
        maxCategories: spec.maxCategories ?? 7,
        preserveCategories: spec.preserveCategories ?? [],
        enabled: spec.groupOther === true,
      })
    : rows;
  const pieRows = visibleGroupedCategories(rows, groupedPieRows, {
    categoryField: x, valueField: y, visibleCategories: visibleSourceCategories,
  });
  const { numeric, seriesValues, fields, barFields, heatmapGroup, sankeyStages } = chartDataShape(spec, seriesRows);

  useEffect(() => {
    if (type !== "rankedList" || rankingExpanded) return undefined;
    const ranking = rankingListRef.current;
    const component = ranking?.closest("[data-component-id]");
    const firstRow = ranking?.querySelector(".chart-ranked-list-row");
    if (!ranking || !component || !firstRow) return undefined;
    const layoutItem = component.closest(".sortable-item") ?? component;
    const layout = layoutItem.parentElement;

    let frame;
    const updateCapacity = () => {
      const itemBounds = layoutItem.getBoundingClientRect();
      const adjacent = [...(layout?.children ?? [])].some((candidate) => {
        if (candidate === layoutItem || candidate.querySelector(".chart-ranked-list")) return false;
        const bounds = candidate.getBoundingClientRect();
        return bounds.width > 0 && bounds.height > 0 && Math.abs(bounds.top - itemBounds.top) < 2;
      });
      if (!adjacent) {
        setFittedRankingRows((current) => current === minimumRankingRows ? current : minimumRankingRows);
        return;
      }
      const componentStyle = getComputedStyle(component);
      const rankingStyle = getComputedStyle(ranking);
      const toggle = component.querySelector(".chart-ranked-list-toggle");
      const toggleStyle = toggle ? getComputedStyle(toggle) : null;
      const toggleHeight = toggle
        ? toggle.getBoundingClientRect().height + Number.parseFloat(toggleStyle.marginTop || "0")
        : 0;
      const availableHeight = component.getBoundingClientRect().bottom
        - Number.parseFloat(componentStyle.paddingBottom || "0")
        - ranking.getBoundingClientRect().top
        - toggleHeight;
      const capacity = rankedListCapacity({
        availableHeight,
        rowHeight: firstRow.getBoundingClientRect().height,
        rowGap: Number.parseFloat(rankingStyle.rowGap || "0"),
        minimumCount: minimumRankingRows,
        totalCount: rows.length,
      });
      setFittedRankingRows((current) => current === capacity ? current : capacity);
    };
    const scheduleCapacity = () => {
      if (frame) cancelAnimationFrame(frame);
      frame = requestAnimationFrame(updateCapacity);
    };
    scheduleCapacity();
    if (typeof ResizeObserver !== "function") return () => cancelAnimationFrame(frame);
    const observer = new ResizeObserver(scheduleCapacity);
    observer.observe(component);
    observer.observe(firstRow);
    if (layout) observer.observe(layout);
    return () => {
      observer.disconnect();
      if (frame) cancelAnimationFrame(frame);
    };
  }, [minimumRankingRows, rankingExpanded, rows.length, type]);
  const groupedRows = type === "pie" ? pieRows : seriesRows;
  const displayedCategories = new Set(groupedRows.map((row) => String(row[groupedField])));
  const groupedCategories = rows.map((row) => String(row[groupedField]))
    .filter((category) => !displayedCategories.has(category));
  const isVisible = (value) => {
    if (!controlledVisible) {
      if (String(value) === "Other" && groupedCategories.length) {
        return !hiddenSeries.has("Other") && groupedCategories.some((category) => !hiddenSeries.has(category));
      }
      return !hiddenSeries.has(String(value));
    }
    return controlledVisible.has(String(value))
      || String(value) === "Other" && groupedCategories.some((category) => controlledVisible.has(category));
  };
  const visibleFields = fields.filter(isVisible);
  const activeZoom = zoomRange ?? localZoom;
  const zoomable = ["line", "area", "stackedArea"].includes(type) && rows.some((row) => dateValue(row[x]));
  const plottedRows =
    zoomable && activeZoom?.start && activeZoom?.end
      ? seriesRows.filter((row) => String(row[x]) >= String(activeZoom.start) && String(row[x]) <= String(activeZoom.end))
      : seriesRows;
  const visibleRows = type === "pie" ? pieRows.filter((row) => isVisible(row[x])) : plottedRows;
  const sourceData = seriesValues.length ? pivot(plottedRows, x, series, y) : plottedRows;
  const numericTrend = ["line", "area", "stackedArea"].includes(type)
    && sourceData.length > 1 && sourceData.every((row) => typeof row[x] === "number" && Number.isFinite(row[x]));
  const continuousTime = ["line", "area", "stackedArea"].includes(type) && !barFields.length
    && sourceData.length > 0 && sourceData.every(row => dateValue(row[x]));
  const calendarChart = ["line", "area", "stackedArea", "bar", "stackedBar", "stackedBar100",
    "horizontalBar", "horizontalStackedBar", "horizontalStackedBar100"].includes(type);
  const data = numericTrend ? [...sourceData].sort((left, right) => left[x] - right[x])
    : continuousTime ? [...sourceData].sort((left, right) => Date.parse(left[x]) - Date.parse(right[x]))
    : calendarChart ? orderCalendarRows(sourceData, x, spec) : sourceData;
  const reviewedTimeValues = new Map(continuousTime ? data.map(row => [Date.parse(row[x]),row[x]]) : []);
  const originalAxisValue = value => continuousTime ? reviewedTimeValues.get(Number(value)) ?? value : value;
  const axisCoordinate = value => continuousTime && value != null ? Date.parse(value) : value;
  const rightFields = secondaryAxisFields({ ...spec, type }, data, fields);
  const annotations = bindChartAnnotationAxes(resolveChartAnnotations(spec, plottedRows, { data, visibleFields }), rightFields)
    .map(annotation => continuousTime ? {...annotation,x:axisCoordinate(annotation.x),xEnd:axisCoordinate(annotation.xEnd)} : annotation);
  const sorted = (source) => {
    if (!["ascending", "descending"].includes(spec.sortOrder)) return source;
    const value = (row) =>
      Number.isFinite(row[y]) ? row[y] : visibleFields.reduce((total, field) => total + (Number(row[field]) || 0), 0);
    const direction = spec.sortOrder === "descending" ? -1 : 1;
    return [...source].sort((left, right) => direction * (value(left) - value(right)));
  };
  const horizontal = type === "horizontalBar" || type === "leaderboard" || type.startsWith("horizontalStacked");
  const stacked = type.toLowerCase().includes("stacked");
  const proportional = type.endsWith("100");
  const barPoints = type === "bar" || type === "horizontalBar";
  const annotationRanges = chartAnnotationMarks(annotations, { horizontal, layer: "ranges" });
  const annotationMarks = chartAnnotationMarks(annotations, { horizontal, barPoints });
  const annotationLabels = annotations.length
    ? <ChartAnnotationLayer annotations={annotations} horizontal={horizontal} barPoints={barPoints}
      onPlacedChange={setPlacedAnnotationIds} /> : null;
  const ratio = ratioMetric(
    y,
    rows.map((row) => row[y]),
  );
  const leftFields = fields.filter((field) => !rightFields.includes(field));
  const separateAxes = rightFields.length > 0;
  const fieldAxis = (field) => rightFields.includes(field) ? "secondary" : 0;
  const valueIsRatio = (field) => seriesValues.length ? ratio : ratioMetric(field, data.map((row) => row[field]));
  const axisUnit = axisFields => percentageAxisMode(seriesValues.length ? [y] : axisFields, seriesValues.length ? rows : data);
  const axisRatio = axisFields => axisUnit(axisFields) === true;
  const formatMarkValue = (value, field = y) => formatChartValue(value, seriesValues.length ? y : field,
    { ratio: valueIsRatio(field), compactValue: true, decimals: spec.valueDecimals ?? 1, currency: spec.currency });
  const formatTooltipValue = (value, field = y) => formatChartValue(value, seriesValues.length ? y : field,
    { ratio: valueIsRatio(field), decimals: spec.valueDecimals ?? 1, currency: spec.currency });
  const wideMultiMeasure = !seriesValues.length && fields.length > 1;
  const yTitle = spec.yLabel ?? (type === "histogram" ? "Observations"
    : separateAxes ? leftFields.map(label).join(" / ") : wideMultiMeasure ? "" : label(y));
  const rightTitle = spec.rightYAxisLabel ?? rightFields.map(label).join(" / ");
  const xTitle = spec.xLabel ?? label(type === "histogram" ? y : x);
  const { x: showXAxisTitle, y: showYAxisTitle } = axisTitleVisibility(spec, separateAxes);
  const hasYAxisTitle = showYAxisTitle && Boolean(yTitle);
  const yAxisPosition = spec.yAxisPosition === "right" ? "right" : "left";
  const categoryAxisPosition = spec.type === "bar" && type === "horizontalBar" ? "left" : yAxisPosition;
  const flushRightYAxisTicks = !horizontal && yAxisPosition === "right" && !hasYAxisTitle;
  const chartMargin = {
    ...margin,
    left: hasYAxisTitle && yAxisPosition === "left" ? margin.left : 0,
    right: flushRightYAxisTicks ? 2 : margin.right,
    bottom: showXAxisTitle ? margin.bottom : 0,
  };
  const colorFor = ({ field, value, index = 0, dimension, explicitColor } = {}) => {
    const descriptor = { field: field ?? y, dimension, value, index, explicitColor };
    return explicitColor ?? resolveColor?.(descriptor) ?? semanticColor(descriptor);
  };
  const pieColor = (row) => {
    const index = rows.findIndex((candidate) => candidate[x] === row[x]);
    return colorFor({
      field: y,
      dimension: x,
      value: row[x],
      index: Math.max(index, 0),
      explicitColor: spec.colors?.[row[x]] ?? (index < 0 ? "var(--secondary)" : undefined),
    });
  };
  const fieldColor = (requested) => {
    const field = comparisonSeriesBase(requested, fields);
    return seriesValues.length
      ? colorFor({
          field: y,
          dimension: series,
          value: field,
          index: fields.indexOf(field),
          explicitColor: spec.colors?.[requested] ?? spec.colors?.[field] ?? gradients[requested]?.[0]?.color ?? (field === "Other" ? "var(--secondary)" : undefined),
        })
      : colorFor({ field, index: fields.indexOf(field), explicitColor: spec.colors?.[requested] ?? spec.colors?.[field] ?? gradients[requested]?.[0]?.color });
  };
  const numericAxisValues = data
    .flatMap((row) =>
      stacked
        ? [visibleFields.reduce((total, field) => total + (Number(row[field]) || 0), 0)]
        : visibleFields.map((field) => Number(row[field])),
    )
    .filter(Number.isFinite);
  const numericAxisMaximum = maximumValue(numericAxisValues.map(Math.abs), 0);
  const annotationFields = visibleFields.filter((field) => type !== "line" || !spec.barFields?.includes(field));
  const benchmarkDomain = useBenchmarkAnnotationDomain(annotations, data,
    annotationFields.filter((field) => fieldAxis(field) === 0), 0, height, spec.startAtZero !== false,
    separateAxes ? axisRatio(leftFields) : ratio);
  const secondaryBenchmarkDomain = useBenchmarkAnnotationDomain(annotations, data,
    annotationFields.filter((field) => fieldAxis(field) === "secondary"), "secondary", height,
    spec.startAtZero !== false, axisRatio(rightFields));
  const formatNumericAxisTick = numericAxisFormatter([...numericAxisValues, numericAxisMaximum * 1.25], {
    percent: proportional || ratio,
    currency: spec.currency,
  });
  const numericAxisTickLength = maximumValue(
    [...numericAxisValues, numericAxisMaximum * 1.25].map((value) => String(formatNumericAxisTick(value)).length),
    proportional ? 4 : 1,
  );
  const numericAxisWidth = Math.max(
    34,
    Math.min(82, Math.ceil(numericAxisTickLength * 7 + 14 + (hasYAxisTitle ? 20 : 0))),
  );
  const autoAxisWidth = fixedAxisWidths ? numericAxisWidth : "auto";
  const secondaryAxisValues = data.flatMap((row) => rightFields.map((field) => Number(row[field])))
    .filter(Number.isFinite);
  const formatSecondaryAxisTick = numericAxisFormatter(secondaryAxisValues, {
    percent: axisRatio(rightFields),
    currency: spec.currency,
  });
  const secondaryAxisTickLength = maximumValue(
    secondaryAxisValues.map((value) => String(formatSecondaryAxisTick(value)).length), 1);
  const secondaryNumericAxisWidth = Math.max(34, Math.min(fixedAxisWidths ? Infinity : 72,
    Math.ceil(secondaryAxisTickLength * 7 + (fixedAxisWidths ? 14 + (hasYAxisTitle && rightTitle ? 20 : 0) : 8))));
  const flushRightAxisWidth = Math.max(24, Math.min(72, Math.ceil(numericAxisTickLength * 7 + 4)));
  const categoryWidth = horizontal
    ? Math.max(54, Math.min(126, maximumValue(rows.map((row) => categoryLabel(x, row[x] ?? "").length * 8 + 18), 0)))
    : numericAxisWidth;
  const heatmapYAxisTitle = spec.yLabel ?? label(heatmapGroup);
  const heatmapCategoryWidth =
    type === "heatmap"
      ? Math.max(
          38,
          Math.min(160, maximumValue(rows.map((row) =>
            categoryLabel(heatmapGroup, row[heatmapGroup] ?? "").length * axisTickFontSize * 0.62 + 18), 0)),
        ) + (showYAxisTitle && heatmapYAxisTitle ? 18 : 0)
      : 86;
  const inlineHeatmapXAxisLabel = type === "heatmap" && spec.xLabelPosition === "inline-right" && showXAxisTitle;
  const referenceField = (field) => /(?:target|plan|forecast|projected|benchmark|previous)/iu.test(String(field));
  const dashedField = (field) => referenceField(field) || spec.dashedFields?.includes(field);
  const primaryValueField = visibleFields.find((field) => !referenceField(field)) ?? visibleFields[0];
  const themeElement =
    themeRoot?.host ?? themeRoot ?? (typeof document === "undefined" ? null : document.documentElement);
  const themeView = themeElement?.ownerDocument?.defaultView;
  const readThemeStyle =
    themeView?.getComputedStyle?.bind(themeView) ?? (typeof getComputedStyle === "function" ? getComputedStyle : null);
  const themeMarkRadius = !themeElement || !readThemeStyle
    ? 0
    : Number.parseFloat(readThemeStyle(themeElement).getPropertyValue("--mark-radius")) || 0;
  const configuredMarkRadius = Number(spec.markRadius);
  const configuredMarkStartRadius = Number(spec.markStartRadius);
  const markRadius = Number.isFinite(configuredMarkRadius) && configuredMarkRadius >= 0
    ? configuredMarkRadius
    : themeMarkRadius;
  const hasCustomStartRadius = Number.isFinite(configuredMarkStartRadius) && configuredMarkStartRadius >= 0;
  const markStartRadius = hasCustomStartRadius ? configuredMarkStartRadius : markRadius;
  const markCorners = (index, row) => {
    if (!stacked || visibleFields.length === 1) {
      if (hasCustomStartRadius) {
        return horizontal
          ? [markStartRadius, markRadius, markRadius, markStartRadius]
          : [markRadius, markRadius, markStartRadius, markStartRadius];
      }
      return [markRadius, markRadius, markRadius, markRadius];
    }
    const present = row
      ? visibleFields
          .map((field, position) => ({ position, value: Number(row[field]) }))
          .filter(({ value }) => Number.isFinite(value) && value !== 0)
      : visibleFields.map((_, position) => ({ position }));
    const first = present[0]?.position;
    const last = present.at(-1)?.position;
    if (index !== first && index !== last) return 0;
    if (horizontal) {
      if (first === last) return [markRadius, markRadius, markRadius, markRadius];
      return index === first
        ? [hasCustomStartRadius ? markStartRadius : markRadius, 0, 0, hasCustomStartRadius ? markStartRadius : markRadius]
        : [0, markRadius, markRadius, 0];
    }
    if (index === last) return [markRadius, markRadius, 0, 0];
    return hasCustomStartRadius && index === first ? [0, 0, markStartRadius, markStartRadius] : 0;
  };
  const selectMark =
    (field, sourceRows = data, markLabel) =>
    (entry, index, event) => {
      const row = entry?.payload ?? sourceRows[index] ?? {};
      // Retain React propagation control; explicit touch-detail actions supply a native target only.
      const markEvent = event?.target ? event : event?.nativeEvent;
      selectChartMark(
        {
          kind: "chart",
          chartType: type,
          label: markLabel ?? String(row[x] ?? entry?.name ?? label(field)),
          series: label(field),
          value: type === "waterfall" && row.isTotal ? row.runningTotal : row[field] ?? entry?.value,
          row,
          hoverCard: captureHoverCard(markEvent, row),
          actions: getMarkActions?.({ row, field }) ?? [],
        },
        markEvent,
      );
    };
  const suppressSelectionAfterZoom = useRef(false);
  const selectLinePoint = (chartState, event) => {
    if (suppressSelectionAfterZoom.current) {
      suppressSelectionAfterZoom.current = false;
      return;
    }
    const activeEntry =
      chartState?.activePayload?.find((entry) => visibleFields.includes(entry.dataKey)) ??
      chartState?.activePayload?.[0];
    const activeIndex = Number(chartState?.activeTooltipIndex);
    const row = activeEntry?.payload ?? (Number.isInteger(activeIndex) ? data[activeIndex] : null);
    const field = activeEntry?.dataKey ?? visibleFields[0];
    if (!row || !field) return;
    selectChartMark(
      {
        kind: "chart",
        chartType: type,
        label: String(row[x] ?? chartState?.activeLabel ?? label(field)),
        series: label(field),
        value: row[field] ?? activeEntry?.value,
        row,
        hoverCard: captureHoverCard(event?.nativeEvent ?? event, row),
        actions: getMarkActions?.({ row, field }) ?? [],
      },
      event,
    );
  };
  const axisPercentTicks = (axisFields, percent, includeZero = true) => {
    if (percent !== true || spec.axisPercentDigits !== 0) return undefined;
    if (proportional) return wholePercentTicks([0, 1]);
    const values = data.flatMap((row) => axisFields.filter(isVisible).map((field) => row[field]))
      .filter(value => value != null).map(Number).filter(Number.isFinite);
    if (!values.length) return undefined;
    const domain = [minimumValue(values, includeZero ? 0 : Infinity), maximumValue(values, includeZero ? 0 : -Infinity)];
    const ticks = wholePercentTicks(domain);
    return ticks.length ? ticks : undefined;
  };
  const primaryAxisPercent = proportional || (separateAxes ? axisUnit(leftFields) : axisUnit(visibleFields));
  const primaryPercentTicks = axisPercentTicks(leftFields, primaryAxisPercent, spec.startAtZero !== false);
  const secondaryAxisPercent = separateAxes && axisUnit(rightFields);
  const secondaryPercentTicks = axisPercentTicks(rightFields, secondaryAxisPercent, spec.startAtZero !== false);
  // Recharts supplies the visible, per-axis domain, including stacks and references.
  const valueDomain = spec.startAtZero === false ? ["dataMin", "auto"] : zeroAnchoredDomain;
  const ValueYAxis = horizontal ? YAxis : NumericYAxis;
  const hideCategoryTicks = spec.showCategoryTicks === false;
  const hideYAxisCategoryTicks = horizontal && hideCategoryTicks;
  const yAxis = (
    <ValueYAxis
      type={horizontal ? "category" : "number"}
      dataKey={horizontal ? x : undefined}
      {...(horizontal ? {} : { percent: primaryAxisPercent, ticks: benchmarkDomain ? undefined : primaryPercentTicks, currency: spec.currency })}
      percentDigits={spec.axisPercentDigits}
      tickCount={benchmarkDomain ? 6 : spec.yTickCount ?? 5}
      domain={!horizontal ? benchmarkDomain ?? valueDomain : undefined}
      tickFormatter={horizontal ? tick : undefined}
      axisLine={false}
      tickLine={false}
      tickMargin={horizontal || flushRightYAxisTicks ? 0 : 9}
      tickSize={horizontal || flushRightYAxisTicks ? 0 : undefined}
      tick={hideYAxisCategoryTicks ? false : horizontal
        ? <CategoryAxisTick field={x} horizontal width={categoryWidth} side={categoryAxisPosition} />
        : flushRightYAxisTicks
          ? { fontSize: 12, textAnchor: "end", dx: flushRightAxisWidth + chartMargin.right - 1 }
          : { fontSize: 12 }}
      interval={horizontal ? 0 : undefined}
      width={hideYAxisCategoryTicks ? 0 : horizontal ? categoryWidth
        : flushRightYAxisTicks ? flushRightAxisWidth : autoAxisWidth}
      orientation={horizontal ? categoryAxisPosition : yAxisPosition}
      label={
        horizontal || !hasYAxisTitle
          ? undefined
          : {
              value: yTitle,
              angle: yAxisPosition === "right" ? 90 : -90,
              position: yAxisPosition === "right" ? "insideRight" : "insideLeft",
              offset: 0,
              style: valueAxisLabelStyle,
            }
      }
    />
  );
  const SecondaryAxis = horizontal ? NumericXAxis : NumericYAxis;
  const secondaryAxis = separateAxes && <SecondaryAxis
    type="number"
    {...(horizontal ? { xAxisId: "secondary", orientation: "top", height: 44 }
      : { yAxisId: "secondary", orientation: yAxisPosition === "right" ? "left" : "right",
        width: yAxisPosition === "right" || fixedAxisWidths ? secondaryNumericAxisWidth : "auto" })}
    currency={spec.currency}
    percent={axisUnit(rightFields)}
    percentDigits={spec.axisPercentDigits}
    ticks={secondaryBenchmarkDomain ? undefined : secondaryPercentTicks}
    domain={secondaryBenchmarkDomain ?? valueDomain}
    tickCount={secondaryBenchmarkDomain ? 6 : undefined}
    axisLine={false} tickLine={false} tickMargin={9}
    tick={{ fontSize: 12, fill: rightFields.length === 1 ? fieldColor(rightFields[0]) : "var(--secondary)",
      ...(horizontal || yAxisPosition !== "right" || fixedAxisWidths
        ? {} : { textAnchor: "start", dx: -secondaryNumericAxisWidth + 4 }) }}
    label={!(horizontal ? showXAxisTitle : hasYAxisTitle) || !rightTitle ? undefined
      : { value: rightTitle, angle: horizontal ? 0 : yAxisPosition === "right" ? -90 : 90,
        position: horizontal ? "insideTop"
          : yAxisPosition === "right" ? "insideLeft" : "insideRight",
        style: { fill: "var(--secondary)", fontSize: 12, textAnchor: "middle" } }}
  />;
  const everyCategory =
    !horizontal && ["bar", "stackedBar", "stackedBar100", "waterfall"].includes(type) && !rows.some((row) => dateValue(row[x]));
  const temporalValues =
    !horizontal && data.length > 0 && data.every((row) => dateValue(row[x]))
      ? [...new Set(data.map((row) => row[x]))]
      : [];
  const categoryValues = everyCategory ? [...new Set(data.map((row) => row[x]))] : [];
  const categoryCount = categoryValues.length;
  const dateTimeCategories = !horizontal && !temporalValues.length && spec.xTickLabelLayout === "date-time";
  const angledCategories = everyCategory && !dateTimeCategories
    && categoryAxisLayout(categoryValues.map((value) => categoryLabel(x, value)),
      { preference: spec.xTickLabelLayout }) === "angled";
  const quantitativeXAxis = !horizontal && numericTrend && new Set(data.map((row) => row[x])).size > 1;
  const numericXValues = quantitativeXAxis ? data.map((row) => row[x]) : [];
  const numericXDomain = quantitativeXAxis ? [minimumValue(numericXValues), maximumValue(numericXValues)] : null;
  const integerXAxis = numericXValues.every(Number.isInteger);
  const hideXAxisCategoryTicks = !horizontal && !quantitativeXAxis && hideCategoryTicks;
  const numericXTicks = quantitativeXAxis
    ? [...new Set([numericXDomain[0], ...getNiceTickValues(numericXDomain, 5, !integerXAxis)
      .filter((value) => value > numericXDomain[0] && value < numericXDomain[1]), numericXDomain[1]])]
    : [];
  const ValueXAxis = horizontal || quantitativeXAxis ? NumericXAxis : temporalValues.length ? TemporalXAxis : XAxis;
  const xAxis = (
    <ValueXAxis
      {...(temporalValues.length ? { values:temporalValues, continuous:continuousTime, banded:barFields.length > 0 || ["bar","stackedBar","stackedBar100"].includes(type) } : {})}
      type={horizontal || quantitativeXAxis ? "number" : "category"}
      dataKey={horizontal ? undefined : continuousTime ? row => Date.parse(row[x]) : x}
      {...(horizontal ? { percent: primaryAxisPercent, currency: spec.currency } : quantitativeXAxis ? { allowDecimals: !integerXAxis } : {})}
      percentDigits={horizontal ? spec.axisPercentDigits : undefined}
      tickCount={horizontal && benchmarkDomain ? 6 : horizontal && !proportional ? 4 : undefined}
      domain={quantitativeXAxis ? numericXDomain : horizontal ? benchmarkDomain ?? valueDomain : undefined}
      axisLine={false}
      tickLine={false}
      tickMargin={8}
      minTickGap={18}
      ticks={horizontal && !benchmarkDomain && primaryPercentTicks?.length ? primaryPercentTicks : quantitativeXAxis ? numericXTicks : undefined}
      interval={everyCategory ? 0 : quantitativeXAxis ? "preserveStartEnd" : undefined}
      height={hideXAxisCategoryTicks ? 0 : angledCategories ? 76 : everyCategory || dateTimeCategories ? 44 : 30}
      tick={
        hideXAxisCategoryTicks ? false : everyCategory || dateTimeCategories ? (
          <CategoryAxisTick field={x} count={categoryCount} angled={angledCategories} layout={spec.xTickLabelLayout} />
        ) : (
          { fontSize: 12 }
        )
      }
      tickFormatter={horizontal || quantitativeXAxis ? undefined : tick}
    />
  );
  const explicitFieldColors = fields.some(field => spec.colors?.[field]);
  const explicitCategoryColors = rows.some(row => typeof spec.colors?.[row[x]] === "string");
  // Legend visibility never changes whether color identifies a measure or a category.
  const singleLogicalSeries = fields.length > 0 && fields.every(field =>
    comparisonSeriesBase(field, fields) === comparisonSeriesBase(fields[0], fields));
  const signedBarColors = !stacked && ["bar", "horizontalBar", "leaderboard"].includes(type)
    && fields.length === 1 && !explicitFieldColors && !explicitCategoryColors && spec.colorBySign !== false
    && (spec.colorBySign === true ||
      (data.some(row => Number(row[fields[0]]) < 0) && data.some(row => Number(row[fields[0]]) > 0)));
  const signColor = value => Number(value) < 0 ? "var(--negative)" : Number(value) > 0 ? "var(--positive)" : "var(--secondary)";
  const categoryTooltipColors = !stacked && !signedBarColors
    && ["bar", "horizontalBar", "leaderboard", "pie", "funnel"].includes(type)
    && singleLogicalSeries && !explicitFieldColors && (semanticCategoryDimension(x) || explicitCategoryColors);
  const hoverHighlight = spec.hoverHighlight && typeof spec.hoverHighlight === "object"
    ? spec.hoverHighlight
    : spec.hoverHighlight
      ? {}
      : null;
  const tooltipCursor = ["heatmap", "scatter"].includes(type)
    ? false
    : hoverHighlight
      ? {
          fill: "none",
          stroke: hoverHighlight.color ?? "color-mix(in srgb, var(--text) 5%, transparent)",
          strokeWidth: Number(hoverHighlight.width) || 42,
          strokeLinecap: "round",
        }
      : { fill: "var(--text)", fillOpacity: 0.06 };
  const tooltipTemplate = tooltipContent ??
        <ChartTooltip
          stacked={stacked}
          vertical={["line", "area", "sparkline"].includes(type)}
          mode={["heatmap", "scatter", "boxPlot", "pie"].includes(type) ? type : "default"}
          xField={x}
          yField={y}
          groupField={heatmapGroup}
          detailFields={spec.tooltipFields}
          xLabel={xTitle}
          yLabel={yTitle}
          formatValue={type === "histogram" ? displayValue : formatTooltipValue}
          comparisonMode={spec.legend?.comparisons === "grouped"}
          baseField={field => comparisonSeriesBase(field,fields)}
          formatLabel={item => {
            const field = String(item.dataKey ?? item.name);
            const paired = /previous/i.test(field);
            const source = rows.find(row => row[x] === item.payload?.[x] && (!series || row[series] === field)) ?? item.payload;
            const priorDate = source?.previousPeriodStart ?? source?.comparisonStart ?? (source?.comparison === "Previous" ? source.periodStart : null);
            const base = comparisonSeriesBase(field,fields);
            const name = spec.legend?.labels?.[base] ?? (series ? categoryLabel(series, base) : compactChartLabel(base));
            return paired ? (priorDate ? String(tick(priorDate)) : "Previous") : name;
          }}
          resolveStyle={item => ({ type: /previous/i.test(item.dataKey) ? ["bar","horizontalBar"].includes(type) ? "previous-bar" : "previous" : "current", opacity:/previous/i.test(item.dataKey) ? .45 : 1 })}
          resolveColor={
            signedBarColors ? item => signColor(item.value) : categoryTooltipColors
              ? (item) =>
                  type === "pie"
                    ? pieColor(item.payload)
                    : colorFor({
                        field: y,
                        dimension: x,
                        value: item.payload?.[x],
                        index: rows.findIndex((row) => row[x] === item.payload?.[x]),
                        explicitColor: spec.colors?.[item.payload?.[x]],
                      })
              : item => fieldColor(String(item.dataKey ?? item.name))
          }
        />;
  const pointerTooltip = ["heatmap", "pie", "scatter", "area", "stackedArea"].includes(type);
  const tooltip = (
    <PointerChartTooltip
      frameRef={frameRef}
      touchOnly={!pointerTooltip}
      touchPreview={["heatmap", "scatter", "pie"].includes(type)}
      active={type === "heatmap" && heatHover ? true : undefined}
      filterNull={type === "heatmap" ? false : undefined}
      content={props => {
        if (continuousTime) props = {...props,label:originalAxisValue(props.label)};
        const content = React.isValidElement(tooltipTemplate) ? React.cloneElement(tooltipTemplate, props)
          : typeof tooltipTemplate === "function" ? tooltipTemplate(props) : tooltipTemplate;
        if (props.active && props.payload?.length) latestHover.current = { row: props.payload[0]?.payload };
        return content;
      }}
      itemSorter={() => 0}
      labelFormatter={(value) => categoryLabel(x, tooltipLabel(value))}
      isAnimationActive={false}
      cursor={tooltipCursor}
    />
  );
  const fullLegend =
    type === "pie"
      ? pieRows.map((row) => ({
          label: categoryLabel(x, row[x]),
          value: String(row[x]),
          color: pieColor(row),
          visible: isVisible(row[x]),
        }))
      : type !== "heatmap" && fields.length > 1
        ? fields.map((field, index) => ({
            label: spec.legend?.labels?.[field] ?? (series ? categoryLabel(series, field) : label(String(field))),
            value: String(field),
            color:
              categoryTooltipColors && fields.length > 1 ? "var(--secondary)" : ["line", "sparkline"].includes(type) && referenceField(field) && !/previous/i.test(field) && !spec.colors?.[field]
                ? "var(--secondary)" : fieldColor(field),
            opacity:
              ["line", "sparkline"].includes(type) && referenceField(field) && !spec.colors?.[field] ? /previous/i.test(field) ? .45 : .7 : /previous/i.test(field) ? .3 : undefined,
            visible: isVisible(field),
            type:
              ["line", "sparkline"].includes(type) && !barFields.includes(field)
                ? dashedField(field)
                  ? "line line-dashed"
                  : "line"
                : /previous/i.test(field) ? "square square-previous" : "square",
          }))
        : [];
  const comparisonFields = fields.filter(field => /previous/i.test(field));
  const groupedComparison = spec.legend?.comparisons === "grouped" && comparisonFields.length > 1;
  const legend = groupedComparison ? fullLegend.filter(item => !comparisonFields.includes(item.value)).map(item => {
    const pair = fields.filter(field => comparisonSeriesBase(field,fields) === item.value);
    return { ...item,value:pair,visible:pair.some(isVisible) };
  }) : fullLegend;
  const sourceCategoryIdentities = (values) => [...new Set([...values].flatMap((value) =>
    String(value) === "Other" && groupedCategories.length ? groupedCategories : [String(value)]))];
  const persistVisibleSeries = (all, next) => {
    const visibleCategories = sourceCategoryIdentities(next);
    if (onVisibleSeriesChange) onVisibleSeriesChange(visibleCategories);
    else {
      const selected = new Set(visibleCategories);
      setHiddenSeries(new Set(sourceCategoryIdentities(all).filter((category) => !selected.has(category))));
    }
  };
  const toggleSeries = (value) => {
    const all = type === "pie" ? pieRows.map((row) => String(row[x])) : fields.map(String);
    const next = new Set(all.filter(isVisible));
    const targets = Array.isArray(value) ? value : [String(value)];
    const hide = targets.every(field => next.has(field));
    for (const field of targets) { if (hide) next.delete(field); else next.add(field); }
    if (!next.size) return;
    persistVisibleSeries(all, next);
  };
  const isolateSeries = (value) => {
    const all = type === "pie" ? pieRows.map((row) => String(row[x])) : fields.map(String);
    const active = all.filter(isVisible);
    const targets = Array.isArray(value) ? value : [String(value)];
    const next = active.length === targets.length && targets.every(field => active.includes(field)) ? new Set(all) : new Set(targets);
    persistVisibleSeries(all, next);
  };
  const setZoom = (next) => {
    if (onZoomChange) onZoomChange(next);
    else setLocalZoom(next);
  };
  const interactionProps = zoomable
    ? {
        onMouseDown: (state) => {
          suppressSelectionAfterZoom.current = false;
          if (state?.activeLabel != null)
            setSelection({ start: String(originalAxisValue(state.activeLabel)), end: String(originalAxisValue(state.activeLabel)) });
        },
        onMouseMove: (state) => {
          if (selection && state?.activeLabel != null) {
            setSelection((current) => (current ? { ...current, end: String(originalAxisValue(state.activeLabel)) } : null));
          }
        },
        onMouseUp: (state) => {
          if (!selection) return;
          const end = String(originalAxisValue(state?.activeLabel ?? selection.end));
          const range = normalizeZoomRange(rows, x, selection.start, end);
          if (range) {
            suppressSelectionAfterZoom.current = true;
            setZoom(range);
          }
          setSelection(null);
        },
        onMouseLeave: () => setSelection(null),
      }
    : {};
  const selectedArea =
    selection && selection.start !== selection.end ? (
      <ReferenceArea
        x1={axisCoordinate(selection.start)}
        x2={axisCoordinate(selection.end)}
        fill="var(--accent)"
        fillOpacity={0.12}
        stroke="var(--accent)"
        strokeOpacity={0.35}
      />
    ) : null;

  if (categoricalEnabled && type === "rankedList") {
    const ordered = spec.sortOrder ? sorted(data) : [...data].sort((left, right) => Number(right[y]) - Number(left[y]));
    const maximum = maximumValue(ordered.map((row) => Number(row[y]) || 0), 0);
    const initialVisibleCount = Math.min(ordered.length, Math.max(minimumRankingRows, fittedRankingRows));
    const visibleRankings = rankingExpanded ? ordered : ordered.slice(0, initialVisibleCount);
    return (
      <>
        <div
          ref={rankingListRef}
          className="chart-ranked-list"
          role="list"
          aria-label={`${label(y)} by ${label(x)}`}
          data-chart-id={chartId}
          data-ranked-list-variant={spec.variant ?? "inset"}
        >
          {visibleRankings.map((row, index) => {
            const value = Number(row[y]);
            const reviewedLabel = categoryLabel(x, row[x]);
            const width =
              Number.isFinite(value) && maximum > 0 ? `${Math.max(0, Math.min(100, (value / maximum) * 100))}%` : "0%";
            const categoryColor = spec.colors?.[row[x]];
            const rankedFill = categoryColor ? {
              width,
              "--ranked-list-fill": `color-mix(in srgb, ${categoryColor} 18%, var(--surface))`,
              "--ranked-list-fill-hover": `color-mix(in srgb, ${categoryColor} 26%, var(--surface))`,
            } : { width };
            return (
              <button
                key={`${String(row[x])}-${index}`}
                type="button"
                role="listitem"
                className="chart-ranked-list-row"
                aria-label={`${reviewedLabel}: ${formatMarkValue(value, y)}`}
                onClick={(event) => selectMark(y, ordered, reviewedLabel)({ payload: row }, index, event)}
              >
                <span className="chart-ranked-list-fill" style={rankedFill} aria-hidden="true" />
                <span className="chart-ranked-list-label">{reviewedLabel}</span>
                <span className="chart-ranked-list-value">{formatMarkValue(value, y)}</span>
              </button>
            );
          })}
        </div>
        {ordered.length > initialVisibleCount && (
          <button
            type="button"
            className="chart-ranked-list-toggle"
            aria-expanded={rankingExpanded}
            onClick={() => {
              if (rankingExpanded) setFittedRankingRows(minimumRankingRows);
              setRankingExpanded((expanded) => !expanded);
            }}
          >
            {rankingExpanded ? "Show fewer" : `Show ${ordered.length - initialVisibleCount} more`}
          </button>
        )}
      </>
    );
  }

  if (categoricalEnabled && type === "funnel") return <div role="group" aria-label={accessibleLabel || `${label(y)} by ${label(x)}`}>
    <FunnelRenderer rows={rows} x={x} y={y} height={height} chartId={chartId}
    formatValue={formatMarkValue} colorFor={(stage) => spec.colors?.[stage.__funnelStage]
      ?? colorFor({ field: y, index: 0, explicitColor: spec.colors?.[y] })}
    formatExactValue={valueIsRatio(y) ? (value) => new Intl.NumberFormat(undefined,
      { style: "percent", maximumSignificantDigits: 15 }).format(value) : undefined}
    formatDropoff={valueIsRatio(y) ? (value) => `${new Intl.NumberFormat(undefined, { maximumSignificantDigits: 15 }).format(value * 100)} pp` : undefined}
    onChartClick={(event) => selectChartSection({ kind: "chart", chartType: type, label: "Chart" }, event.nativeEvent)}
    onSelect={selectionEnabled || getMarkActions ? (row, index, event) => selectMark(y, rows)({ payload: row }, index, event) : undefined} />
  </div>;

  let chart;
  let scaleLegend;

  if (categoricalEnabled && type === "pie") {
    chart = <PieRenderer spec={spec} rows={sorted(visibleRows)} colorFor={pieColor}
      onSelect={(row, event) => selectMark(y)({ payload: row }, 0, event)}>{tooltip}</PieRenderer>;
  } else if (flowEnabled && type === "sankey") {
    chart = <SankeyRenderer rows={rows} stages={sankeyStages} spec={spec} colorFor={colorFor}
      onSelection={onSankeySelection} />;
  } else if (cartesianEnabled && type === "histogram") {
    const buckets = histogram(rows, y).map((bucket) => ({
      ...bucket,
      range: `${compact(bucket.start)}–${compact(bucket.end)}`,
    }));
    chart = (
      <BarChart data={buckets} margin={chartMargin} barCategoryGap="2%" accessibilityLayer>
        {grid}
        <XAxis dataKey="range" axisLine={false} tickLine={false} tickMargin={10} interval={0} height={30}
          tick={<CategoryAxisTick field="range" count={buckets.length} />} />
        {React.cloneElement(yAxis, { domain: [0, "auto"], allowDecimals: false, percent: false,
          percentDigits: undefined, currency: undefined, ticks: undefined })}
        {tooltip}
        <Bar
          dataKey="count"
          fill={fieldColor(y)}
          radius={[Math.min(markRadius, 3), Math.min(markRadius, 3), 0, 0]}
          isAnimationActive={false}
          onClick={selectMark("count", buckets)}
        >
          {spec.showValues && (
            <LabelList dataKey="count" position="top" formatter={compact} fill="var(--secondary)" fontSize={12} />
          )}
        </Bar>
      </BarChart>
    );
  } else if (categoricalEnabled && type === "heatmap") {
    const heat = heatmap(rows, x, heatmapGroup, y, {
      domain: spec.colorDomain,
      startAtZero: spec.colorScaleStartAtZero,
      missingValues: spec.missingValues,
      xOrder: spec.categoryOrder,
      yOrder: spec.seriesOrder,
    });
    scaleLegend = {
      label: yTitle,
      color: spec.baseColor ?? colors[0],
      minimum: formatMarkValue(heat.minimum),
      maximum: formatMarkValue(heat.maximum),
      bands: Array.isArray(spec.colorBands) ? spec.colorBands : undefined,
    };
    chart = <HeatmapRenderer spec={spec} heat={heat} groupField={heatmapGroup}
      layout={{ margin: chartMargin, categoryWidth: heatmapCategoryWidth,
        yAxisTitle: heatmapYAxisTitle, showXAxisTitle, showYAxisTitle }}
      markRadius={markRadius} formatValue={formatMarkValue} onHover={setHeatHover}
      onSelect={selectionEnabled || getMarkActions
        ? (row, event) => selectMark(y)({ payload: row }, 0, event) : undefined}>
      {tooltip}
    </HeatmapRenderer>;
  } else if (cartesianEnabled && type === "scatter") {
    const ScatterXAxis = numeric.includes(x) ? NumericXAxis : XAxis;
    chart = (
      <ScatterChart margin={chartMargin} accessibilityLayer>
        <CartesianGrid stroke="var(--border)" strokeWidth={0.5} />
        <ScatterXAxis
          type={numeric.includes(x) ? "number" : "category"}
          dataKey={x}
          {...(numeric.includes(x)
            ? {
                percent: ratioMetric(
                  x,
                  rows.map((row) => row[x]),
                ),
              }
            : { tickFormatter: tick })}
          axisLine={false}
          tickLine={false}
          tickMargin={10}
          height={30}
        />
        <NumericYAxis
          orientation={yAxisPosition}
          type="number"
          dataKey={y}
          domain={spec.startAtZero === false ? ["dataMin", "auto"] : undefined}
          percent={ratio}
          width={autoAxisWidth}
          axisLine={false}
          tickLine={false}
          tickMargin={9}
          label={
            !showYAxisTitle || !yTitle
              ? undefined
              : {
                  value: yTitle,
                  angle: yAxisPosition === "right" ? 90 : -90,
                  position: yAxisPosition === "right" ? "insideRight" : "insideLeft",
                  offset: 0,
                  style: { fill: "var(--secondary)", fontSize: 12, textAnchor: "middle" },
                }
          }
        />
        {tooltip}
        {seriesValues.length ? (
          seriesValues.filter(isVisible).map((value) => (
            <Scatter
              key={value}
              name={String(value)}
              data={rows.filter((row) => row[series] === value)}
              fill={fieldColor(value)}
              isAnimationActive={false}
              onClick={selectMark(
                y,
                rows.filter((row) => row[series] === value),
              )}
            >
              {spec.showValues && (
                <LabelList dataKey={y} position="top" formatter={compact} fill="var(--secondary)" fontSize={12} />
              )}
            </Scatter>
          ))
        ) : (
          <Scatter data={rows} fill={fieldColor(y)} isAnimationActive={false} onClick={selectMark(y, rows)}>
            {spec.showValues && (
              <LabelList dataKey={y} position="top" formatter={compact} fill="var(--secondary)" fontSize={12} />
            )}
          </Scatter>
        )}
      </ScatterChart>
    );
  } else if (cartesianEnabled && type === "waterfall") {
    const bridge = waterfall(rows, y, {
      categoryField: x,
      beginning: Number.isFinite(spec.beginning) ? spec.beginning : undefined,
      ending: Number.isFinite(spec.ending) ? spec.ending : undefined,
      includeEnding: true,
    }).map((row) => ({
      ...row,
      __waterfallLabel: row.isTotal
        ? compact(row.balance)
        : row.change > 0
          ? `+${compact(row.change)}`
          : compact(row.change).replace(/^-/, "−"),
    }));
    const focusedDomain = spec.startAtZero === false ? waterfallValueDomain(bridge) : undefined;
    const waterfallAxis = focusedDomain
      ? React.cloneElement(yAxis, { domain: focusedDomain, allowDataOverflow: true })
      : yAxis;
    chart = (
      <BarChart data={bridge} margin={{ ...chartMargin, top: 26 }} accessibilityLayer>
        {grid}
        {xAxis}
        {waterfallAxis}
        {tooltip}
        <Bar
          dataKey="range"
          radius={[markRadius, markRadius, markRadius, markRadius]}
          shape={<WaterfallShape />}
          isAnimationActive={false}
          onClick={selectMark(y, bridge)}
        >
          {bridge.map((row, index) => (
            <Cell
              key={index}
              fill={
                row.isTotal
                  ? "var(--chart-neutral-fill, color-mix(in srgb, var(--text) 3%, var(--surface)))"
                  : row.change < 0
                    ? "var(--negative)"
                    : "var(--positive)"
              }
            />
          ))}
          <LabelList dataKey="__waterfallLabel" position="top" fill="var(--secondary)" fontSize={12} offset={5} />
        </Bar>
      </BarChart>
    );
  } else if (cartesianEnabled && type === "boxPlot") {
    const boxes = boxPlots(rows, x, y);
    const whiskerMaximum = maximumValue(boxes.map((box) => Number(box.maximum) || 0), 1);
    chart = (
      <ComposedChart data={boxes} margin={{ ...chartMargin, top: 20 }} barCategoryGap="38%" accessibilityLayer>
        {grid}
        <XAxis
          dataKey={x}
          axisLine={false}
          tickLine={false}
          tickMargin={10}
          interval={0}
          height={44}
          tick={<CategoryAxisTick field={x} count={boxes.length} />}
        />
        <NumericYAxis
          orientation={yAxisPosition}
          domain={[0, whiskerMaximum * 1.12]}
          width={autoAxisWidth}
          tickCount={5}
          axisLine={false}
          tickLine={false}
          tickMargin={9}
          label={
            !showYAxisTitle || !yTitle
              ? undefined
              : {
                  value: yTitle,
                  angle: yAxisPosition === "right" ? 90 : -90,
                  position: yAxisPosition === "right" ? "insideRight" : "insideLeft",
                  offset: 0,
                  style: { fill: "var(--secondary)", fontSize: 12, textAnchor: "middle" },
                }
          }
        />
        {tooltip}
        <Bar dataKey="lowerQuartile" stackId="box" maxBarSize={66} fill="transparent" isAnimationActive={false} />
        <Bar
          dataKey="spread"
          stackId="box"
          maxBarSize={66}
          shape={<BoxShape />}
          isAnimationActive={false}
          onClick={selectMark("median", boxes)}
        >
          {boxes.map((box, index) => (
            <Cell
              key={String(box[x])}
              fill={colorFor({ field: y, dimension: x, value: box[x], index, explicitColor: spec.colors?.[box[x]] })}
            />
          ))}
        </Bar>
      </ComposedChart>
    );
  } else if (trendEnabled && ["line", "sparkline"].includes(type)) {
    const TrendChart = barFields.length && type === "line" ? ComposedChart : LineChart;
    const lineFields = visibleFields.filter((field) => !barFields.includes(field));
    const isolatedPoints = new Map(
      type === "line" ? lineFields.map((field) => [field, new Set(isolatedPointIndexes(data, field))]) : [],
    );
    chart = (
      <TrendChart
        data={data}
        margin={type === "sparkline" ? { top: 8, right: 8, bottom: 8, left: 8 } : chartMargin}
        {...(type === "sparkline" ? {} : interactionProps)}
        accessibilityLayer
        onClick={selectLinePoint}
      >
        <defs>{lineFields.map((field,index) => gradients[field] && <linearGradient key={field} id={gradientId+"-line-"+index} x1="0" y1="0" x2="100%" y2="0">
          {gradients[field].map((stop,i) => <stop key={i} offset={stop.offset} stopColor={stop.color} />)}
        </linearGradient>)}</defs>
        {type !== "sparkline" && grid}
        {type !== "sparkline" && xAxis}
        {type !== "sparkline" && yAxis}
        {secondaryAxis}
        {barFields.length > 0 && (
          <NumericYAxis
            yAxisId="weekly-change"
            orientation={yAxisPosition === "right" ? "left" : "right"}
            width={autoAxisWidth}
            axisLine={false}
            tickLine={false}
            tickMargin={7}
            tick={{ fontSize: 12 }}
          />
        )}
        {selectedArea}
        {annotationRanges}
        {tooltip}
        {barFields.filter(isVisible).map((field) => (
          <Bar
            key={`bar-${field}`}
            yAxisId="weekly-change"
            dataKey={field}
            stackId="weekly-growth"
            fill={fieldColor(field)}
            fillOpacity={0.9}
            radius={[markRadius, markRadius, markRadius, markRadius]}
            maxBarSize={28}
            isAnimationActive={false}
          />
        ))}
        {lineFields.map((field,index) => (
          <Line
            key={field}
            yAxisId={fieldAxis(field)}
            type="monotone"
            dataKey={field}
            stroke={gradients[field] ? `url(#${gradientId}-line-${index})` : /previous/i.test(field) ? fieldColor(field) : referenceField(field) && !spec.colors?.[field] ? "var(--secondary)" : fieldColor(field)}
            strokeWidth={dashedField(field) ? 1.5 : 2.25}
            strokeOpacity={/previous/i.test(field) ? 0.45 : referenceField(field) && !spec.colors?.[field] ? 0.7 : dashedField(field) ? 0.62 : undefined}
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeDasharray={dashedField(field) ? "5 4" : undefined}
            connectNulls={false}
            dot={getMarkActions && !referenceField(field) ? <ExploreDot first={field === primaryValueField} firstIndex={data.findIndex(row => Number.isFinite(row[field]))} isolated={isolatedPoints.get(field)}
              label={row => `${tick(row[x])}: ${formatTooltipValue(row[field], field)}. Open actions`}
              onSelect={(row, event) => selectMark(field)({ payload: row }, 0, event)} />
              : isolatedPoints.get(field)?.size ? <IsolatedLineDot indexes={isolatedPoints.get(field)} /> : false}
            activeDot={{ r: 5, strokeWidth: 3, stroke: "var(--surface)" }}
            isAnimationActive={false}
          >
            {spec.showValues && field === primaryValueField && (
              <LabelList dataKey={field} content={<SparseValueLabel count={data.length} />} />
            )}
          </Line>
        ))}
        {annotationMarks}
        {annotationLabels}
      </TrendChart>
    );
  } else if (trendEnabled && ["area", "stackedArea"].includes(type)) {
    chart = (
      <AreaChart data={data} margin={chartMargin} {...interactionProps} accessibilityLayer>
        {grid}
        {xAxis}
        {yAxis}
        {secondaryAxis}
        {selectedArea}
        {annotationRanges}
        {tooltip}
        {visibleFields.map((field) => (
          <Area
            key={field}
            yAxisId={fieldAxis(field)}
            dataKey={field}
            type="monotone"
            stackId={stacked ? "stack" : undefined}
            stroke={fieldColor(field)}
            fill={fieldColor(field)}
            fillOpacity={stacked ? 0.5 : 0.18}
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            isAnimationActive={false}
            onClick={selectMark(field, data)}
          >
            {spec.showValues && field === primaryValueField && (
              <LabelList dataKey={field} content={<SparseValueLabel count={data.length} />} />
            )}
          </Area>
        ))}
        {annotationMarks}
        {annotationLabels}
      </AreaChart>
    );
  } else if (barsEnabled) {
    const ordered = spec.sortOrder
      ? sorted(data)
      : type === "leaderboard"
        ? [...data].sort((left, right) => right[y] - left[y])
        : data;
    const categoryColors = categoryTooltipColors;
    const barChartMargin = horizontal && (type === "leaderboard" || spec.showValues)
      ? { ...chartMargin, right: 58 }
      : !horizontal && spec.showValues
        ? { ...chartMargin, top: Math.max(chartMargin.top, 24) }
        : chartMargin;
    chart = (
      <BarChart
        key={stacked ? visibleFields.join("|") : undefined}
        data={ordered}
        margin={barChartMargin}
        layout={horizontal ? "vertical" : "horizontal"}
        accessibilityLayer
        barCategoryGap={orderedDistribution(spec, rows) ? "3%" : "24%"}
        stackOffset={proportional ? "expand" : stacked ? "sign" : "none"}
      >
        <CartesianGrid stroke="var(--border)" strokeWidth={0.5} vertical={horizontal} horizontal={!horizontal} />
        {xAxis}
        {yAxis}
        {secondaryAxis}
        {annotationRanges}
        {tooltip}
        {visibleFields.map((field, index) => (
          <Bar
            key={field}
            {...(horizontal ? { xAxisId: fieldAxis(field) } : { yAxisId: fieldAxis(field) })}
            dataKey={field}
            stackId={stacked ? "stack" : undefined}
            fill={fieldColor(field)}
            fillOpacity={/previous/i.test(field) ? 0.24 : 1}
            stroke={/previous/i.test(field) ? fieldColor(field) : undefined}
            strokeDasharray={/previous/i.test(field) ? "3 2" : undefined}
            strokeWidth={/previous/i.test(field) ? 1.25 : 0}
            radius={markCorners(index)}
            shape={
              stacked ? (
                <StackedMarkShape fields={visibleFields} field={field} horizontal={horizontal} radius={markRadius} />
              ) : getMarkActions ? <ExploreBar
                label={row => `${row[x]}: ${formatTooltipValue(row[field], field)}. Open actions`}
                onSelect={(row, event) => selectMark(field, ordered)({ payload: row }, 0, event)} /> : undefined
            }
            isAnimationActive={false}
            onClick={selectMark(field, ordered)}
          >
            {(categoryColors || stacked || signedBarColors) &&
              ordered.map((row, rowIndex) => (
                <Cell
                  key={`${String(row[x])}-${rowIndex}`}
                  {...(signedBarColors
                    ? { fill: signColor(row[field]) }
                    : categoryColors
                      ? {
                          fill: colorFor({
                            field: y,
                            dimension: x,
                            value: row[x],
                            index: rowIndex,
                            explicitColor: spec.colors?.[row[x]],
                          }),
                          stroke: /previous/i.test(field) ? colorFor({ field:y,dimension:x,value:row[x],index:rowIndex,explicitColor:spec.colors?.[row[x]] }) : undefined,
                        }
                      : {})}
                  {...(stacked ? { radius: markCorners(index, row) } : {})}
                />
              ))}
            {(type === "leaderboard" || spec.showValues) && (
              <LabelList
                dataKey={field}
                position={horizontal && categoryAxisPosition === "right" ? "insideRight" : horizontal ? "right" : "top"}
                formatter={(value) => formatMarkValue(value, field)}
                content={horizontal && signedBarColors && categoryAxisPosition !== "right"
                  ? <SignedHorizontalValueLabel formatValue={value => formatMarkValue(value, field)} />
                  : undefined}
              />
            )}
          </Bar>
        ))}
        {annotationMarks}
        {annotationLabels}
      </BarChart>
    );
  }

  const chartHeight = horizontal
    ? Math.max(height, data.length * (Number(spec.rowHeight) || 42))
    : type === "heatmap"
      ? Math.max(
          height,
          Math.min(
            460,
            new Set(rows.map((row) => row[heatmapGroup])).size * (Number(spec.rowHeight) || 43) +
              (showXAxisTitle ? 60 : 32),
          ),
        )
      : height;
  const plotInset = ["pie", "funnel", "sparkline", "sankey"].includes(type)
    ? { left: 0, right: 0 }
    : {
        left: hasYAxisTitle && yAxisPosition === "left"
          ? chartMargin.left +
            (type === "heatmap" ? heatmapCategoryWidth : type === "histogram" ? numericAxisWidth : categoryWidth)
          : 0,
        right: hasYAxisTitle && yAxisPosition === "right"
          ? chartMargin.right +
            (type === "heatmap" ? heatmapCategoryWidth : type === "histogram" ? numericAxisWidth : categoryWidth)
          : 0,
      };
  return (
    <ChartFrame
      frameRef={frameRef}
      chart={chart}
      accessibleLabel={accessibleLabel
        ?? (x && y ? `${label(y)} by ${label(x)}` : `${label(type)} chart`)}
      height={chartHeight}
      xLabel={
        ["sparkline", "pie", "funnel", "sankey"].includes(type) || !showXAxisTitle
          ? ""
          : xTitle
      }
      xLabelPosition={inlineHeatmapXAxisLabel ? "inline-right" : "bottom"}
      plotInset={plotInset}
      legend={spec.showLegend === false ? [] : legend}
      scaleLegend={scaleLegend}
      onChartClick={(event) =>
        selectChartSection(
          { kind: "chart", chartType: type, label: "Chart" },
          event.nativeEvent,
        )
      }
      onLegendToggle={toggleSeries}
      onLegendIsolate={isolateSeries}
      zoomed={zoomable && Boolean(activeZoom)}
      onResetZoom={zoomable ? () => setZoom(null) : undefined}
      legendPosition={spec.legend?.position}
      annotationNotes={<ChartAnnotationNotes annotations={annotations} placedIds={placedAnnotationIds} />}
      data-chart-id={chartId}
    />
  );
}
