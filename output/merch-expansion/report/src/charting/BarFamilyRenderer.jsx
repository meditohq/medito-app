import React, { useLayoutEffect, useMemo, useRef, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  LabelList,
  ReferenceLine,
  Rectangle,
  ResponsiveContainer,
  XAxis,
  YAxis,
} from "recharts";

import { ChartMark, captureChartHoverCard } from "./ChartMark.jsx";
import { ChartLegend } from "./ChartFrame.jsx";
import { ChartTooltip, PointerChartTooltip } from "./ChartTooltip.jsx";
import { NumericXAxis, NumericYAxis } from "./NumericAxes.jsx";
import { TemporalXAxis } from "./TemporalXAxis.jsx";
import { formatChartValue, percentageAxisMode } from "./chart-theme.js";
import { barValue, barPresentationIssue, segmentCalloutsFit, rangePosition } from "./bar-family.js";
import { useDashboardAsk } from "../components/DashboardAsk.jsx";

const numberFormatter = new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 });

function valueFor(row, field) {
  return typeof field === "function" ? field(row) : row?.[field];
}

function categoryFor(row, spec) {
  return spec.formatCategory(valueFor(row, spec.category));
}

function shareLabel(value, total) {
  return total > 0 ? `${Math.round(value / total * 100)}%` : "—";
}

function normalizeSpec(spec) {
  let formatter;
  try { formatter = new Intl.NumberFormat(undefined, spec.format ?? { maximumFractionDigits: 1 }); }
  catch { formatter = numberFormatter; }
  const formatValue = value => value == null || !Number.isFinite(Number(value)) ? "—" : spec.format
    ? formatter.format(Number(value)) : formatChartValue(value, spec.value, { decimals: 1 });
  const axes = spec.axes === false ? { category: false, value: false } : {
    category: spec.axes?.category ?? true,
    value: spec.axes?.value ?? true,
  };
  return {
    ...spec,
    category: spec.category ?? spec.x,
    value: spec.value ?? spec.y,
    orientation: spec.orientation ?? "vertical",
    presentation: spec.presentation ?? "plot",
    series: (spec.series ?? []).map((series, index) => ({
      ...(typeof series === "string" ? { key: series, label: series } : series),
      color: series.color ?? `var(--chart-${index % 8 + 1})`,
    })),
    axes,
    markers: spec.markers ?? [],
    labels: spec.labels ?? {},
    style: spec.style ?? {},
    interaction: { tooltip: true, ...(spec.interaction ?? {}) },
    tooltipFields: spec.tooltipFields ?? [],
    formatValue: spec.formatValue ?? formatValue,
    formatCategory: spec.formatCategory ?? String,
    formatRange: spec.formatRange ?? (spec.rangeLabelField ? (_range, row) => row[spec.rangeLabelField] : undefined),
  };
}

function BulletPresentation({ rows, spec }) {
  const domainMax = Math.max(1, ...rows.flatMap((row) => [
    barValue(row, spec.value),
    barValue(row, spec.target),
    barValue(row, spec.projection),
  ])) * 1.08;
  const thickness = Number(spec.style.thickness) || 18;
  const fontSize = Number(spec.style.fontSize) || 14;

  return <div className="bar-family-bullets" style={{
    "--bar-family-thickness": `${thickness}px`,
    "--bar-family-font-size": `${fontSize}px`,
    "--bar-family-row-gap": `${spec.style.gap ?? 18}px`,
  }}>
    {rows.map((row, index) => {
      const value = barValue(row, spec.value);
      const target = barValue(row, spec.target);
      const projection = barValue(row, spec.projection);
      const label = categoryFor(row, spec);
      const color = valueFor(row, spec.style.colorField) || spec.style.color || "var(--chart-1)";
      return <BarMark row={row} spec={spec}
        className="bar-family-bullet-row"
        key={`${label}-${index}`}
        aria-label={`${label}: ${spec.formatValue(value, row)}${target == null ? "" : `; target ${spec.formatValue(target, row)}`}`}
      >
        <span className="bar-family-list-copy"><span>{label}</span><strong>{spec.formatValue(value, row)}</strong></span>
        <span className="bar-family-bullet-track" aria-hidden="true">
          {projection != null && <span className="bar-family-bullet-projection" style={{ width: `${Math.min(projection / domainMax, 1) * 100}%`, background: color }} />}
          <span className="bar-family-bullet-value" style={{ width: `${Math.min(value / domainMax, 1) * 100}%`, background: color }} />
          {target != null && <i style={{ left: `${Math.min(target / domainMax, 1) * 100}%` }} />}
        </span>
        </BarMark>;
    })}
  </div>;
}

