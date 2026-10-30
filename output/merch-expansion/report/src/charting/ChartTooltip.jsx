import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Tooltip } from "recharts";
import { chartPointerTooltipPosition } from "../dashboard-ask.js";

import { categoryLabel, displayValue, label as humanize, tick } from "./chart-theme.js";
import { scatterTooltipIdentityField } from "./chart-data-shape.js";
import { orderTooltipEntries } from "./chart-transforms.js";

function MeasuredTooltipContent({ content, measure, ...props }) {
  const ref = useRef(null);
  // Recharts can mount tooltip content after its first active render. Observe
  // that content, but only measure when its size actually changes so position
  // updates do not feed a WebKit resize cycle during a drag.
  useLayoutEffect(() => {
    const card = ref.current?.firstElementChild;
    if (!card) return undefined;
    let width = -1, height = -1;
    const observer = new ResizeObserver(() => {
      if (!card.isConnected) return;
      const bounds = card.getBoundingClientRect();
      if (bounds.width === width && bounds.height === height) return;
      width = bounds.width;
      height = bounds.height;
      measure(card);
    });
    observer.observe(card);
    return () => { observer.disconnect(); measure(null); };
  }, [measure, props.active]);
  // The active payload can mount a new tooltip node. Measure after paint so
  // Recharts' position update cannot synchronously trigger this effect again.
  useEffect(() => {
    const frame = requestAnimationFrame(() => measure(ref.current?.firstElementChild));
    return () => cancelAnimationFrame(frame);
  }, [measure, props.active, props.payload]);
  return <div ref={ref} style={{ display: "contents" }}>
    {React.isValidElement(content) ? React.cloneElement(content, props)
      : typeof content === "function" ? content(props) : content}
  </div>;
}

/** Item tooltips follow the pointer, not the center of a cell or pie sector.
 * Position updates stay in this leaf; the chart/rows don't rerender on every move.
 * Keyboard navigation retains Recharts' datum anchor; selected cards stay pinned.
 */
