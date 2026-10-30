import React, { useLayoutEffect, useRef, useState } from "react";
import { Scatter, ScatterChart, XAxis, YAxis, ZAxis, useChartWidth, usePlotArea } from "recharts";

import { useChartText } from "./ChartAnnotations.jsx";
import { categoryAxisLayout, heatmapCellSize } from "./chart-data-shape.js";
import { canSelectHeatmapCell, exploreMarkKey } from "./chart-mark-interactions.js";
import { categoryLabel, colors, heatmapFill, heatmapTextColor, tick } from "./chart-theme.js";

const axisTickFontSize = 12;
const axisTextColor = "var(--secondary)";

export function HeatCell({ cx, cy, payload, columnCount, rowCount, radius, baseColor = "var(--chart-1)",
  valueField, showValues, formatValue, onSelect, onHover, colorBands, hideMissingCells = false,
  cellLabel, firstSelectableCell }) {
  const plot = usePlotArea();
  const { width, height, pitchX, pitchY } = heatmapCellSize(plot?.width ?? 240, plot?.height ?? 160, columnCount, rowCount);
  const rect = useRef(null);
  const [textColor, setTextColor] = useState("var(--text)");
  useLayoutEffect(() => {
    if (!showValues && !cellLabel) return;
    const view = rect.current?.ownerDocument?.defaultView;
    if (view) setTextColor(heatmapTextColor(view.getComputedStyle(rect.current).fill));
  });
  const unknown = payload.__unknown;
  const numericValue = Number(payload[valueField]);
  const band = !unknown && !payload.__missing && Array.isArray(colorBands) && Number.isFinite(numericValue)
    ? colorBands.find(({ max }) => !Number.isFinite(Number(max)) || numericValue < Number(max)) ?? colorBands.at(-1)
    : undefined;
  const showCellLabel = !unknown && !payload.__missing && cellLabel &&
    (!Number.isFinite(Number(cellLabel.showWhen)) || numericValue === Number(cellLabel.showWhen));
  const hidden = hideMissingCells && (payload.__missing || unknown);
  const selectable = Boolean(onSelect) && canSelectHeatmapCell(payload);
  const first = firstSelectableCell?.xIndex === payload.xIndex && firstSelectableCell?.yIndex === payload.yIndex;
  const value = unknown ? "—" : formatValue?.(payload[valueField]) ?? payload[valueField];
  return (
    <g className={selectable ? "chart-explore-mark" : undefined} role={selectable ? "button" : undefined}
      tabIndex={selectable ? first ? 0 : -1 : undefined}
      data-heatmap-cell={!hidden || undefined}
      onPointerEnter={() => onHover?.(!hidden)}
      onPointerLeave={event => { if (!event.relatedTarget?.closest?.("[data-heatmap-cell]")) onHover?.(false); }}
      aria-label={`${Object.values(payload).filter(v => typeof v === "string").join(", ")}: ${value}`}
      onKeyDown={event => { if (selectable) exploreMarkKey(event, event => onSelect(payload, event)); }}>
    {!hidden && <rect x={cx - pitchX / 2} y={cy - pitchY / 2} width={pitchX} height={pitchY} fill="transparent" pointerEvents="all" />}
    <rect
      ref={rect} className="chart-heatmap-cell"
      pointerEvents={hidden ? "none" : undefined}
      x={cx - width / 2}
      y={cy - height / 2}
      width={width}
      height={height}
      rx={Math.min(radius, width / 5, height / 5)}
      data-structural-zero={payload.__missing ? "true" : undefined}
      fill={hidden ? "transparent" : unknown ? "var(--control)" : band?.color ?? heatmapFill(baseColor, payload.intensity)}
    />
    {!hidden && showValues && !showCellLabel && <text x={cx} y={cy} dy="0.35em" textAnchor="middle" fontSize={12}
      fill={unknown ? "var(--secondary)" : textColor} pointerEvents="none">{value}</text>}
    {!hidden && showCellLabel && <text className="chart-heatmap-cell-label" x={cx} y={cy}
      textAnchor="middle" dominantBaseline="central" pointerEvents="none"
      fill={cellLabel.color ?? textColor} fontSize={Number(cellLabel.fontSize) || 12}
      fontWeight={Number(cellLabel.fontWeight) || 700}>{cellLabel.text ?? String(numericValue)}</text>}
    </g>
  );
}

