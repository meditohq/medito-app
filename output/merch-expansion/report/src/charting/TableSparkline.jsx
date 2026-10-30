import React from "react";

import { displayValue } from "./chart-theme.js";

export function TableSparkline({ values, label }) {
  const points = Array.isArray(values) ? values.filter(Number.isFinite) : [];
  if (points.length < 3) return <span className="table-visual-empty">—</span>;
  const changes = points.map((value) => value - points[0]);
  const minimum = Math.min(0, ...changes);
  const range = Math.max(1, Math.max(0, ...changes) - minimum);
  const y = (value) => 23 - (value - minimum) / range * 17;
  const coordinates = changes.map((value, index) =>
    `${4 + index / (points.length - 1) * 80},${y(value)}`).join(" ");
  const direction = points.at(-1) >= points[0] ? "positive" : "negative";
  return <svg className="table-sparkline" viewBox="0 0 88 28" role="img"
    aria-label={`${label}: latest ${displayValue(points.at(-1))}`} data-direction={direction}>
    <line x1="3" x2="85" y1={y(0)} y2={y(0)} stroke="var(--border)" strokeWidth="1" />
    <polyline points={coordinates} fill="none" stroke="currentColor" strokeWidth="1.75"
      strokeLinecap="round" strokeLinejoin="round" />
    <circle cx="84" cy={y(changes.at(-1))} r="2.3" fill="currentColor" />
  </svg>;
}
