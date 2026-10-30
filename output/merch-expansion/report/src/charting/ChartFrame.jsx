import React, { useEffect, useRef, useState } from "react";
import { ResponsiveContainer } from "recharts";

export function collapsedLegendLayout(items) {
  const tops = [...new Set(items.map(item => item.offsetTop))].sort((a, b) => a - b);
  const visible = items.filter(item => item.offsetTop <= (tops[1] ?? tops[0]));
  return { height: Math.max(0, ...visible.map(item => item.offsetTop + item.offsetHeight)), visibleCount: visible.length };
}

export function ChartLegend({ items = [], onToggle, onIsolate, position = "bottom" }) {
  const legendRef = useRef(null);
  const [layout, setLayout] = useState({ height: 38, visibleCount: items.length });
  const [expanded, setExpanded] = useState(false);
  const labels = items.map(item => item.label).join("\n");
  const overflowing = layout.visibleCount < items.length;

  useEffect(() => {
    const legend = legendRef.current;
    if (!legend || position === "right") return undefined;
    const measure = () => {
      const { height, visibleCount } = collapsedLegendLayout([...legend.children]);
      setLayout(previous => previous.height === height && previous.visibleCount === visibleCount
        ? previous : { height, visibleCount });
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(legend);
    return () => observer.disconnect();
  }, [labels, position]);

  if (!items.length) return null;
  return <>
    <ul className={["chart-legend", position === "right" ? "chart-legend--right" : ""].filter(Boolean).join(" ")}
      ref={legendRef} data-expanded={expanded || undefined} data-overflowing={overflowing || undefined}
      aria-label="Chart legend" data-legend-position={position}
      style={position !== "right" ? { "--legend-collapsed-height": `${layout.height}px` } : undefined}>
      {items.map((item, index) => <li key={`${item.label}-${index}`}
        data-collapsed={!expanded && position !== "right" && index >= layout.visibleCount || undefined}
        inert={!expanded && position !== "right" && index >= layout.visibleCount ? true : undefined}>
        <button type="button" className="chart-legend-button"
          aria-label={`Toggle ${item.label}`} aria-pressed={item.visible !== false}
          title="Click to toggle. Double-click or press Shift+Enter to isolate."
          onClick={() => onToggle?.(item.value ?? item.label)}
          onDoubleClick={() => onIsolate?.(item.value ?? item.label)}
          onKeyDown={(event) => {
            if (event.shiftKey && ["Enter", " "].includes(event.key)) {
              event.preventDefault();
              onIsolate?.(item.value ?? item.label);
            }
          }} disabled={!onToggle}>
          <span className={`chart-legend-mark ${item.type ?? "square"}`}
            style={{ "--legend-color": item.color, opacity: item.opacity }} aria-hidden="true" />
          <span>{item.label}</span>
        </button>
      </li>)}
    </ul>
    {position !== "right" && (overflowing || expanded) && <button
      type="button"
      className="chart-legend-toggle"
      aria-expanded={expanded}
      onClick={() => setExpanded((current) => !current)}
    >
      {expanded ? "Show fewer categories" : `Show all ${items.length} categories`}
    </button>}
  </>;
}

export function ChartFrame({ chart, height = 240, xLabel, xLabelPosition = "bottom", legend = [], onLegendToggle,
  onLegendIsolate, onChartClick, plotInset, zoomed = false, onResetZoom, legendPosition, scaleLegend, frameRef, accessibleLabel, annotationNotes
}) {
  const right = legendPosition === "right";
  const footerXLabel = xLabel && !["top", "inline-right"].includes(xLabelPosition);
  const bandLegendGroups = scaleLegend?.bands?.reduce((groups, band) => {
    const label = band.legendGroup ?? band.label;
    if (!label) return groups;
    const existing = groups.find((group) => group.label === label);
    if (existing) existing.colors.push(band.color);
    else groups.push({ label, colors: [band.color] });
    return groups;
  }, []);
  const legendContent = <ChartLegend items={legend} onToggle={onLegendToggle}
    onIsolate={onLegendIsolate} position={right ? "right" : "bottom"} />;

  return (
    <div className={["chart-layout", right ? "chart-layout--legend-right" : ""].filter(Boolean).join(" ")}
      style={plotInset ? {
        "--chart-plot-left": `${plotInset.left ?? 0}px`,
        "--chart-plot-right": `${plotInset.right ?? 0}px`,
      } : undefined}>
      {zoomed && onResetZoom && <button type="button" className="chart-reset-zoom"
        onClick={onResetZoom}>Reset zoom</button>}
      {xLabel && xLabelPosition === "top" && <p className="chart-axis-label chart-axis-label--top">{xLabel}</p>}
      <div ref={frameRef} className="chart-frame" style={{ minHeight: height }} role="group" aria-label={accessibleLabel || xLabel || "Reviewed data chart"} onClick={onChartClick}>
        <ResponsiveContainer width="100%" height="100%">{chart}</ResponsiveContainer>
        {xLabel && xLabelPosition === "inline-right"
          && <p className="chart-axis-label chart-axis-label--inline-right">{xLabel}</p>}
      </div>
      {right && legendContent}
      {Boolean(footerXLabel || scaleLegend || (!right && legend.length)) && <div className="chart-footer">
        {footerXLabel && <p className="chart-axis-label">{xLabel}</p>}
        {scaleLegend && (bandLegendGroups?.length
          ? <div className="chart-scale-band-legend" aria-label={`${scaleLegend.label} color bands`}>
              {bandLegendGroups.map(({ label, colors }) => <span key={label}
                data-single-band={colors.length === 1 || undefined}
                style={colors.length === 1 ? { "--chart-band-color": colors[0] } : undefined}>
                <span className="chart-scale-band-swatches" aria-hidden="true">
                  {colors.map((color, index) => <i key={`${color}-${index}`} style={{ background: color }} />)}
                </span>
                {label}
              </span>)}
            </div>
          : <div className="chart-scale-legend" aria-label={`${scaleLegend.label} color scale`}>
              <span>{scaleLegend.minimum}</span>
              <i aria-hidden="true" style={{ "--chart-scale-color": scaleLegend.color }} />
              <span>{scaleLegend.maximum}</span>
            </div>)}
        {!right && legendContent}
      </div>}
      {annotationNotes}
    </div>
  );
}
