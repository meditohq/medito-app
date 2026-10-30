import React, { useEffect, useId, useLayoutEffect, useMemo, useRef, useState } from "react";

import { ChartTooltip } from "./ChartTooltip.jsx";
import { funnelStageColor } from "./chart-theme.js";
import { funnelLayout, funnelRibbonSegments, funnelStages } from "./chart-transforms.js";

const percent = (value) => Number.isFinite(value)
  ? new Intl.NumberFormat(undefined, { style: "percent", maximumFractionDigits: 1 }).format(value) : "—";
const exactValue = (value) => Number.isFinite(value)
  ? new Intl.NumberFormat(undefined, { maximumSignificantDigits: 21 }).format(value) : "—";
/** Ordered, proportional stage ribbons shared by dashboards, reports, and inline charts. */
export function FunnelRenderer({ rows, x, y, height = 240, chartId, colorFor, formatValue,
  formatExactValue = exactValue, formatDropoff = exactValue, onSelect, onChartClick }) {
  const id = useId().replace(/:/gu, "");
  const root = useRef(null);
  const tooltip = useRef(null);
  const [active, setActive] = useState(null);
  const [width, setWidth] = useState(null);
  const pointerType = useRef("mouse");
  const suppressFocus = useRef(false);
  const { stages, segments, maximum } = useMemo(() => {
    const stages = funnelStages(rows, x, y);
    return { stages, segments: funnelRibbonSegments(stages),
      maximum: Math.max(0, ...stages.map((stage) => stage.__funnelValue ?? 0)) };
  }, [rows, x, y]);
  const layout = funnelLayout(width, stages.length);
  const activeStage = stages[active?.index];
  const firstLabel = stages[0]?.__funnelStage || "first stage";
  const previousLabel = stages[active?.index - 1]?.__funnelStage || "previous stage";
  const activeValue = activeStage?.__funnelValue;
  const exactActiveValue = Number.isFinite(activeValue) ? formatExactValue(activeValue) : "—";
  const difference = activeStage?.__funnelDropoff;
  const ribbonHeight = Math.max(120, height - (layout === "compact" ? 112 : 80));
  useLayoutEffect(() => {
    const element = root.current;
    if (!element) return;
    const measure = () => setWidth(element.clientWidth);
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    const keyboard = () => { pointerType.current = "keyboard"; };
    element.ownerDocument.addEventListener("keydown", keyboard, true);
    return () => {
      observer.disconnect();
      element.ownerDocument.removeEventListener("keydown", keyboard, true);
    };
  }, [stages.length]);
  useEffect(() => {
    if (!active?.pinned) return;
    const dismiss = (event) => {
      if (!root.current?.contains(event.target)
        || !event.target.closest(".chart-funnel-stage, .chart-funnel-tooltip")) setActive(null);
    };
    const document = root.current.ownerDocument;
    document.addEventListener("pointerdown", dismiss, true);
    return () => document.removeEventListener("pointerdown", dismiss, true);
  }, [active?.pinned]);
  useLayoutEffect(() => {
    if (active?.pinned) tooltip.current?.focus({ preventScroll: true });
  }, [active?.pinned, active?.index]);
  const show = (index, event, pinned = false) => {
    const bounds = root.current.getBoundingClientRect();
    const target = event.currentTarget.getBoundingClientRect();
    if (target.right <= bounds.left || target.left >= bounds.right) { setActive(null); return; }
    const touch = pinned && pointerType.current === "touch" && event.detail > 0;
    const pointer = (touch || !pinned) && Number.isFinite(event.clientX) && Number.isFinite(event.clientY);
    setActive({ index, pinned, touch, anchored: !pointer,
      x: (pointer ? event.clientX : target.left + target.width / 2) - bounds.left,
      y: pointer ? event.clientY - bounds.top : target.bottom - bounds.top,
    });
  };
  useLayoutEffect(() => {
    if (!activeStage || !tooltip.current) return;
    const bounds = root.current.getBoundingClientRect();
    const tip = tooltip.current.getBoundingClientRect();
    const stage = root.current.querySelector(`[data-stage-index="${active.index}"]`).getBoundingClientRect();
    const x = active.anchored ? stage.left + stage.width / 2 - bounds.left : active.x;
    const y = active.anchored ? stage.bottom - bounds.top : active.y;
    const preferredLeft = active.touch ? x - tip.width / 2
      : x + 12 + tip.width <= bounds.width ? x + 12 : x - tip.width - 12;
    const minTop = Math.max(0, 8 - bounds.top);
    const maxTop = Math.min(bounds.height - tip.height, root.current.ownerDocument.documentElement.clientHeight - bounds.top - tip.height - 8);
    const above = y - tip.height - (active.touch ? 24 : 12);
    const below = y + (active.touch ? 24 : 12);
    const preferredTop = active.touch ? above >= minTop ? above : below <= maxTop ? below : Math.max(minTop, above)
      : below <= maxTop ? below : above;
    tooltip.current.style.left = `${Math.max(0, Math.min(bounds.width - tip.width, preferredLeft))}px`;
    tooltip.current.style.top = `${Math.max(0, Math.max(minTop, Math.min(maxTop, preferredTop)))}px`;
  }, [active, activeStage, width]);
  if (!stages.length) return <div className="chart-funnel-empty">No funnel stages</div>;
  const touchClick = (event) => event.nativeEvent.pointerType === "touch"
    || pointerType.current === "touch" && event.detail > 0;
  const dismiss = (restoreFocus = false) => {
    if (restoreFocus === true && active?.pinned) {
      suppressFocus.current = true;
      root.current.querySelector(`[data-stage-index="${active.index}"]`)?.focus({ preventScroll: true });
      suppressFocus.current = false;
    }
    setActive(null);
  };
  return <div ref={root} className="chart-funnel" data-funnel-layout={layout} data-chart-id={chartId} data-reviewed-rows
    onPointerDownCapture={(event) => { pointerType.current = event.pointerType; }}
    onKeyDown={(event) => {
      pointerType.current = "keyboard";
      if (event.key === "Escape") { event.stopPropagation(); dismiss(true); }
    }}
    onBlurCapture={(event) => { if (!event.currentTarget.contains(event.relatedTarget)) dismiss(); }}
    onClickCapture={(event) => {
      if (!touchClick(event) && !event.target.closest(".chart-funnel-tooltip")) onChartClick?.(event);
    }}
    style={{ "--funnel-stage-count": stages.length, "--funnel-ribbon-height": `${ribbonHeight}px` }}>
    <div className="chart-funnel-scroll" onScroll={(event) => {
      const focused = event.currentTarget.querySelector(".chart-funnel-stage:focus");
      if (focused) show(Number(focused.dataset.stageIndex), { currentTarget: focused });
      else setActive(null);
    }}>
      <div className="chart-funnel-canvas">
        <svg className="chart-funnel-ribbon" viewBox={`0 0 ${stages.length * 100} 200`}
          preserveAspectRatio="none" aria-hidden="true">
          <defs><linearGradient id={`${id}-fill`} gradientUnits="userSpaceOnUse" x1="0" x2={stages.length * 100} y1="0" y2="0">
            {stages.flatMap((stage, index) => [0, 1].map((edge) => <stop key={`${index}-${edge}`}
              data-stage-stop={edge === 0 ? "start" : "end"}
              offset={`${(index + edge) / stages.length * 100}%`}
              stopColor={funnelStageColor(colorFor(stage, index), index, stages.length, active?.index === index)} />))}
          </linearGradient></defs>
          {segments.map(({ path }, index) => <path key={index} className="chart-funnel-band"
            d={path} fill={`url(#${id}-fill)`} />)}
        </svg>
        <ol className="chart-funnel-stages" aria-label="Funnel stages">
          {stages.map((stage, index) => <li key={index}>
            <button type="button" className="chart-funnel-stage" data-stage-index={index} data-active={active?.index === index || undefined}
              aria-label={`${stage.__funnelStage || "Unnamed stage"}: ${Number.isFinite(stage.__funnelValue) ? formatExactValue(stage.__funnelValue) : "—"}, ${percent(stage.__funnelShare)} of ${firstLabel}`}
              aria-describedby={active?.index === index && !active.pinned ? `${id}-tooltip` : undefined}
              aria-expanded={active?.pinned ? active.index === index : undefined}
              aria-controls={active?.pinned && active.index === index ? `${id}-tooltip` : undefined}
              onPointerEnter={(event) => { if (event.pointerType !== "touch" && !active?.pinned) show(index, event); }}
              onPointerMove={(event) => { if (event.pointerType !== "touch" && !active?.pinned) show(index, event); }}
              onPointerLeave={() => setActive((current) => current?.anchored || current?.index !== index ? current : null)}
              onFocus={(event) => { if (!suppressFocus.current && pointerType.current !== "touch" && !active?.pinned) show(index, event); }}
              onClick={(event) => {
                if (touchClick(event)) {
                  if (active?.pinned && active.index === index) dismiss();
                  else show(index, event, true);
                } else onSelect?.(rows[index], index, event);
              }}>
              <span className="chart-funnel-stage-bar" aria-hidden="true"><span className="chart-funnel-stage-bar-fill"
                style={{ width: `${maximum > 0 ? (stage.__funnelValue ?? 0) / maximum * 100 : 0}%`,
                  backgroundColor: funnelStageColor(colorFor(stage, index), index, stages.length, active?.index === index) }} /></span>
              <span className="chart-funnel-stage-name">{stage.__funnelStage || "Unnamed stage"}</span>
              <span className="metric-value chart-funnel-stage-value">{Number.isFinite(stage.__funnelValue) ? formatValue(stage.__funnelValue) : "—"}</span>
              <span className="chart-funnel-stage-share"><span>{percent(stage.__funnelShare)}</span></span>
            </button>
          </li>)}
        </ol>
      </div>
    </div>
    {activeStage && <div ref={tooltip} id={`${id}-tooltip`} role={active.pinned ? "dialog" : "tooltip"} tabIndex={active.pinned ? -1 : undefined}
      aria-label={active.pinned ? `${activeStage.__funnelStage || "Unnamed stage"} details` : undefined}
      className="chart-funnel-tooltip" data-pinned={active.pinned || undefined}>
      <ChartTooltip active label={activeStage.__funnelStage || "Unnamed stage"} headerValue={exactActiveValue}
        details={active.index > 0 ? [
          { label: `${previousLabel} → ${activeStage.__funnelStage || "Unnamed stage"}`, value: percent(activeStage.__funnelConversion) },
          { label: difference < 0 ? "Increase" : "Drop-off", value: Number.isFinite(difference)
            ? `${difference > 0 ? "−" : difference < 0 ? "+" : ""}${formatDropoff(Math.abs(difference))}` : "—" },
        ] : []}>
      {active.pinned && <div className="chart-funnel-detail-actions">
        {onSelect && <button type="button" className="button ghost" onClick={() => {
          const target = root.current.querySelector(`[data-stage-index="${active.index}"]`);
          dismiss(true);
          onSelect(rows[active.index], active.index, { nativeEvent: { target, detail: 0 } });
        }}>Ask about this stage</button>}
        <button type="button" className="button ghost" onClick={() => dismiss(true)}>Done</button>
      </div>}
      </ChartTooltip>
    </div>}
  </div>;
}
