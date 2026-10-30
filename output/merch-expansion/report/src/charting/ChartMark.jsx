import React, { useEffect, useId, useLayoutEffect, useRef, useState } from "react";
import { useDashboardAsk } from "../components/DashboardAsk.jsx";
import { Tooltip } from "../components/ui.jsx";
import { chartMarkTooltipPosition } from "../dashboard-ask.js";

/** Capture an already-visible plot tooltip without moving its selected-state anchor. */
export function captureChartHoverCard(element, tooltip) {
  if (!element || !tooltip) return undefined;
  const bounds = tooltip.getBoundingClientRect(), chartBounds = element.getBoundingClientRect();
  if (!bounds.width || !bounds.height) return undefined;
  const style = getComputedStyle(tooltip);
  return { element, width: bounds.width, height: bounds.height,
    left: bounds.left - chartBounds.left, top: bounds.top - chartBounds.top,
    radius: style.borderRadius, shadow: style.boxShadow, background: style.backgroundColor };
}

/** A custom visualization's native button, using the same selection card as ChartRenderer. */
export function ChartMark({ context, tooltip, tooltipEnabled = true, children, ...props }) {
  const { selectChartMark, canSelectChartMark, selectedMarkElement, pinnedChartElement, dismissChartMark } = useDashboardAsk();
  const markRef = useRef(null), tooltipRef = useRef(null);
  const pointer = useRef(null), placeRef = useRef(null);
  const id = useId();
  const [hover, setHover] = useState(false);
  const [positioned, setPositioned] = useState(false);
  const [pendingClick, setPendingClick] = useState(null);
  const selected = selectedMarkElement === markRef.current && selectedMarkElement != null;
  const root = () => markRef.current?.closest("[data-chart-interaction-root]") ?? markRef.current;
  const blocked = () => pinnedChartElement === root() || root()?.hasAttribute("data-chart-tooltip-pinned");
  const visible = tooltipEnabled && hover && !blocked();
  const show = () => { if (!blocked()) setHover(true); };
  function move(event) {
    pointer.current = { x: event.clientX, y: event.clientY };
    if (visible) placeRef.current?.();
  }
  useLayoutEffect(() => {
    if (!visible) return undefined;
    let geometry;
    const mark = markRef.current, card = tooltipRef.current?.querySelector(".chart-tooltip");
    const wrapper = tooltipRef.current?.closest(".chart-mark-tooltip");
    if (!mark || !card || !wrapper) return undefined;
    function place() {
      geometry ??= { mark: mark.getBoundingClientRect(), card: card.getBoundingClientRect() };
      const next = chartMarkTooltipPosition(geometry.mark, geometry.card,
        { width: window.innerWidth, height: window.innerHeight }, 12, 8, pointer.current);
      wrapper.style.transform = `translate3d(${next.left}px, ${next.top}px, 0)`;
      wrapper.style.visibility = "visible";
    }
    const invalidate = () => { geometry = null; place(); };
    const observer = new ResizeObserver(invalidate);
    observer.observe(mark); observer.observe(card);
    placeRef.current = place;
    place();
    setPositioned(true);
    window.addEventListener("resize", invalidate);
    document.addEventListener("scroll", invalidate, true);
    return () => { placeRef.current = null;
      observer.disconnect();
      window.removeEventListener("resize", invalidate); document.removeEventListener("scroll", invalidate, true); };
  }, [visible]);
  useLayoutEffect(() => {
    if (!pendingClick || !visible || !positioned) return;
    const element = markRef.current, card = tooltipRef.current?.querySelector(".chart-tooltip");
    if (!card || !element) return;
    const bounds = card.getBoundingClientRect(), mark = element.getBoundingClientRect(), style = getComputedStyle(card);
    const selected = selectChartMark({ ...context, hoverCard: { element, rootElement: root(), width: bounds.width, height: bounds.height,
      left: bounds.left - mark.left, top: bounds.top - mark.top,
      radius: style.borderRadius, shadow: style.boxShadow, background: style.backgroundColor } }, pendingClick);
    setPendingClick(null);
    setHover(false);
  }, [pendingClick, visible, positioned, context, selectChartMark]);
  useEffect(() => {
    const mark = markRef.current;
    setHover(false); setPositioned(false); setPendingClick(null);
    return () => dismissChartMark(mark);
  }, [context.row]);
  function click(event) {
    props.onClick?.(event);
    if (event.defaultPrevented || !canSelectChartMark(context) || blocked()) return;
    if (!tooltipEnabled) { selectChartMark(context, event); return; }
    // A tap or keyboard activation first measures the same hover card before pinning it.
    if (!visible) setPositioned(false);
    setHover(true);
    setPendingClick({ target: event.currentTarget, detail: event.detail });
  }
  return <>
    <button {...props} ref={markRef} type="button" data-chart-mark
      aria-haspopup={canSelectChartMark(context) ? "dialog" : undefined} aria-expanded={selected}
      aria-describedby={visible ? id : undefined}
      onPointerEnter={event => { props.onPointerEnter?.(event); move(event); show(); }}
      onPointerMove={event => { props.onPointerMove?.(event); move(event); }}
      onPointerLeave={event => { props.onPointerLeave?.(event); if (event.pointerType !== "touch") setHover(false); }}
      onPointerCancel={event => { props.onPointerCancel?.(event); pointer.current = null; setHover(false); }}
      onFocus={event => { props.onFocus?.(event); if (event.currentTarget.matches(":focus-visible")) pointer.current = null; show(); }}
      onBlur={event => { props.onBlur?.(event); setHover(false); }}
      onKeyDown={event => { props.onKeyDown?.(event); if (event.key === "Escape") setHover(false); }} onClick={click}>{children}</button>
    {visible && <Tooltip portal visible id={id} className="chart-mark-tooltip" style={{ left: 0, top: 0, visibility: "hidden" }}>
      <span ref={tooltipRef}>{tooltip}</span>
    </Tooltip>}
  </>;
}
