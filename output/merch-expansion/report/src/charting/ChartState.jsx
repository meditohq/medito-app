import React from "react";

export function chartSkeletonFamily(chart = {}) {
  if (chart.presentation === "segmented") return "composition";
  if (["bullet", "progress", "rankedList", "groupedList", "comparison", "rangePosition"].includes(chart.presentation)) return "list";
  if (["line", "area", "stackedArea", "sparkline"].includes(chart.type)) return "trend";
  if (["pie", "heatmap", "scatter", "sankey", "funnel", "boxPlot"].includes(chart.type)) return chart.type;
  if (/horizontal/i.test(chart.type) || chart.type === "rankedList") return "list";
  return "bar";
}

export function ComponentSkeleton({ kind = "chart", chart = {}, rows = [] }) {
  const family = kind === "table" || kind === "metric" ? kind : chartSkeletonFamily(chart);
  const segments = chart.presentation === "progress" && Number.isInteger(chart.barOptions?.style?.segments)
    ? Math.max(2, Math.min(40, chart.barOptions.style.segments)) : 0;
  const columns = family === "heatmap" ? new Set(rows.map(row => row[chart.x])).size || 6 : 1;
  const bands = family === "heatmap" ? new Set(rows.map(row => row[chart.series])).size || 4 : 1;
  const count = family === "heatmap" ? Math.min(128, columns * bands)
    : family === "table" ? Math.min(rows.length || 7, 8) : family === "pie" ? 1
    : family === "metric" ? 2 : Math.min(rows.length || 4, 24);
  const lines = family === "trend" ? <path d="M4 70 Q45 70 65 58 T130 50 T190 34 T250 25 T296 14" />
    : family === "sankey" ? <><path d="M12 24 C100 24 170 65 288 65" /><path d="M12 75 C110 75 160 22 288 22" /></>
    : family === "pie" ? <circle cx="50" cy="50" r="34" strokeWidth="16" />
    : family === "scatter" ? Array.from({length: count}, (_, index) => <circle key={index} cx={15 + index * 47 % 270} cy={12 + index * 29 % 75} r="3" />)
    : null;
  return <div className={`component-skeleton-shape is-${family}`} data-skeleton-family={family} data-presentation={chart.presentation}
    style={{ "--skeleton-columns": columns, "--skeleton-rows": bands }} aria-hidden="true">
    {lines ? <svg viewBox={`0 0 ${family === "pie" ? 100 : 300} 100`} preserveAspectRatio={["pie", "scatter"].includes(family) ? "xMidYMid meet" : "none"}>{lines}</svg>
      : Array.from({ length: count }, (_, index) => <i key={index} style={{ "--skeleton-step": index % 4, "--skeleton-height": `${[55, 80, 65, 90][index % 4]}%`,
        height: chart.presentation === "rangePosition" ? 3 : undefined,
        background: segments ? `repeating-linear-gradient(to right,var(--skeleton-fill) 0 calc(${100 / segments}% - 3px),transparent 0 ${100 / segments}%)` : undefined }} />)}
  </div>;
}

export function ComponentState({ error = false, kind = "chart", height = 240, onRetry }) {
  const noun = kind === "table" ? "table" : kind === "metric" ? "metric" : "chart";
  return <div className="component-data-state" role={error ? "alert" : "status"} style={{ minHeight: height }}>
    <strong>{error ? `Couldn’t load this ${noun}` : "No data to display"}</strong>
    <p>{error ? "The data is unavailable. Try again in a moment." : "No rows are available for this view."}</p>
    {error && onRetry && <button type="button" className="button secondary" onClick={onRetry}>Try again</button>}
  </div>;
}
