import React from "react";
import { usePlotArea } from "recharts";
import { useChartText } from "./ChartAnnotations.jsx";
import { categoryLabel, compactAxisCategory } from "./chart-theme.js";

const axisTickFontSize = 12;
const axisTextColor = "var(--secondary)";

export function CategoryAxisTick({
  x,
  y,
  payload,
  field,
  horizontal = false,
  angled = false,
  layout,
  width = 150,
  count = 1,
  side = "left",
}) {
  const value = categoryLabel(field, payload.value);
  const { measureFont, measureText } = useChartText(400, axisTickFontSize);
  const plot = usePlotArea();
  const spacing = (plot?.width ?? count * 80) / Math.max(1, count);
  const angle = angled && spacing < 50 ? -60 : -45;
  const projection = angled ? Math.cos(Math.abs(angle) * Math.PI / 180) : 1;
  const capacity = horizontal
    ? Math.max(6, Math.floor((width - 18) / 6.4))
    : Math.max(angled ? 4 : 1, Math.min(angled ? spacing < 35 ? 4 : angle === -60 ? 8 : 12 : 18,
      Math.floor((spacing - (angled ? 12 : 6))
      / (angled ? 7 * projection : 8))));
  if (horizontal) {
    let visible = value;
    while (visible.length > 1 && measureText(visible) > width - 18) {
      visible = `${visible.replace(/…$/u, "").slice(0, -1).trimEnd()}…`;
    }
    const right = side === "right";
    return (
      <text ref={measureFont} x={x + (right ? 9 : -9)} y={y + 4} fill={axisTextColor}
        textAnchor={right ? "start" : "end"} fontSize={axisTickFontSize}>
        <title>{value}</title>
        {visible}
      </text>
    );
  }
  if (layout === "date-time") {
    const [date, time] = value.split(" · ");
    const halfWidth = Math.max(measureText(date), measureText(time ?? "")) / 2;
    const anchor = x - halfWidth < (plot?.x ?? 0) ? "start"
      : x + halfWidth > (plot?.x ?? 0) + (plot?.width ?? Infinity) ? "end" : "middle";
    return (
      <text ref={measureFont} x={x} y={y + 11} fill={axisTextColor} textAnchor={anchor}
        fontSize={axisTickFontSize} data-axis-layout="date-time">
        <title>{value}</title>
        <tspan x={x}>{date}</tspan>
        {time && <tspan x={x} dy={13}>{time}</tspan>}
      </text>
    );
  }
  if (angled) {
    const visible = compactAxisCategory(value, capacity);
    const labelY = y + 11;
    return (
      <text x={x} y={labelY} fill={axisTextColor} textAnchor="end"
        fontSize={axisTickFontSize}
        transform={`rotate(${angle} ${x} ${labelY})`} data-axis-layout="angled">
        <title>{value}</title>
        {visible}
      </text>
    );
  }
  const lines = [];
  for (const word of value.split(/\s+/u)) {
    const current = lines.at(-1);
    if (current && `${current} ${word}`.length <= capacity) lines[lines.length - 1] = `${current} ${word}`;
    else lines.push(word);
  }
  const visible = lines.slice(0, 2).map((line) => (line.length > capacity ? `${line.slice(0, capacity - 1)}…` : line));
  if (lines.length > 2) visible[1] = `${visible[1].slice(0, Math.max(1, capacity - 1))}…`;
  return (
    <text x={x} y={y + 11} fill={axisTextColor} textAnchor="middle"
      fontSize={axisTickFontSize}
      data-axis-layout={visible.length > 1 ? "wrapped" : "horizontal"}>
      <title>{value}</title>
      {visible.map((line, index) => (
        <tspan key={`${line}-${index}`} x={x} dy={index ? 13 : 0}>
          {line}
        </tspan>
      ))}
    </text>
  );
}