export function PointerChartTooltip({ frameRef, content, touchOnly = false, touchPreview = false, ...props }) {
  const pointer = useRef(null), card = useRef(null), frame = useRef(null);
  const [position, setPosition] = useState(undefined);
  const [touchDismissed, setTouchDismissed] = useState(false);
  const place = useCallback(() => {
    const root = frameRef.current;
    if (!root || !pointer.current || root.querySelector("[data-chart-tooltip-pinned]")) return false;
    const chart = root.querySelector(".recharts-wrapper");
    if (!chart) return false;
    const bounds = chart.getBoundingClientRect();
    // Recharts keeps an inactive tooltip node with zero dimensions. The last
    // measured ref may still point there when the first touch activates a new
    // datum; read the visible card rather than waiting for a payload effect.
    const cardBounds = [card.current, ...(root.closest('.dashboard-component')?.querySelectorAll('.recharts-tooltip-wrapper .chart-tooltip') ?? [])]
      .filter(Boolean).map(element => element.getBoundingClientRect())
      .find(rect => rect.width && rect.height);
    if (!bounds.width || !bounds.height || !cardBounds) return false;
    const next = chartPointerTooltipPosition(bounds, { width: chart.offsetWidth, height: chart.offsetHeight },
      cardBounds, { width: window.innerWidth, height: window.innerHeight }, pointer.current);
    setPosition(current => current?.x === next.x && current?.y === next.y ? current : next);
    return true;
  }, [frameRef]);
  const measure = useCallback(element => {
    card.current = element;
    if (element) place();
  }, [place]);
  useEffect(() => {
    const root = frameRef.current;
    if (!root) return;
    let scrubMark = null;
    const schedule = () => {
      if (frame.current != null) return;
      const run = attempt => { frame.current = null;
        if (!place() && attempt < 3) frame.current = requestAnimationFrame(() => run(attempt + 1));
      };
      frame.current = requestAnimationFrame(() => run(0));
    };
    const move = event => {
      if (touchOnly && event.pointerType !== "touch") {
        // Recharts owns mouse positioning for these charts, but a mouse move
        // must still release a tooltip dismissed by the previous touch.
        setTouchDismissed(false);
        return;
      }
      if (event.pointerType === "touch" && event.type !== "pointerup") return;
      if (event.pointerType === "touch" && touchPreview && event.target.closest?.(
        '[data-heatmap-cell], .recharts-scatter-symbol, .recharts-sector')) {
        // iOS does not always synthesize a mouse move on a stationary tap.
        // Recharts needs one to resolve the active heatmap/scatter payload.
        root.querySelector('.recharts-surface')?.dispatchEvent(new MouseEvent('mousemove', {
          bubbles: true, clientX: event.clientX, clientY: event.clientY,
        }));
      }
      setTouchDismissed(false);
      pointer.current = { x: event.clientX, y: event.clientY, type: event.pointerType };
      schedule();
    };
    const reset = () => { scrubMark = null; pointer.current = null; setPosition(undefined); };
    const dismissTouch = () => { reset(); setTouchDismissed(true); };
    const leave = event => { if (event.pointerType !== "touch") reset(); };
    const outside = event => { if (event.pointerType === "touch" && !root.contains(event.target)) dismissTouch(); };
    const scrub = event => {
      const point = event.detail;
      const surface = root.querySelector('.recharts-surface');
      if (!surface || !Number.isFinite(point?.x) || !Number.isFinite(point?.y)) return;
      pointer.current = { x: point.x, y: point.y, type: 'touch' };
      setTouchDismissed(false);
      // ScatterChart does not resolve an active dot from a move on its surface.
      // Hit-test the drawn dots once per scrub frame and enter the nearest
      // one, preserving Recharts' own payload rather than reconstructing rows.
      const marks = root.querySelectorAll('.recharts-scatter-symbol');
      let target = surface;
      if (marks.length) {
        let distance = 36 * 36;
        for (const mark of marks) {
          const bounds = mark.getBoundingClientRect();
          const dx = point.x - (bounds.left + bounds.width / 2);
          const dy = point.y - (bounds.top + bounds.height / 2);
          const next = dx * dx + dy * dy;
          if (next < distance) { distance = next; target = mark; }
        }
        if (target !== scrubMark && target !== surface) target.dispatchEvent(new MouseEvent('mouseover', {
          bubbles: true, clientX: point.x, clientY: point.y,
        }));
        scrubMark = target;
      }
      // Native touchmove remains excluded to avoid the WebKit layout loop.
      target.dispatchEvent(new MouseEvent('mousemove', {
        bubbles: true, clientX: point.x, clientY: point.y,
      }));
      schedule();
    };
    const cancel = event => { if (event.pointerType === "touch") dismissTouch(); else reset(); };
    const scroll = () => { if (pointer.current?.type === "touch") dismissTouch(); else schedule(); };
    const focus = event => { if (event.target.matches?.(":focus-visible")) { reset(); setTouchDismissed(false); } };
    root.addEventListener("pointerdown", move, true);
    root.addEventListener("pointermove", move);
    root.addEventListener("pointerover", move);
    root.addEventListener("pointerup", move);
    root.addEventListener("data-chart-scrub", scrub);
    root.addEventListener("pointercancel", cancel);
    root.addEventListener("pointerleave", leave);
    document.addEventListener("pointerdown", outside, true);
    root.addEventListener("focusin", focus);
    window.addEventListener("resize", schedule);
    document.addEventListener("scroll", scroll, true);
    return () => {
      cancelAnimationFrame(frame.current); frame.current = null;
      root.removeEventListener("pointerdown", move, true);
      root.removeEventListener("pointermove", move); root.removeEventListener("pointerover", move);
      root.removeEventListener("pointerup", move); root.removeEventListener("pointercancel", cancel);
      root.removeEventListener("data-chart-scrub", scrub);
      root.removeEventListener("pointerleave", leave); document.removeEventListener("pointerdown", outside, true);
      root.removeEventListener("focusin", focus); window.removeEventListener("resize", schedule);
      document.removeEventListener("scroll", scroll, true);
    };
  }, [frameRef, place, touchOnly, touchPreview]);
  return <Tooltip {...props} active={touchDismissed ? false : props.active} position={position}
    allowEscapeViewBox={{ x: position != null, y: true }}
    content={<MeasuredTooltipContent content={content} measure={measure} />} />;
}