function RangePositionPresentation({ rows, spec }) {
  return <div className="bar-family-list bar-family-range" style={{
    "--bar-family-row-gap": `${spec.style.gap ?? 13}px`,
    "--bar-family-font-size": `${spec.style.fontSize ?? 14}px`,
  }}>{rows.map((row, index) => {
    const [low, high] = spec.range.map(field => barValue(row, field));
    const value = barValue(row, spec.value), position = rangePosition(low, high, value);
    const label = categoryFor(row, spec);
    return <BarMark key={index} row={row} spec={spec} className="bar-family-list-row"
      style={{ "--bar-family-range-color": valueFor(row, spec.style.colorField) || spec.style.color || "var(--text)" }}
      aria-label={`${label}: ${spec.formatValue(value)}; ${spec.formatValue(low)} to ${spec.formatValue(high)}`}>
      {spec.labels.primary !== false && <span className="bar-family-list-copy"><span>{label}</span><strong>{spec.formatValue(value)}</strong></span>}
      <span className="bar-family-range-track" aria-hidden="true">{position != null && <i style={{ left: `clamp(4px, ${position}%, calc(100% - 4px))` }} />}</span>
      <span className="bar-family-list-copy bar-family-range-bounds" aria-hidden="true"><span>{spec.formatValue(low)}</span><span>{spec.formatValue(high)}</span></span>
    </BarMark>;
  })}</div>;
}

