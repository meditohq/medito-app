import React, { useId } from "react";
import { resolveDeltaTone } from "./table-data.js";

export function MetricSparkline({ values = [], label, tone, negative = false, className = "" }) {
  const id = useId().replaceAll(":", "");
  const reviewed = values.filter(Number.isFinite);
  if (reviewed.length < 2) return null;
  const minimum = Math.min(...reviewed);
  const range = Math.max(Number.EPSILON, Math.max(...reviewed) - minimum);
  const segments = [];
  let points = [];
  values.forEach((value, index) => {
    if (!Number.isFinite(value)) {
      if (points.length) segments.push(points);
      points = [];
    } else {
      points.push([2 + index / (values.length - 1) * 54, 21 - (value - minimum) / range * 16]);
    }
  });
  if (points.length) segments.push(points);
  const gradient = `metric-fill-${id}`;
  const stroke = `metric-stroke-${id}`;
  return <svg className={["metric-mini-trend", "data-metric-sparkline", className].filter(Boolean).join(" ")}
    viewBox="0 0 58 25" role={label ? "img" : undefined} aria-label={label || undefined}
    aria-hidden={label ? undefined : true} data-direction={resolveDeltaTone(tone, undefined, undefined, negative ? "negative" : "positive")}>
    {label && <title>{label}</title>}
    <defs>
      <linearGradient id={gradient} x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stopColor="currentColor" stopOpacity=".32" />
        <stop offset="100%" stopColor="currentColor" stopOpacity="0" />
      </linearGradient>
      <linearGradient id={stroke} x1="0" y1="0" x2="1" y2="0">
        <stop offset="0%" stopColor="currentColor" stopOpacity=".58" />
        <stop offset="100%" stopColor="currentColor" stopOpacity=".94" />
      </linearGradient>
    </defs>
    {segments.map((segment, index) => segment.length === 1
      ? <circle key={index} cx={segment[0][0]} cy={segment[0][1]} r="1" fill="currentColor" />
      : <React.Fragment key={index}>
        <polygon points={`${segment[0][0]},23 ${segment.join(" ")} ${segment.at(-1)[0]},23`} fill={`url(#${gradient})`} />
        <polyline points={segment.join(" ")} fill="none" stroke={`url(#${stroke})`} strokeWidth="1.7"
          strokeLinecap="round" strokeLinejoin="round" />
      </React.Fragment>)}
  </svg>;
}