export function ChartTooltip({
  active,
  label,
  payload = [],
  stacked = false,
  vertical = false,
  resolveColor,
  mode = "default",
  xField,
  yField,
  groupField,
  xLabel,
  yLabel,
  formatValue,
  details,
  detailFields = [],
  headerValue,
  children,
  formatLabel, resolveStyle, comparisonMode = false, baseField = field => field,
}) {
  if (active && details) return <div className={`chart-tooltip chart-tooltip--plain${headerValue != null ? " chart-tooltip--details" : ""}`}>
    {headerValue != null ? <div className="chart-tooltip-heading"><strong>{label}</strong><b>{headerValue}</b></div>
      : label != null && <strong>{label}</strong>}
    {details.map(({ label: name, value }) => <span key={name}>{name}<b>{value}</b></span>)}
    {children}
  </div>;
  if (!active || !payload.length) return null;
  const row = payload[0]?.payload;
  if (mode === "pie") label = row?.[xField] ?? label;
  const ageUnit = /^(weeks?|days?|months?)\b/i.exec(xLabel ?? "")?.[1];
  if (ageUnit && label !== "" && label != null && Number.isFinite(Number(label))) {
    label = `${ageUnit.replace(/s$/i, "").replace(/^./, letter => letter.toUpperCase())} ${label}`;
  }
  if (mode === "heatmap" && row) {
    return (
      <div className="chart-tooltip chart-tooltip--plain">
        <strong>{String(tick(row[xField] ?? ""))}</strong>
        <span>
          {detailFields.find(({ field }) => field === groupField)?.label ?? humanize(String(groupField))}
          <b>{categoryLabel(groupField, row[groupField] ?? "—")}</b>
        </span>
        <span>
          {yLabel ?? humanize(String(yField))}
          <b>{row.__unknown ? "Not yet observed" : formatValue ? formatValue(row[yField], yField) : displayValue(row[yField])}</b>
        </span>
        {detailFields.filter(({ field }) => field !== groupField).map(({ field, label }) => <span key={field}>{label}<b>{displayValue(row[field])}</b></span>)}
      </div>
    );
  }
  if (mode === "scatter" && row) {
    const identityField = scatterTooltipIdentityField(row);
    const identity = identityField ? row[identityField] : undefined;
    return (
      <div className="chart-tooltip chart-tooltip--plain">
        {identity && <strong>{String(identity)}</strong>}
        <span>
          {xLabel ?? humanize(String(xField))}
          <b>{formatValue ? formatValue(row[xField], xField) : displayValue(row[xField])}</b>
        </span>
        <span>
          {yLabel ?? humanize(String(yField))}
          <b>{formatValue ? formatValue(row[yField], yField) : displayValue(row[yField])}</b>
        </span>
      </div>
    );
  }
  if (mode === "boxPlot" && row) {
    const statistics = [
      ["Maximum", row.maximum],
      ["75th percentile", row.upperQuartile],
      ["Median", row.median],
      ["25th percentile", row.lowerQuartile],
      ["Minimum", row.minimum],
    ];
    return (
      <div className="chart-tooltip chart-tooltip--plain chart-tooltip--distribution">
        <strong>{String(tick(row[xField] ?? label ?? ""))}</strong>
        {statistics.map(([name, value]) => (
          <span key={name} data-box-statistic={name}>
            {name}
            <b>{formatValue ? formatValue(value, yField) : displayValue(value)}</b>
          </span>
        ))}
      </div>
    );
  }
  const seenFields = new Set();
  const items = payload
    .filter((item) => {
      if (item.value == null || item.dataKey === "baseline") return false;
      const field = String(item.dataKey ?? item.name);
      if (seenFields.has(field)) return false;
      seenFields.add(field);
      return true;
    })
    .map((item) => {
      if (item.dataKey !== "magnitude" && item.dataKey !== "range") {
        return resolveColor ? { ...item, color: resolveColor(item) ?? item.color } : item;
      }
      const isTotal = Boolean(item.payload?.isTotal);
      const change = Number(item.payload?.change ?? item.value);
      const color = change < 0 ? "var(--negative)" : "var(--positive)";
      return {
        ...item,
        name: "Net change",
        value: isTotal ? item.payload?.runningTotal ?? item.payload?.balance : change,
        color: isTotal ? "var(--chart-neutral-fill, color-mix(in srgb, var(--text) 3%, var(--surface)))" : color,
        ...(isTotal
          ? {
              name: item.payload.totalType === "beginning" ? "Beginning total" : "Ending total",
            }
          : {}),
      };
    });
  const ordered = orderTooltipEntries(items, { stacked, vertical });
  // Comparison order must not flip when the previous value exceeds the current one.
  if (ordered.some(item => /previous/i.test(item.dataKey))) ordered.sort((a,b) => Number(/previous/i.test(a.dataKey)) - Number(/previous/i.test(b.dataKey)));
  const comparisonKeys = [...new Set(ordered.map(item => baseField(item.dataKey)))];
  if (comparisonMode && comparisonKeys.length > 1 && ordered.some(item => /previous/i.test(item.dataKey))) {
    const previous = ordered.filter(item => /previous/i.test(item.dataKey));
    const current = comparisonKeys.map(key => ordered.find(item => item.dataKey === key)
      ?? { ...ordered.find(item => baseField(item.dataKey) === key), dataKey:key, name:key, value:null });
    return <div className="chart-tooltip chart-tooltip-comparison">
      <div className="comparison-tooltip-grid"><div className="comparison-tooltip-row comparison-tooltip-heading"><span/><span data-current-period>{label != null ? categoryLabel(xField,tick(label)) : "Current"}</span><span>{formatLabel?.(previous[0]) ?? "Previous"}</span></div>
      {current.map(item => { const prior = previous.find(prior => baseField(prior.dataKey) === item.dataKey);
        return <div key={item.dataKey} className="comparison-tooltip-row"><span><i style={{background:item.color}}/>{formatLabel?.(item) ?? humanize(item.name)}</span>
          <b>{formatValue ? formatValue(item.value,item.dataKey) : displayValue(item.value)}</b>
          <b className="comparison-tooltip-prior">{prior ? formatValue ? formatValue(prior.value,prior.dataKey) : displayValue(prior.value) : "—"}</b></div>;
      })}</div>
    </div>;
  }
  return (
    <div className="chart-tooltip">
      {label != null && <strong>{categoryLabel(xField, tick(label))}</strong>}
      {ordered.map((item) => (
        <span key={`${item.dataKey}-${item.name}`}>
          <i data-comparison={resolveStyle?.(item)?.type} style={{ color: item.color ?? item.payload?.fill ?? item.fill ?? "var(--chart-1)", background: item.color ?? item.payload?.fill ?? item.fill ?? "var(--chart-1)", opacity:resolveStyle?.(item)?.opacity }} />
          {formatLabel ? formatLabel(item) : humanize(String(item.name ?? item.dataKey))}
          <b>{formatValue ? formatValue(item.value, item.dataKey) : displayValue(item.value)}</b>
        </span>
      ))}
    </div>
  );
}