function SegmentedPresentation({ rows, spec }) {
  const root = useRef(null);
  const [calloutsFit, setCalloutsFit] = useState(false);
  const [activeStage, setActiveStage] = useState(null);
  const activate = key => {
    if (!root.current?.closest("[data-chart-tooltip-pinned]")) setActiveStage(key);
  };
  const highlight = key => ({ "data-active": activeStage === key || undefined });
  const row = rows[0] ?? {};
  const comparisonRow = spec.comparison && rows[1] ? rows[1] : null;
  const aligned = Boolean(comparisonRow || ["aligned", "auto"].includes(spec.annotations));
  useLayoutEffect(() => {
    const element = root.current;
    if (!aligned || !element) return;
    const measure = () => setCalloutsFit(segmentCalloutsFit(
      [...element.querySelectorAll(".bar-family-segment-callouts > div")].map(cell => ({
        width: cell.querySelector("strong").clientWidth,
        labelWidth: cell.querySelector("strong").scrollWidth,
        valueWidth: cell.querySelector("span").scrollWidth,
      }))));
    measure();
    const observer = typeof ResizeObserver === "function" ? new ResizeObserver(measure) : null;
    observer?.observe(element);
    const fonts = element.ownerDocument.fonts;
    fonts?.addEventListener("loadingdone", measure);
    return () => { observer?.disconnect(); fonts?.removeEventListener("loadingdone", measure); };
  }, [aligned, rows, spec]);
  const series = spec.series.map((entry, index) => typeof entry === "string"
    ? { key: entry, label: entry, color: `var(--chart-${index + 1})` }
    : entry);
  const segmentsFor = (sourceRow, comparison = false) => series.map((entry, index) => ({
    ...entry,
    value: barValue(sourceRow, entry.key),
    color: comparison
      ? entry.comparisonColor ?? spec.comparison?.colors?.[index] ?? `var(--neutral-${index + 2})`
      : entry.color,
  }));
  const segments = segmentsFor(row);
  const comparisonSegments = comparisonRow ? segmentsFor(comparisonRow, true) : [];
  const totalFor = (items) => items.reduce((sum, segment) => sum + (segment.value ?? 0), 0);
  const total = totalFor(segments);
  const thickness = Number(spec.style.thickness) || 28;
  const radius = Number(spec.style.radius) || 999;
  const fontSize = Number(spec.style.fontSize) || 14;

  const renderTrack = (items, sourceRow, rowKey) => {
    const rowTotal = totalFor(items);
    return <div className="bar-family-segmented-track" role="group" aria-label={spec.formatCategory(valueFor(sourceRow, spec.category)) || "Composition"}>
      {items.map((segment, index) => <BarMark row={sourceRow} field={segment.key} spec={spec}
        color={segment.color} previous={rowKey === "comparison"}
        className="bar-family-segment"
        key={segment.key}
        {...highlight(segment.key)}
        onPointerEnter={() => activate(segment.key)} onPointerLeave={() => activate(null)}
        onFocus={() => activate(segment.key)} onBlur={() => activate(null)}
        style={{ width: `${(rowTotal > 0 ? segment.value / rowTotal : 0) * 100}%`, background: segment.color }}
        aria-label={`${segment.label}: ${spec.formatValue(segment.value, sourceRow)}`}
      >
        {spec.labels.value === "inside" && (rowTotal > 0 ? segment.value / rowTotal : 0) >= .12 && <span>{spec.formatValue(segment.value, sourceRow)}</span>}
        </BarMark>)}
    </div>;
  };

  const renderAlignedCallouts = (items, sourceRow, position) => {
    const rowTotal = totalFor(items);
    const alignRight = spec.labels.align === "right";
    return <div className="bar-family-segment-callouts" data-position={position}
      aria-hidden={!calloutsFit || undefined}
      data-align={alignRight ? "right" : "left"}
      style={{ gridTemplateColumns: items.map((segment) => `${Math.max(segment.value, .01)}fr`).join(" ") }}>
      {items.map((segment) => <div key={segment.key} {...highlight(segment.key)}>
        {position === "top" && <strong>{segment.label}</strong>}
        <span>
          {!alignRight && <i className="bar-family-callout-marker" aria-hidden="true" />}
          <b>{spec.formatValue(segment.value, sourceRow)}</b> <small>{shareLabel(segment.value, rowTotal)}</small>
          {alignRight && <i className="bar-family-callout-marker" aria-hidden="true" />}
        </span>
        {position === "bottom" && <strong>{segment.label}</strong>}
      </div>)}
    </div>;
  };

  const renderSegmentLabels = (items, sourceRow, position) => {
    const rowTotal = totalFor(items);
    const primary = spec.labels.primary ?? "value";
    const secondary = spec.labels.secondary ?? "label";
    const contentFor = (segment, content) => {
      if (content === "value") return spec.formatValue(segment.value, sourceRow);
      if (content === "share") return shareLabel(segment.value, rowTotal);
      return segment.label;
    };
    const spread = spec.labels.align === "spread";
    return <div className="bar-family-segment-labels" data-position={position} data-align={spread ? "spread" : "segment"}
      style={{ gridTemplateColumns: spread
        ? `repeat(${items.length}, minmax(0, 1fr))`
        : items.map((segment) => `${Math.max(segment.value, .01)}fr`).join(" ") }}>
      {items.map((segment) => <div key={segment.key} {...highlight(segment.key)}>
        <strong>{contentFor(segment, primary)}</strong>
        {secondary !== false && <span>{contentFor(segment, secondary)}</span>}
      </div>)}
    </div>;
  };

  return <div ref={root} className="bar-family-segmented" data-interacting={activeStage !== null || undefined}
    data-callouts-fit={aligned ? String(calloutsFit) : undefined} style={{
    "--bar-family-thickness": `${thickness}px`,
    "--bar-family-radius": `${radius}px`,
    "--bar-family-font-size": `${fontSize}px`,
    "--bar-family-segment-gap": `${spec.style.segmentGap ?? 2}px`,
  }} data-rounded-segments={spec.style.roundedSegments || undefined} data-annotations={spec.annotations || undefined}>
    {aligned && renderAlignedCallouts(segments, row, "top")}
    {!comparisonRow && spec.labels.position === "above" && renderSegmentLabels(segments, row, "above")}
    {aligned && <span className="bar-family-period-label">{categoryFor(row, spec)}</span>}
    {renderTrack(segments, row, "current")}
    {!comparisonRow && spec.labels.position === "below" && renderSegmentLabels(segments, row, "below")}
    {comparisonRow && <span className="bar-family-period-label">{spec.formatCategory(valueFor(comparisonRow, spec.category))}</span>}
    {comparisonRow && renderTrack(comparisonSegments, comparisonRow, "comparison")}
    {comparisonRow && renderAlignedCallouts(comparisonSegments, comparisonRow, "bottom")}
    {aligned && <div className="bar-family-comparison-table"><table>
      <thead><tr><th>Stage</th><th>{categoryFor(row, spec)}</th>
        {comparisonRow && <th>{spec.formatCategory(valueFor(comparisonRow, spec.category))}</th>}</tr></thead>
      <tbody>{segments.map(segment => <tr key={segment.key} {...highlight(segment.key)}><th scope="row">{segment.label}</th>
        <td>{spec.formatValue(segment.value, row)}</td>
        {comparisonRow && <td>{spec.formatValue(barValue(comparisonRow, segment.key), comparisonRow)}</td>}</tr>)}</tbody>
    </table></div>}
    {spec.annotations && !["aligned", "auto"].includes(spec.annotations) && !comparisonRow && <div className="bar-family-segment-annotations">
      {segments.map((segment) => <div key={segment.key} {...highlight(segment.key)}
        onPointerEnter={() => activate(segment.key)} onPointerLeave={() => activate(null)}>
        <span className="bar-family-segment-key" style={{ background: segment.color }} aria-hidden="true" />
        <span><strong>{segment.label}</strong><small>{total > 0 ? `${shareLabel(segment.value, total)} of total` : "—"}</small></span>
        <b>{spec.formatValue(segment.value, row)}</b>
      </div>)}
    </div>}
  </div>;
}