function HeatmapTick({ x, y, payload, values, angled = false }) {
  const chartWidth = useChartWidth();
  const { measureFont, measureText } = useChartText(400, axisTickFontSize);
  const display = (raw) => {
    const time = typeof raw === "string" && /^(?:[01]\d|2[0-3]):[0-5]\d$/u.test(raw)
      ? `${Number(raw.slice(0, 2)) % 12 || 12}${raw.slice(3) === "00" ? "" : `:${raw.slice(3)}`} ${Number(raw.slice(0, 2)) < 12 ? "AM" : "PM"}`
      : tick(raw);
    return categoryLabel("", time);
  };
  const value = display(values[payload.value] ?? "");
  const plot = usePlotArea();
  const spacing = (plot?.width ?? values.length * 82) / Math.max(1, values.length);
  const angle = angled && spacing < 50 ? -60 : -45;
  const projection = angled ? Math.cos(Math.abs(angle) * Math.PI / 180) : 1;
  const characterWidth = axisTickFontSize * 0.58;
  const widest = Math.max(42, ...values.map((raw) => Math.min(128, display(raw).length * characterWidth + 12)));
  const interval = angled ? 1 : Math.max(
    1,
    Math.ceil((values.length * widest) / Math.max(1, plot?.width ?? values.length * 82)),
  );
  const index = Number(payload.value);
  if (index % interval !== 0 && index !== values.length - 1) return null;
  if (index !== 0 && index !== values.length - 1 && values.length - 1 - index < interval) return null;
  const capacity = Math.max(
    angled ? 4 : 5,
    Math.min(angled ? spacing < 35 ? 4 : angle === -60 ? 8 : 12 : 24,
      Math.floor((spacing * interval - (angled ? 12 : 8)) / (characterWidth * projection))),
  );
  let visible = value.length > capacity ? `${value.slice(0, capacity - 1).trimEnd()}…` : value;
  const availableWidth = angled ? x - 4 : 2 * Math.min(x - 4, chartWidth - x - 4);
  while (visible.length > 1 && measureText(visible) * projection > availableWidth) {
    visible = `${visible.replace(/…$/u, "").slice(0, -1).trimEnd()}…`;
  }
  const labelY = y + 11;
  return (
    <text ref={measureFont} x={x} y={labelY} fill={axisTextColor} textAnchor={angled ? "end" : "middle"}
      fontSize={axisTickFontSize}
      transform={angled ? `rotate(${angle} ${x} ${labelY})` : undefined}
      data-axis-layout={angled ? "angled" : "horizontal"}>
      <title>{value}</title>
      {visible}
    </text>
  );
}

/** Render the prepared heatmap with shared hover content and reviewed-row selection. */
export function HeatmapRenderer({ spec, heat, groupField, layout, markRadius, formatValue,
  onHover, onSelect, children }) {
  const { x, y } = spec;
  const { margin: chartMargin, categoryWidth: heatmapCategoryWidth,
    yAxisTitle: heatmapYAxisTitle, showXAxisTitle, showYAxisTitle } = layout;
  const yAxisPosition = spec.yAxisPosition === "right" ? "right" : "left";
  const inlineHeatmapXAxisLabel = spec.xLabelPosition === "inline-right" && showXAxisTitle;
  const firstSelectableCell = heat.rows.find(canSelectHeatmapCell);
  const selectCell = (row, event) => {
    if (!canSelectHeatmapCell(row)) {
      event?.stopPropagation?.();
      return;
    }
    onSelect?.(row, event);
  };
  const angledHeatmap = categoryAxisLayout(heat.xValues.map((value) => categoryLabel(x, value)),
    { preference: spec.xTickLabelLayout }) === "angled";
  return (
    <ScatterChart margin={{ ...chartMargin, bottom: showXAxisTitle ? 4 : 0,
      right: inlineHeatmapXAxisLabel ? Math.max(chartMargin.right, 168) : chartMargin.right }} accessibilityLayer>
      <XAxis
        type="number"
        dataKey="xIndex"
        domain={[-0.5, Math.max(0.5, heat.xValues.length - 0.5)]}
        ticks={heat.xValues.map((_, index) => index)}
        interval={0}
        tick={<HeatmapTick values={heat.xValues} angled={angledHeatmap} />}
        axisLine={false}
        tickLine={false}
        height={angledHeatmap ? 76 : 30}
      />
      <YAxis
        orientation={yAxisPosition}
        type="number"
        dataKey="yIndex"
        reversed={spec.reverseRows === true}
        domain={[-0.5, Math.max(0.5, heat.yValues.length - 0.5)]}
        ticks={heat.yValues.map((_, index) => index)}
        tickFormatter={(index) => categoryLabel(groupField, heat.yValues[index] ?? "")}
        axisLine={false}
        tickLine={false}
        tickMargin={5}
        tick={{ fontSize: axisTickFontSize, fill: axisTextColor }}
        width={heatmapCategoryWidth}
        label={
          showYAxisTitle && heatmapYAxisTitle
            ? {
                value: heatmapYAxisTitle,
                angle: yAxisPosition === "right" ? 90 : -90,
                position: yAxisPosition === "right" ? "insideRight" : "insideLeft",
                offset: 0,
                style: { fill: "var(--secondary)", fontSize: 12, textAnchor: "middle" },
              }
            : undefined
        }
      />
      <ZAxis dataKey={y} />
      {children}
      <Scatter
        data={heat.rows}
        shape={
          <HeatCell
            columnCount={heat.xValues.length}
            rowCount={heat.yValues.length}
            radius={markRadius}
            baseColor={spec.baseColor ?? colors[0]}
            valueField={y} showValues={spec.showValues} formatValue={formatValue}
            onHover={onHover}
            firstSelectableCell={firstSelectableCell}
            onSelect={onSelect ? selectCell : undefined}
            colorBands={spec.colorBands}
            hideMissingCells={spec.hideMissingCells}
            cellLabel={spec.cellLabel}
          />
        }
        isAnimationActive={false}
        onClick={(entry, index, event) => selectCell(entry?.payload ?? heat.rows[index], event)}
      />
    </ScatterChart>
  );
}