export function ProgressTooltip({ label, actual, goal, unit = "", formatValue = value => numberFormatter.format(value) }) {
  const observed = actual != null && Number.isFinite(actual);
  const validGoal = goal != null && Number.isFinite(goal) && goal > 0;
  const summary = `${observed ? formatValue(actual) : "—"} of ${validGoal ? formatValue(goal) : "—"}${unit ? ` ${unit}` : ""}`;
  return <ChartTooltip active label={label} headerValue={observed && validGoal ? shareLabel(actual, goal) : "—"} details={[]}>
    <span className="chart-tooltip-summary">{summary}</span>
  </ChartTooltip>;
}

export function BarTooltip({ active = true, payload, row = payload?.[0]?.payload, field, color, previous = false, spec }) {
  if (!active || !row) return null;
  if (spec.presentation === "rangePosition" && !spec.tooltipFields.length) return <ChartTooltip active
    label={categoryFor(row, spec)} headerValue={spec.formatValue(barValue(row, spec.value))}
    details={spec.range.map((key, index) => ({ label: index ? "High" : "Low", value: spec.formatValue(barValue(row, key)) }))} />;
  if (spec.presentation === "progress" && !spec.tooltipFields.length) return <ProgressTooltip
    label={categoryFor(row, spec)} actual={barValue(row, spec.value)}
    goal={barValue(row, spec.track.max)} unit={typeof row[spec.unitField] === "string" ? row[spec.unitField] : ""}
    formatValue={spec.formatValue} />;
  const fieldSpec = spec.series.find(series => series.key === field);
  const fields = spec.tooltipFields.length ? spec.tooltipFields : field ? [fieldSpec ?? { key: field, label: "Value" }]
    : spec.series.length ? spec.series
    : [{ key: spec.value, label: "Actual" }, ...(spec.target && barValue(row, spec.target) != null ? [{ key: spec.target, label: "Target" }] : []),
      ...(spec.projection && barValue(row, spec.projection) != null ? [{ key: spec.projection, label: "Projected" }] : []),
      ...(spec.presentation === "progress" ? [{ key: spec.track.max, label: "Goal" }] : [])];
  const range = spec.range?.map(key => barValue(row, key));
  return <ChartTooltip active={active} label={categoryFor(row, spec)}
    formatValue={(value, key) => range && spec.presentation !== "rangePosition" && key === spec.value
      ? spec.formatRange?.(range, row) ?? range.map(spec.formatValue).join("–") : spec.formatValue(value, row)}
    formatLabel={entry => entry.name}
    resolveStyle={entry => ({ type: entry.dataKey === spec.target || entry.dataKey === spec.track?.max ? "target"
      : entry.dataKey === spec.projection ? "projection"
      : previous || /previous|prior/i.test(entry.dataKey) ? "previous-bar" : "current",
      opacity: previous || /previous|prior/i.test(entry.dataKey) ? .45 : 1 })}
    payload={fields.filter(item => item.key).map(item => ({ dataKey: item.key, name: item.label ?? item.key,
      value: barValue(row, item.key), payload: row,
      color: item.key === spec.target || item.key === spec.track?.max || item.key === spec.projection
        ? "var(--secondary)" : color ?? item.color ?? valueFor(row, spec.style.colorField) ?? spec.style.color ?? "var(--chart-1)" }))} />;
}

function BarMark({ row, field, spec, color, previous, children, ...props }) {
  return <ChartMark {...props} tooltipEnabled={spec.interaction.tooltip}
    context={{ kind: "chart", chartType: spec.chartType, label: categoryFor(row, spec),
      series: field ?? spec.value, value: barValue(row, field ?? spec.value), row,
      actions: spec.getMarkActions?.({ row, field: field ?? spec.value }) ?? [] }}
    tooltip={<BarTooltip row={row} field={field} spec={spec} color={color} previous={previous} />}>{children}</ChartMark>;
}

function GroupedListPresentation({ rows, spec }) {
  const [activeBar, setActiveBar] = useState(null);
  const maximum = Math.max(1, ...rows.flatMap((row) =>
    spec.series.map((series) => barValue(row, series.key))));
  return <div className="bar-family-grouped-list" data-interacting={activeBar !== null || undefined} style={{
    "--bar-family-group-gap": `${spec.style.gap ?? 15}px`,
    "--bar-family-value-width": `${Math.max(4, ...rows.flatMap(row => spec.series.map(series => spec.formatValue(barValue(row, series.key), row).length)))}ch`,
    "--bar-family-thickness": `${spec.style.thickness ?? 10}px`,
    "--bar-family-radius": `${spec.style.radius ?? 5}px`,
  }}>
    <ChartLegend items={spec.series.map(series => ({ key: series.key, label: series.label ?? series.key, color: series.color }))} />
    {rows.map((row, rowIndex) => {
      const category = categoryFor(row, spec);
      return <div className="bar-family-grouped-row" key={category} role="group"
        aria-label={`${category}: ${spec.series.map((series) =>
          `${series.label ?? series.key} ${spec.formatValue(barValue(row, series.key), row)}`).join(", ")}`}>
        <span className="bar-family-grouped-label">{category}</span>
        <div className="bar-family-grouped-pair">
          {spec.series.map((series) => {
            const value = barValue(row, series.key);
            const activeKey = `${rowIndex}-${series.key}`;
            const color = series.colors?.[rowIndex] ?? series.color;
            const textColor = series.textColors?.[rowIndex] ?? series.textColor ?? "var(--text)";
            return <BarMark row={row} field={series.key} spec={spec} color={color} className="bar-family-grouped-bar" key={series.key}
              data-active={activeBar === activeKey || undefined}
              aria-label={`${category}, ${series.label ?? series.key}: ${spec.formatValue(value, row)}`}
              onMouseEnter={() => setActiveBar(activeKey)} onMouseLeave={() => setActiveBar(null)}
              onFocus={() => setActiveBar(activeKey)} onBlur={() => setActiveBar(null)}>
              <span className="bar-family-grouped-track">
                <span style={{ width: `${value / maximum * 100}%`, background: color, color: textColor }}>
                </span>
              </span>
              <strong className="bar-family-grouped-value">{spec.formatValue(value, row)}</strong>
              </BarMark>;
          })}
        </div>
      </div>;
    })}
  </div>;
}

function ListPresentation({ rows, spec }) {
  const [activeIndex, setActiveIndex] = useState(null);
  const [expanded, setExpanded] = useState(false);
  const maxValue = Math.max(1, ...rows.map((row) => barValue(row, spec.value)));
  const initialVisibleRows = spec.visibleRows ?? rows.length;
  const visibleRows = expanded ? rows : rows.slice(0, initialVisibleRows);
  const hiddenCount = Math.max(0, rows.length - initialVisibleRows);
  const isProgress = spec.presentation === "progress";

  return <div
    className={`bar-family-list bar-family-list--${spec.presentation}`}
    data-label-position={spec.labels.position}
    data-interacting={activeIndex !== null || undefined}
    style={{
      "--bar-family-row-gap": `${spec.style.gap ?? (isProgress ? 20 : 13)}px`,
      "--bar-family-radius": `${spec.style.radius ?? 999}px`,
    }}
  >
    {visibleRows.map((row, index) => {
      const value = barValue(row, spec.value);
      const trackMax = isProgress
        ? barValue(row, typeof spec.track === "object" ? spec.track.max : undefined)
        : maxValue;
      const ratio = Math.max(0, Math.min(value / trackMax, 1));
      const label = categoryFor(row, spec);
      const displayValue = isProgress && spec.labels.value !== "formatted"
        ? value == null ? "—" : `${Math.round(value / trackMax * 100)}%`
        : spec.formatValue(value, row);
      const color = valueFor(row, spec.style.colorField) || spec.style.color || "var(--chart-1)";
      const textColor = valueFor(row, spec.style.textColorField) || spec.style.textColor || "var(--text)";
      const thicknessSource = spec.style.thicknessField ? valueFor(row, spec.style.thicknessField) : spec.style.thickness;
      const thickness = Number(typeof thicknessSource === "function" ? thicknessSource(row, index) : thicknessSource) || (isProgress ? 12 : 32);
      const fontSize = Number(spec.style.fontSize) || 14;
      const showTrack = isProgress || Boolean(spec.track);
      const trackColor = typeof spec.track === "object" && spec.track.color
        ? spec.track.color
        : "color-mix(in srgb, var(--text) 7%, transparent)";
      const labelsAbove = !isProgress && spec.labels.position === "above";
      const segments = isProgress ? spec.style.segments : null;
      const summary = isProgress && spec.labels.position === "summary";
      return <BarMark row={row} spec={spec}
        className="bar-family-list-row"
        key={`${label}-${index}`}
        onMouseEnter={() => setActiveIndex(index)}
        onMouseLeave={() => setActiveIndex(null)}
        onFocus={() => setActiveIndex(index)}
        onBlur={() => setActiveIndex(null)}
        aria-label={`${label}: ${displayValue}${spec.detailField ? `; ${valueFor(row, spec.detailField) ?? ""}` : ""}`}
        data-active={activeIndex === index || undefined}
        data-track={showTrack || undefined}
        style={{
          "--bar-family-thickness": `${thickness}px`,
          "--bar-family-font-size": `${fontSize}px`,
          "--bar-family-track-color": trackColor,
        }}
      >
        {summary ? <span className="bar-family-list-copy bar-family-progress-summary"><strong>{displayValue}</strong><span>{valueFor(row, spec.detailField)}</span></span> : labelsAbove
          ? <span className="bar-family-list-value"><strong>{displayValue}</strong>{spec.labels.suffix}</span>
          : <span className="bar-family-list-copy">
            <span style={{ color: textColor }}>{label}</span>
            <strong style={{ color: ratio >= 0.88 ? textColor : undefined }}>{displayValue}</strong>
          </span>}
        <span className="bar-family-list-track" data-segments={segments || undefined} aria-hidden="true"
          style={segments ? { "--progress-color": color, "--progress-segments": segments } : undefined}>
          {segments ? Array.from({length: segments}, (_, segment) => <span key={segment} data-active={value != null && segment < Math.round(ratio * segments) || undefined} />)
          : <span style={{ width: `${ratio * 100}%`, background: color, color: textColor }}>
            {labelsAbove && <b>{label}</b>}
          </span>}
        </span>
        </BarMark>;
    })}
    {spec.expandable && hiddenCount > 0 && <button
      type="button"
      className="bar-family-list-toggle"
      aria-expanded={expanded}
      onClick={() => setExpanded((value) => !value)}
    >{expanded ? "Show less" : `Show ${hiddenCount} more`}</button>}
  </div>;
}

export function BarFamilyRenderer({ rows = [], spec: chartSpec, height = 220, className = "", getMarkActions }) {
  const plotRef = useRef(null);
  const { selectChartMark } = useDashboardAsk();
  const rawSpec = useMemo(() => ({ ...chartSpec.barOptions, category: chartSpec.x, value: chartSpec.y,
    presentation: chartSpec.presentation, xLabel: chartSpec.xLabel,
    orientation: chartSpec.barOptions?.orientation ?? (chartSpec.type === "horizontalBar" ? "horizontal" : "vertical") }), [chartSpec]);
  const spec = useMemo(() => ({ ...normalizeSpec(rawSpec), chartType: chartSpec.type, getMarkActions }), [rawSpec, chartSpec.type, getMarkActions]);
  const chartRows = useMemo(() => {
    const nextRows = [...rows];
    if (spec.sort === "descending") {
      nextRows.sort((a, b) => Number(valueFor(b, spec.value)) - Number(valueFor(a, spec.value)));
    }
    if (spec.sort === "ascending") {
      nextRows.sort((a, b) => Number(valueFor(a, spec.value)) - Number(valueFor(b, spec.value)));
    }
    return nextRows;
  }, [rows, spec]);

  const issue = barPresentationIssue(chartRows, chartSpec);
  if (issue) return <div className="bar-family-empty" role="status">{issue}</div>;
  if (!chartRows.length) return <div className="bar-family-empty">No data</div>;
  const Presentation = { rangePosition: RangePositionPresentation, segmented: SegmentedPresentation,
    bullet: BulletPresentation, groupedList: GroupedListPresentation,
    rankedList: ListPresentation, progress: ListPresentation, comparison: ListPresentation }[spec.presentation];
  if (Presentation) return <div className={`experimental-bar-chart ${className}`} data-chart-interaction-root><Presentation rows={chartRows} spec={spec} /></div>;

  const visibleChartRows = spec.visibleRows ? chartRows.slice(0, spec.visibleRows) : chartRows;

  const horizontal = spec.orientation === "horizontal";
  const radius = spec.style.radius ?? 10;
  const thickness = spec.style.thickness ?? (horizontal ? 18 : 34);
  const color = spec.style.color ?? "var(--chart-1)";
  const valueDataKey = spec.range
    ? (row) => {
        const range = spec.range.map((field) => barValue(row, field));
        return range.some(value => value == null) ? null : range;
      }
    : spec.value;
  const categoryAxis = {
    dataKey: spec.category,
    hide: !spec.axes.category,
    axisLine: false,
    tickLine: false,
    tick: { fill: "var(--secondary)", fontSize: 12 },
  };
  const valueAxis = {
    type: "number",
    hide: !spec.axes.value,
    axisLine: false,
    tickLine: false,
    tick: { fill: "var(--secondary)", fontSize: 12 },
    domain: rawSpec.domain,
    percent: percentageAxisMode([spec.value], chartRows),
  };

  const temporal = visibleChartRows.length > 0 && visibleChartRows.every(row =>
    typeof row[spec.category] === "string" && /^\d{4}-\d{2}-\d{2}/.test(row[spec.category]) && Number.isFinite(Date.parse(row[spec.category])));
  const CategoryXAxis = temporal ? TemporalXAxis : XAxis;
  const select = (entry, index, event, field = spec.value) => {
    const row = entry?.payload ?? visibleChartRows[index];
    if (!row) return;
    const element = event?.target?.closest?.(".recharts-wrapper");
    selectChartMark({ kind: "chart", chartType: chartSpec.type, label: spec.formatCategory(row[spec.category]),
      series: field, value: barValue(row, field), row, actions: getMarkActions?.({ row, field }) ?? [],
      hoverCard: captureChartHoverCard(element, element?.querySelector(".chart-tooltip")) }, event);
  };
  const shape = field => props => <Rectangle {...props} role="button" tabIndex={0}
    aria-label={`${spec.formatCategory(props.payload?.[spec.category])}: ${spec.formatValue(barValue(props.payload, field))}`}
    onKeyDown={event => { if (["Enter", " "].includes(event.key)) {
      event.preventDefault(); select(props, props.index, event, field);
    } }} />;
  return <div ref={plotRef} className={`experimental-bar-chart ${className}`} data-chart-interaction-root style={{ height }}
    data-axis-label={rawSpec.xLabel ? "true" : undefined}>
    <div className="experimental-bar-plot">
    <ResponsiveContainer width="100%" height="100%">
      <BarChart
        data={visibleChartRows}
        layout={horizontal ? "vertical" : "horizontal"}
        margin={{ top: 12, right: horizontal ? 20 : 8, bottom: 0, left: horizontal ? 4 : 0 }}
        barCategoryGap={rawSpec.barCategoryGap ?? "24%"}
      >
        {rawSpec.grid !== false && <CartesianGrid vertical={false} stroke="var(--border)" strokeOpacity={0.6} />}
        {horizontal
          ? <><NumericXAxis {...valueAxis} /><YAxis {...categoryAxis} type="category"
              width={rawSpec.categoryWidth ?? Math.min(160, Math.max(60, ...visibleChartRows.map(row => String(row[spec.category]).length * 7 + 8)))} /></>
          : <><CategoryXAxis {...categoryAxis} {...(temporal ? { values: visibleChartRows.map(row => row[spec.category]), banded: true } : {})} /><NumericYAxis {...valueAxis} width={rawSpec.valueWidth ?? "auto"} /></>}
        {spec.interaction.tooltip && <PointerChartTooltip frameRef={plotRef} touchOnly
          cursor={{ fill: "color-mix(in srgb, var(--text) 4%, transparent)" }} isAnimationActive={false}
          content={<BarTooltip spec={spec} />} />}
        {spec.markers.map((marker, index) => horizontal
          ? <ReferenceLine key={index} x={marker.value} stroke={marker.color ?? "var(--secondary)"} strokeWidth={marker.width ?? 1} label={marker.label ? { value: marker.label, position: "insideTopRight", fill: "var(--secondary)", fontSize: 10 } : undefined} />
          : <ReferenceLine key={index} y={marker.value} stroke={marker.color ?? "var(--secondary)"} strokeWidth={marker.width ?? 1} label={marker.label ? { value: marker.label, position: "insideTopRight", fill: "var(--secondary)", fontSize: 10 } : undefined} />)}
        {spec.series.length
          ? spec.series.map((series) => <Bar
            key={series.key}
            shape={shape(series.key)} onClick={(entry, index, event) => select(entry, index, event, series.key)}
            dataKey={series.key}
            name={series.label ?? series.key}
            fill={series.color ?? color}
            stackId={series.stackId}
            radius={radius}
            barSize={thickness}
            activeBar={{ fillOpacity: 0.78 }}
            isAnimationActive={false}
          >
            {spec.labels.value && <LabelList
              dataKey={series.key}
              position="top"
              formatter={spec.formatValue}
              fill="var(--text)"
              fontSize={12}
            />}
          </Bar>)
          : <Bar
            shape={shape(spec.value)} onClick={select}
            dataKey={valueDataKey}
            fill={color}
            radius={radius}
            barSize={thickness}
            background={spec.track ? { fill: "color-mix(in srgb, var(--text) 6%, transparent)", radius } : false}
            activeBar={{ fillOpacity: 0.78 }}
            isAnimationActive={false}
          >
            {spec.style.colorField && visibleChartRows.map((row, index) => <Cell key={index} fill={valueFor(row, spec.style.colorField) || color} />)}
            {spec.labels.value && <LabelList
              dataKey={spec.value}
              position={spec.labels.value === "inside" ? "insideRight" : "right"}
              formatter={spec.formatValue}
              fill={spec.labels.value === "inside" ? "white" : "var(--text)"}
              fontSize={12}
            />}
          </Bar>}
      </BarChart>
    </ResponsiveContainer>
    </div>
    {rawSpec.xLabel && <span className="experimental-bar-axis-label">{rawSpec.xLabel}</span>}
  </div>;
}
