import React, { createContext, useContext, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { createPortal, flushSync } from "react-dom";

import { compact } from "../charting/chart-theme.js";
import { SelectedChartRegion } from "../charting/SelectedChartRegion.jsx";
import { chartPointSelection, dashboardAskPrompt, pinnedChartCardPosition } from "../dashboard-ask.js";
import { dataAppPromptLinkProps } from "../data-app-handoff.js";
import {
  codexDataAppPromptUrl,
  currentDataAppReference,
  currentDataAppViewUrl,
  isCodexBrowser,
} from "../runtime-environment.js";
import { Icon } from "./Icon.jsx";
import editIcon from "./icons/dashboard-icon-edit.svg?raw";
import summaryIcon from "./icons/dashboard-icon-summaryBubble.svg?raw";
import reportIcon from "./icons/dashboard-icon-textDocument.svg?raw";
import alertIcon from "./icons/dashboard-icon-alertBell.svg?raw";
import chatIcon from "./icons/dashboard-icon-chatBubble.svg?raw";

const askIconAssets = { edit: editIcon, summaryBubble: summaryIcon, textDocument: reportIcon, alertBell: alertIcon, chatBubble: chatIcon };

export function DashboardAskIcon({ name, size = 16 }) {
  const svg = Object.hasOwn(askIconAssets, name) ? askIconAssets[name] : null;
  if (!svg) return <Icon name={name} size={size} />;
  // Only these bundled, reviewed assets enter the DOM; no prompt or remote SVG.
  return <span className="dashboard-icon dashboard-ask-icon" aria-hidden="true" data-dashboard-icon={name}
    style={{ width: size, height: size }} dangerouslySetInnerHTML={{ __html: svg }} />;
}

const DashboardAskContext = createContext({
  selectionEnabled: false,
  openDashboardComposer: () => {},
  selectChartSection: () => {},
  selectChartMark: () => {},
  canSelectChartMark: () => false,
  selectedMarkElement: null,
  pinnedChartElement: null,
  dismissChartMark: () => {},
});
const chartRootSelector = ".recharts-wrapper, [data-chart-interaction-root]";

function handoffOwnsInteraction(event) {
  return Boolean(event.target?.closest?.("[data-data-app-handoff-navigation]"))
    || Boolean(document.querySelector('.data-app-handoff-dialog[data-state="open"]'));
}

export function PinnedChartCard({ hoverCard, actions, canAsk, onAsk, onClose, panelRef }) {
  useLayoutEffect(() => {
    const panel = panelRef.current;
    if (!panel) return;
    const finalHeight = panel.getBoundingClientRect().height;
    const animation = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ? null
      : panel.animate?.([{ height: `${hoverCard.height}px` }, { height: `${finalHeight}px` }], { duration: 160, easing: "ease-out" });
    const contentAnimation = animation && panel.querySelector(".chart-pinned-actions")?.animate?.(
      [{ opacity: 0 }, { opacity: 1 }], { duration: 120, easing: "ease-out" });
    (panel.querySelector("button") ?? panel).focus({ preventScroll: true });
    return () => { animation?.cancel(); contentAnimation?.cancel(); };
  }, [hoverCard]);
  return <div ref={panelRef} className="chart-tooltip chart-pinned-card dashboard-ask-panel" role="dialog" tabIndex={-1} aria-label="Selected chart data"
    style={{ width: hoverCard.width, borderRadius: hoverCard.radius, boxShadow: hoverCard.shadow, background: hoverCard.background }}>
    {(actions.length > 0 || canAsk) && <div className="chart-pinned-actions">
      {actions.map(action => <button key={action.label} type="button" onClick={() => { onClose(); action.onSelect(); }}><span>{action.label}</span><Icon name="arrowUpRight" size={14} /></button>)}
      {canAsk && <button type="button" onClick={onAsk}>Ask ChatGPT</button>}
    </div>}
  </div>;
}
const COMPOSER_MAX_LINES = 4;
const HEADER_COMPOSER_WIDTH = 260;
const HEADER_COMPOSER_HEIGHT = 36;
const HEADER_COMPOSER_ACTIVE_HEIGHT = 68;
const HEADER_ANCHOR_GAP = 7;
const HEADER_MORPH_DURATION = 150;
const HEADER_UNMORPH_DURATION = HEADER_MORPH_DURATION + 50;

const ASK_LAYOUT = {
  menu: { width: 116, height: 36 },
  actions: { width: 240, height: 96 },
  composer: {
    width: 320,
    minHeight: 96,
    radius: 18,
    padding: { top: 12, right: 6, bottom: 6, left: 12 },
    footerGap: 8,
    footerHeight: 28,
    offsetX: 0,
    translateY: 4,
  },
  viewportPadding: 12,
};

const ASK_MOTION = {
  entrance: {
    startGap: 8,
    endGap: 16,
    startScale: 0.875,
    shadowY: 2,
    shadowBlur: 6,
    duration: 140,
    easing: "cubic-bezier(0.23, 1, 0.32, 1)",
  },
  compose: {
    easing: "cubic-bezier(0.23, 1, 0.32, 1)",
    resizeDuration: 160,
    fadeDuration: 180,
    contentDuration: 300,
    contentSlide: 0,
    contentBlur: 0,
    contentScale: 1,
  },
};

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value));
}

function panelSize(phase, composerHeight = ASK_LAYOUT.composer.minHeight) {
  if (phase === "compose") return { width: ASK_LAYOUT.composer.width, height: composerHeight };
  return ASK_LAYOUT[phase] ?? ASK_LAYOUT.menu;
}

function panelPosition(anchor, phase, anchorGap, composerHeight, reservedHeight) {
  const { width, height } = panelSize(phase, composerHeight);
  const left = clamp(
    anchor.x,
    width / 2 + ASK_LAYOUT.viewportPadding,
    window.innerWidth - width / 2 - ASK_LAYOUT.viewportPadding,
  );
  const bottom = anchor.bottom ?? anchor.y;
  const requiredHeight = (reservedHeight ?? height) + anchorGap;
  const spaceAbove = anchor.y - ASK_LAYOUT.viewportPadding;
  const spaceBelow = window.innerHeight - bottom - ASK_LAYOUT.viewportPadding;
  const placement = spaceAbove >= requiredHeight || spaceAbove >= spaceBelow ? "above" : "below";
  return { left, top: placement === "above" ? anchor.y : bottom, placement };
}

function composerViewportCorrection(position, composerHeight, source, headerMorph = false, headerRight = null) {
  if (!position) return { x: 0, y: 0 };
  const padding = ASK_LAYOUT.viewportPadding;
  const composerWidth = source === "header" ? HEADER_COMPOSER_WIDTH : ASK_LAYOUT.composer.width;
  const width = Math.min(composerWidth, Math.max(0, window.innerWidth - padding * 2));
  const height = Math.min(composerHeight, Math.max(0, window.innerHeight - padding * 2));
  const naturalLeft = source === "header"
    ? position.left - (headerMorph ? width : width / 2)
    : position.left - ASK_LAYOUT.menu.width / 2 - 2 - ASK_LAYOUT.composer.offsetX;
  const targetLeft = source === "header" && !headerMorph && Number.isFinite(headerRight)
    ? headerRight - width
    : naturalLeft;
  const anchorGap = source === "header" ? HEADER_ANCHOR_GAP : ASK_MOTION.entrance.endGap;
  const translateY = source === "header" ? 0 : ASK_LAYOUT.composer.translateY;
  const baseTop = headerMorph
    ? position.top - HEADER_COMPOSER_HEIGHT / 2
    : position.top +
      translateY +
      (position.placement === "above" ? -anchorGap - height : anchorGap);
  const left = clamp(targetLeft, padding, Math.max(padding, window.innerWidth - padding - width));
  const top = source === "header" && !headerMorph
    ? clamp(baseTop, padding, Math.max(padding, window.innerHeight - padding - height))
    : baseTop;
  return { x: left - naturalLeft, y: top - baseTop };
}

function resolveAnchor(source) {
  if (source?.hoverCard?.element?.isConnected) {
    const bounds = source.hoverCard.element.getBoundingClientRect();
    return { x: bounds.left + source.hoverCard.left, y: bounds.top + source.hoverCard.top, bottom: bounds.top + source.hoverCard.top + source.hoverCard.height };
  }
  if (source?.kind === "region" && source.element?.isConnected) {
    const bounds = source.element.getBoundingClientRect();
    return {
      x: bounds.left + source.left + source.width / 2,
      y: bounds.top + source.top,
      bottom: bounds.top + source.top + source.height,
    };
  }
  if (source?.kind === "element" && source.element?.isConnected) {
    const bounds = source.element.getBoundingClientRect();
    const y = bounds.top + source.yOffset;
    return { x: bounds.left + (source.xOffset ?? bounds.width / 2), y, bottom: y };
  }
  if (source?.kind === "range") {
    const bounds = source.range.getBoundingClientRect();
    if (bounds.width || bounds.height)
      return {
        x: bounds.left + bounds.width / 2,
        y: bounds.top,
        bottom: bounds.bottom,
      };
  }
  return null;
}

function axisBand(wrapper, axis) {
  const selector =
    axis === "x"
      ? ".recharts-xAxis-tick-labels .recharts-cartesian-axis-tick-label"
      : ".recharts-yAxis-tick-labels .recharts-cartesian-axis-tick-label";
  const centers = [...wrapper.querySelectorAll(selector)]
    .map((tick) => {
      const bounds = tick.getBoundingClientRect();
      return axis === "x" ? bounds.left + bounds.width / 2 : bounds.top + bounds.height / 2;
    })
    .filter(Number.isFinite)
    .sort((left, right) => left - right);
  const gaps = centers
    .slice(1)
    .map((center, index) => center - centers[index])
    .filter((gap) => gap > 2);
  if (!gaps.length) return null;
  const size = Math.min(...gaps);
  return {
    centers,
    size,
    start: centers[0] - size / 2,
    end: centers.at(-1) + size / 2,
  };
}

function chartRegionSource(target, event, chartType) {
  const rankedRow = target?.closest?.(".chart-ranked-list-row, .chart-funnel-stage, [data-chart-mark]");
  if (rankedRow) {
    const bounds = rankedRow.getBoundingClientRect();
    if (!bounds.width || !bounds.height) return null;
    return {
      kind: "region",
      element: rankedRow,
      left: 0,
      top: 0,
      width: bounds.width,
      height: bounds.height,
      markElement: rankedRow,
      selectionType: "mark",
      renderOverlay: !rankedRow.hasAttribute("data-chart-mark"),
    };
  }
  const wrapper = target?.closest?.(".recharts-wrapper");
  if (!wrapper) return null;
  const wrapperBounds = wrapper.getBoundingClientRect();
  const cursor = wrapper.querySelector(".recharts-tooltip-cursor");
  const barMark = target?.closest?.(".recharts-rectangle");
  if (!barMark && ["line", "sparkline", "area", "stackedArea"].includes(chartType)) {
    return chartPointSelection(wrapper, target);
  }
  const lineMark =
    target?.closest?.(".recharts-dot, .recharts-curve") ??
    wrapper.querySelector(".recharts-active-dot circle, .recharts-active-dot");
  const markElement = barMark ?? lineMark;
  const targetBounds = markElement?.getBoundingClientRect?.() ?? target?.getBoundingClientRect?.();
  const cursorBounds = cursor?.getBoundingClientRect?.();
  let bounds = barMark
    ? targetBounds
    : cursorBounds?.width > 2 && cursorBounds?.height > 2
      ? cursorBounds
      : targetBounds;
  if (lineMark && !(cursorBounds?.height > 2 && cursorBounds.width <= 2)) {
    const band = axisBand(wrapper, "x");
    const plotBounds = wrapper.querySelector(".recharts-cartesian-grid")?.getBoundingClientRect();
    const pointerX = event?.clientX ?? targetBounds?.left + targetBounds?.width / 2;
    const center = band?.centers.length
      ? band.centers.reduce(
          (nearest, candidate) => (Math.abs(candidate - pointerX) < Math.abs(nearest - pointerX) ? candidate : nearest),
          band.centers[0],
        )
      : null;
    if (band && plotBounds && Number.isFinite(center)) {
      const left = Math.max(band.start, center - band.size / 2);
      const right = Math.min(band.end, center + band.size / 2);
      bounds = {
        left,
        top: plotBounds.top,
        width: right - left,
        height: plotBounds.height,
      };
    }
  } else if (cursorBounds?.height > 2 && cursorBounds.width <= 2) {
    const band = axisBand(wrapper, "x");
    const center = cursorBounds.left + cursorBounds.width / 2;
    const width = band?.size ?? Math.max(targetBounds?.width ?? 0, 32);
    const left = Math.max(band?.start ?? wrapperBounds.left, center - width / 2);
    const right = Math.min(band?.end ?? wrapperBounds.right, center + width / 2);
    bounds = {
      left,
      top: cursorBounds.top,
      width: right - left,
      height: cursorBounds.height,
    };
  } else if (cursorBounds?.width > 2 && cursorBounds.height <= 2) {
    const band = axisBand(wrapper, "y");
    const center = cursorBounds.top + cursorBounds.height / 2;
    const height = band?.size ?? Math.max(targetBounds?.height ?? 0, 32);
    const top = Math.max(band?.start ?? wrapperBounds.top, center - height / 2);
    const bottom = Math.min(band?.end ?? wrapperBounds.bottom, center + height / 2);
    bounds = {
      left: cursorBounds.left,
      top,
      width: cursorBounds.width,
      height: bottom - top,
    };
  }
  if (!bounds?.width || !bounds?.height) return null;
  return {
    kind: "region",
    element: wrapper,
    left: bounds.left - wrapperBounds.left,
    top: bounds.top - wrapperBounds.top,
    width: bounds.width,
    height: bounds.height,
    markElement,
    selectionType: barMark ? "mark" : "band",
  };
}

function chartSectionSource(target) {
  const wrapper = target?.closest?.(".recharts-wrapper, .chart-funnel");
  if (!wrapper) return null;
  const bounds = wrapper.getBoundingClientRect();
  if (!bounds.width || !bounds.height) return null;
  return {
    kind: "region",
    element: wrapper,
    left: 0,
    top: 0,
    width: bounds.width,
    height: bounds.height,
    selectionType: "band",
  };
}

function contextLabel(context) {
  if (context.kind === "text") return `Selected text · “${context.label}”`;
  if (context.kind === "dashboard") return "Entire dashboard";
  const value = Number.isFinite(context.value) ? compact(context.value) : context.value;
  return [context.label, context.series, value].filter((entry) => entry !== undefined && entry !== "").join(" · ");
}

export function useDashboardAsk() {
  return useContext(DashboardAskContext);
}

export function DashboardAskProvider({ canEdit = false, enabled, explorationEnabled = true, dashboardTitle, onStatus, children }) {
  const selectionEnabled = enabled && !isCodexBrowser();
  const [selection, setSelection] = useState(null);
  const [phase, setPhase] = useState("menu");
  const [question, setQuestion] = useState("");
  const [composerHeight, setComposerHeight] = useState(ASK_LAYOUT.composer.minHeight);
  const [composerExpanded, setComposerExpanded] = useState(false);
  const [composerReady, setComposerReady] = useState(false);
  const [isPhoneViewport, setIsPhoneViewport] = useState(() =>
    typeof window !== "undefined" && typeof window.matchMedia === "function"
      && window.matchMedia("(max-width: 599px)").matches);
  const [discardVisible, setDiscardVisible] = useState(false);
  const [closing, setClosing] = useState(false);
  const [entranceKey, setEntranceKey] = useState(0);
  const panelRef = useRef(null);
  const anchorRef = useRef(null);
  const composerRef = useRef(null);
  const submitLinkRef = useRef(null);
  const anchorSourceRef = useRef(null);
  const pinnedChartRef = useRef(null);
  const dismissedChartRef = useRef(null);
  const touchGestureRef = useRef(null);
  const touchPreviewRef = useRef(null);
  const closingTimerRef = useRef(null);
  const enabledRef = useRef(selectionEnabled);
  useEffect(() => {
    const query = window.matchMedia("(max-width: 599px)");
    const sync = () => setIsPhoneViewport(query.matches);
    sync();
    query.addEventListener("change", sync);
    return () => query.removeEventListener("change", sync);
  }, []);
  enabledRef.current = selectionEnabled;
  const exploreRef = useRef(explorationEnabled);
  exploreRef.current = explorationEnabled;
  const canSelect = context => enabledRef.current || (exploreRef.current && context?.actions?.length);

  useEffect(() => {
    let previewFrame = null;
    const down = event => {
      if (event.pointerType === "touch") cancelAnimationFrame(previewFrame);
      if (event.pointerType !== "touch") {
        // Some mobile engines emit compatibility mouse events after a touch.
        // They must not erase the preview before its click is delivered.
        if (touchGestureRef.current && performance.now() - touchGestureRef.current.time < 750) return;
        touchGestureRef.current = null;
        touchPreviewRef.current = null;
        return;
      }
      const root = event.target?.closest?.(chartRootSelector) ?? event.target?.closest?.(".chart-frame");
      if (!root) { touchGestureRef.current = null; touchPreviewRef.current = null; return; }
      touchGestureRef.current = { root, id: event.pointerId, x: event.clientX, y: event.clientY,
        canceled: false, released: false, mode: null, frame: null, time: performance.now() };
    };
    const move = event => {
      const gesture = touchGestureRef.current;
      if (event.pointerType !== "touch" || gesture?.id !== event.pointerId) return;
      if (Math.hypot(event.clientX - gesture.x, event.clientY - gesture.y) > 12) {
        gesture.canceled = true;
        touchPreviewRef.current = null;
      }
      // Recharts' native touch path is excluded; the touchmove listener below
      // distinguishes a horizontal scrub from vertical page scrolling.
      event.stopPropagation();
    };
    const touchMove = event => {
      const gesture = touchGestureRef.current;
      const touch = event.touches[0];
      if (!event.target?.closest?.(".recharts-wrapper, .chart-frame, [data-chart-interaction-root]")) return;
      event.stopPropagation();
      if (!gesture || !touch) return;
      const dx = touch.clientX - gesture.x, dy = touch.clientY - gesture.y;
      if (!gesture.mode && Math.hypot(dx, dy) >= 8) {
        gesture.mode = Math.abs(dx) > Math.abs(dy) * 1.25 ? "scrub" : "scroll";
        gesture.canceled = true;
        touchPreviewRef.current = null;
      }
      if (gesture.mode !== "scrub") return;
      // A horizontal gesture is ours. Never send WebKit's unbounded native
      // touchmove stream into Recharts' tooltip/layout loop; the chart consumes
      // one latest position per animation frame instead.
      event.preventDefault();
      gesture.point = { x: touch.clientX, y: touch.clientY };
      if (gesture.frame == null) gesture.frame = requestAnimationFrame(() => {
        gesture.frame = null;
        if (touchGestureRef.current !== gesture) return;
        gesture.root.dispatchEvent(new CustomEvent("data-chart-scrub", { bubbles: true, detail: gesture.point }));
      });
    };
    const cancel = event => {
      if (touchGestureRef.current?.id === event.pointerId) {
        touchGestureRef.current.canceled = true;
        touchPreviewRef.current = null;
      }
    };
    const up = event => {
      const gesture = touchGestureRef.current;
      if (event.pointerType !== "touch" || gesture?.id !== event.pointerId) return;
      gesture.released = true;
      gesture.time = performance.now();
      const mark = event.target?.closest?.(".recharts-scatter-symbol");
      if (gesture.canceled || !mark) return;
      gesture.mark = mark;
      // Touch targeting can choose a nearby dot in a dense cluster. Preview
      // that actual mark, matching the click payload rather than raw coordinates.
      const bounds = mark.getBoundingClientRect();
      const point = { x: bounds.left + bounds.width / 2, y: bounds.top + bounds.height / 2 };
      previewFrame = requestAnimationFrame(() => {
        previewFrame = null;
        if (touchGestureRef.current !== gesture || gesture.canceled ||
          !mark.isConnected || pinnedChartRef.current === gesture.root) return;
        gesture.root.dispatchEvent(new CustomEvent("data-chart-scrub", { bubbles: true, detail: point }));
        // Recharts hover updates can swallow the compatibility click. Deliver
        // one only when absent, and suppress a native click arriving later.
        if (!gesture.clicked) {
          gesture.replayed = true;
          mark.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true,
            detail: 1, clientX: point.x, clientY: point.y }));
        }
      });
    };
    const click = event => {
      const gesture = touchGestureRef.current;
      if (!gesture?.mark || performance.now() - gesture.time >= 750 ||
        !event.target?.closest?.(".recharts-scatter-symbol") || !gesture.root.contains(event.target)) return;
      if (gesture.replayed && event.isTrusted) {
        event.preventDefault();
        event.stopPropagation();
      } else gesture.clicked = true;
    };
    const endTouch = () => {
      const gesture = touchGestureRef.current;
      if (gesture?.frame != null) cancelAnimationFrame(gesture.frame);
      if (gesture) gesture.frame = null;
    };
    document.addEventListener("pointerdown", down, true);
    document.addEventListener("pointermove", move, true);
    document.addEventListener("touchmove", touchMove, { capture: true, passive: false });
    document.addEventListener("touchend", endTouch, true);
    document.addEventListener("touchcancel", endTouch, true);
    document.addEventListener("pointercancel", cancel, true);
    document.addEventListener("pointerup", up, true);
    document.addEventListener("click", click, true);
    return () => {
      cancelAnimationFrame(previewFrame);
      document.removeEventListener("pointerdown", down, true);
      document.removeEventListener("pointermove", move, true);
      document.removeEventListener("touchmove", touchMove, true);
      document.removeEventListener("touchend", endTouch, true);
      document.removeEventListener("touchcancel", endTouch, true);
      document.removeEventListener("pointercancel", cancel, true);
      document.removeEventListener("pointerup", up, true);
      document.removeEventListener("click", click, true);
    };
  }, []);

  function chartTouchClick(event, root) {
    const gesture = touchGestureRef.current;
    const native = event?.nativeEvent ?? event;
    if (native?.type?.startsWith("key") || native?.pointerType === "pen") return false;
    // A touch-generated click can have detail=0 or pointerType="mouse", and
    // SVG marks can retarget its click within the same chart frame on WebKit.
    // The recent touch and frame are a more reliable source of gesture intent.
    return Boolean(gesture && performance.now() - gesture.time < 750 &&
      (!root || gesture.root === root || gesture.root.closest(".chart-frame") === root.closest(".chart-frame")));
  }

  function clearSelectionIndicator() {
    pinnedChartRef.current?.removeAttribute("data-chart-tooltip-pinned");
    pinnedChartRef.current = null;
    globalThis.CSS?.highlights?.delete("dashboard-ask-selection");
    anchorSourceRef.current?.markElement?.classList.remove("dashboard-ask-selected-mark");
    anchorSourceRef.current?.element?.classList.remove("dashboard-ask-trigger-morphing");
  }

  function completeClose() {
    clearSelectionIndicator();
    window.clearTimeout(closingTimerRef.current);
    setQuestion("");
    setComposerHeight(ASK_LAYOUT.composer.minHeight);
    setComposerExpanded(false);
    setDiscardVisible(false);
    setSelection(null);
    setClosing(false);
  }

  function closeComposer() {
    if (!selection?.headerMorph) {
      completeClose();
      return;
    }
    if (closing) return;
    if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
      completeClose();
      return;
    }
    setClosing(true);
    window.clearTimeout(closingTimerRef.current);
    closingTimerRef.current = window.setTimeout(completeClose, HEADER_UNMORPH_DURATION + 100);
  }

  function closeAfterNavigation() {
    // Keep the trusted anchor mounted through bubbling and native activation.
    window.clearTimeout(closingTimerRef.current);
    closingTimerRef.current = window.setTimeout(completeClose, 0);
  }

  function finishClosing(event) {
    if (!closing || event.target !== event.currentTarget || event.animationName !== "dashboard-ask-header-unmorph") return;
    flushSync(completeClose);
  }

  function shakeComposer() {
    const panel = panelRef.current;
    if (!panel) return;
    setDiscardVisible(true);
    panel.classList.remove("is-shaking");
    void panel.offsetWidth;
    panel.classList.add("is-shaking");
  }

  function showSelectionIndicator(anchorSource) {
    if (anchorSource?.kind === "range" && globalThis.CSS?.highlights && globalThis.Highlight) {
      globalThis.CSS.highlights.set("dashboard-ask-selection", new globalThis.Highlight(anchorSource.range));
    }
    anchorSource?.markElement?.classList.add("dashboard-ask-selected-mark");
  }

  function openSelection(context, anchorSource) {
    if (!canSelect(context)) return;
    touchPreviewRef.current = null;
    const anchor = resolveAnchor(anchorSource);
    if (!anchor) return;
    clearSelectionIndicator();
    anchorSourceRef.current = anchorSource;
    pinnedChartRef.current = context.hoverCard?.rootElement ?? context.hoverCard?.element ?? (anchorSource.selectionType === "point" ? anchorSource.element : null);
    pinnedChartRef.current?.setAttribute("data-chart-tooltip-pinned", "true");
    showSelectionIndicator(anchorSource);
    setEntranceKey((current) => current + 1);
    setSelection({ context, anchor, source: "selection", suggestions: [] });
    setPhase("menu");
    setQuestion("");
    setComposerHeight(ASK_LAYOUT.composer.minHeight);
    setComposerExpanded(false);
    setDiscardVisible(false);
    setClosing(false);
  }

  function openDashboardComposer(anchorElement, suggestions = []) {
    if (!anchorElement?.isConnected) return;
    const bounds = anchorElement.getBoundingClientRect();
    const triggerStyle = window.getComputedStyle(anchorElement);
    const labelBounds = [...anchorElement.querySelectorAll(".dashboard-header-action-label")]
      .map(label => label.getBoundingClientRect()).find(rect => rect.width > 0);
    const iconBounds = anchorElement.querySelector('[data-dashboard-icon="chatBubble"]')?.getBoundingClientRect();
    const triggerBorderWidth = Number.parseFloat(triggerStyle.borderLeftWidth) || 0;
    const headerMorph = anchorElement.classList.contains("dashboard-ask-button");
    const triggerLabel = anchorElement.innerText.trim() || anchorElement.getAttribute("aria-label") || "Ask ChatGPT";
    const anchorSource = {
      kind: "element",
      element: anchorElement,
      xOffset: headerMorph ? bounds.width : undefined,
      yOffset: headerMorph ? bounds.height / 2 : bounds.height,
    };
    const anchor = resolveAnchor(anchorSource);
    if (!anchor) return;
    clearSelectionIndicator();
    anchorSourceRef.current = anchorSource;
    if (headerMorph) anchorElement.classList.add("dashboard-ask-trigger-morphing");
    setEntranceKey((current) => current + 1);
    setSelection({
      context: { kind: "dashboard", label: "Entire dashboard" },
      anchor,
      source: "header",
      headerMorph,
      suggestions,
      triggerWidth: bounds.width,
      triggerRight: bounds.right,
      triggerHeight: bounds.height,
      triggerRadius: triggerStyle.borderRadius,
      triggerBackground: triggerStyle.backgroundColor,
      triggerBorderColor: triggerStyle.borderColor,
      triggerBorderWidth: triggerStyle.borderLeftWidth,
      triggerBoxShadow: triggerStyle.boxShadow,
      triggerColor: triggerStyle.color,
      // The return outline is an inset shadow, so it never shifts these children.
      triggerLabelInset: `${(labelBounds?.left ?? bounds.left + triggerBorderWidth + Number.parseFloat(triggerStyle.paddingLeft)) - bounds.left}px`,
      triggerIconInset: iconBounds ? `${iconBounds.left - bounds.left}px` : null,
      triggerLabel,
    });
    setPhase("compose");
    setComposerHeight(HEADER_COMPOSER_HEIGHT);
    setComposerExpanded(false);
    setDiscardVisible(false);
    setClosing(false);
  }

  function discardComposer() {
    closeComposer();
  }

  function selectChartMark(context, event) {
    if (!canSelect(context)) return;
    const target = event?.target;
    const wrapper = target?.closest?.(chartRootSelector);
    if (wrapper && (pinnedChartRef.current === wrapper || dismissedChartRef.current === wrapper)) return;
    const component = target?.closest?.(".dashboard-component");
    if (chartTouchClick(event, wrapper)) {
      event?.stopPropagation?.();
      const gesture = touchGestureRef.current;
      if (gesture.canceled || !gesture.released) return false;
      const previous = touchPreviewRef.current;
      // The first tap only previews a mark. Keep its identity to small, stable
      // fields; serializing the entire chart row on every tap can be expensive
      // and chart payloads are not guaranteed to be JSON safe.
      const key = [component?.dataset.componentId, context.chartType, context.label,
        context.series, context.value].map(value => String(value ?? "")).join("\u0000");
      const sameMark = previous?.root === wrapper && previous.key === key;
      touchPreviewRef.current = sameMark ? null : { root: wrapper, key };
      if (!sameMark) return false;
    }
    const componentKind = component?.dataset.componentKind;
    const componentTitle = component?.querySelector(".component-title-text")?.textContent?.trim();
    const region = chartRegionSource(target, event, context.chartType);
    if (!region) return;
    // A mark owns this click; the containing frame is a background fallback.
    event?.stopPropagation?.();
    if (event?.detail > 0) target?.closest?.(".recharts-surface")?.blur?.();
    openSelection({ ...context, componentKind, componentTitle }, { ...region, hoverCard: context.hoverCard });
    return true;
  }

  function dismissChartMark(element) {
    if (element && anchorSourceRef.current?.markElement === element) completeClose();
  }

  function selectChartSection(context, event) {
    if (!enabledRef.current) return;
    const target = event?.target;
    if (chartTouchClick(event, target?.closest?.(chartRootSelector) ?? target?.closest?.(".chart-frame"))) return;
    if (pinnedChartRef.current || (dismissedChartRef.current && dismissedChartRef.current === target?.closest?.(".recharts-wrapper"))) return;
    const component = target?.closest?.(".dashboard-component");
    const componentKind = component?.dataset.componentKind;
    const componentTitle = component?.querySelector(".component-title-text")?.textContent?.trim();
    const region = chartSectionSource(target);
    if (!region) return;
    openSelection({ ...context, componentKind, componentTitle }, region);
  }

  useEffect(() => {
    if (selectionEnabled || (explorationEnabled && selection?.context?.actions?.length) || selection?.source !== "selection") return;
    setSelection(null);
  }, [selectionEnabled, explorationEnabled, selection?.source, selection?.context?.actions, selection?.context?.hoverCard]);

  useEffect(() => {
    if (selection) return;
    clearSelectionIndicator();
    setDiscardVisible(false);
    setClosing(false);
  }, [selection]);

  useEffect(
    () => () => {
      window.clearTimeout(closingTimerRef.current);
      clearSelectionIndicator();
    },
    [],
  );

  useEffect(() => {
    if (!selectionEnabled) return undefined;
    function handlePointerUp(event) {
      if (handoffOwnsInteraction(event)) return;
      if (
        event.target?.closest?.(
          ".dashboard-ask-panel, .recharts-wrapper, button, input, textarea, select, [contenteditable='true']",
        )
      )
        return;
      requestAnimationFrame(() => {
        const selected = window.getSelection();
        const text = selected?.toString().replace(/\s+/gu, " ").trim();
        if (!text || text.length < 2 || !selected.rangeCount) {
          setSelection(current => current?.context?.kind === "text" ? null : current);
          return;
        }
        const range = selected.getRangeAt(0);
        const bounds = range.getBoundingClientRect();
        const container =
          range.commonAncestorContainer.nodeType === 1
            ? range.commonAncestorContainer
            : range.commonAncestorContainer.parentElement;
        const component = container?.closest?.(".dashboard-component");
        const componentKind = component?.dataset.componentKind;
        const componentTitle = component?.querySelector(".component-title-text")?.textContent?.trim();
        openSelection(
          { kind: "text", label: text.slice(0, 280), componentKind, componentTitle },
          {
            kind: "range",
            range: range.cloneRange(),
          },
        );
      });
    }
    document.addEventListener("pointerup", handlePointerUp);
    return () => {
      document.removeEventListener("pointerup", handlePointerUp);
    };
  }, [selectionEnabled]);

  useEffect(() => {
    function handleKeyDown(event) {
      if (event.defaultPrevented || handoffOwnsInteraction(event)) return;
      if (event.key === "Escape") {
        const mark = selection ? anchorSourceRef.current?.markElement : null;
        closeComposer();
        if (mark?.hasAttribute("data-chart-mark")) mark.focus({ preventScroll: true });
      }
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [closing, selection?.headerMorph, Boolean(selection)]);

  useEffect(() => {
    const resetDismissedChart = () => { dismissedChartRef.current = null; };
    document.addEventListener("pointerdown", resetDismissedChart, true);
    return () => document.removeEventListener("pointerdown", resetDismissedChart, true);
  }, []);

  useEffect(() => {
    if (phase !== "menu" || (!selection?.context?.actions?.length && !selection?.context?.hoverCard && !pinnedChartRef.current)) return undefined;
    const closeOutside = event => {
      if (handoffOwnsInteraction(event)) return;
      if (event.target?.closest?.(".dashboard-ask-panel")) return;
      if (!pinnedChartRef.current && anchorSourceRef.current?.markElement?.contains?.(event.target)) return;
      if (pinnedChartRef.current?.contains(event.target)) dismissedChartRef.current = pinnedChartRef.current;
      closeComposer();
    };
    document.addEventListener("pointerdown", closeOutside, true);
    return () => document.removeEventListener("pointerdown", closeOutside, true);
  }, [phase, selection?.context]);

  useEffect(() => {
    if (selection?.source !== "header" || question.trim()) return undefined;
    function closeEmptyHeaderComposer(event) {
      if (handoffOwnsInteraction(event)) return;
      if (event.target?.closest?.(".dashboard-ask-panel")) return;
      if (anchorSourceRef.current?.element?.contains?.(event.target)) return;
      closeComposer();
    }
    document.addEventListener("pointerdown", closeEmptyHeaderComposer);
    return () => document.removeEventListener("pointerdown", closeEmptyHeaderComposer);
  }, [closing, selection?.headerMorph, selection?.source, Boolean(question.trim())]);

  useEffect(() => {
    if (closing || !selection || phase !== "compose" || !question.trim()) return undefined;
    function guardFilledComposer(event) {
      if (handoffOwnsInteraction(event)) return;
      if (event.target?.closest?.(".dashboard-ask-panel")) return;
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      if (event.type === "pointerdown") shakeComposer();
    }
    document.addEventListener("pointerdown", guardFilledComposer, true);
    document.addEventListener("pointerup", guardFilledComposer, true);
    document.addEventListener("click", guardFilledComposer, true);
    return () => {
      document.removeEventListener("pointerdown", guardFilledComposer, true);
      document.removeEventListener("pointerup", guardFilledComposer, true);
      document.removeEventListener("click", guardFilledComposer, true);
    };
  }, [closing, enabled, Boolean(selection), phase, Boolean(question.trim())]);

  useEffect(() => {
    if (!selection) return undefined;
    let frame;
    function syncAnchor() {
      window.cancelAnimationFrame(frame);
      frame = window.requestAnimationFrame(() => {
        const anchor = resolveAnchor(anchorSourceRef.current);
        setSelection((current) => (current && anchor ? { ...current, anchor } : null));
      });
    }
    window.addEventListener("resize", syncAnchor);
    document.addEventListener("scroll", syncAnchor, true);
    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener("resize", syncAnchor);
      document.removeEventListener("scroll", syncAnchor, true);
    };
  }, [Boolean(selection)]);

  useEffect(() => {
    if (phase !== "compose") {
      setComposerReady(false);
      return undefined;
    }
    setComposerReady(false);
    const reducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    const delay = reducedMotion || selection?.source === "header" ? 0 : ASK_MOTION.compose.resizeDuration;
    const timer = window.setTimeout(() => {
      setComposerReady(true);
      // On phones, let the person choose when to open the keyboard. Forcing focus
      // while the visual viewport is resizing can hide the composer actions.
      if (!window.matchMedia("(max-width: 599px) and (pointer: coarse)").matches)
        composerRef.current?.focus({ preventScroll: true });
    }, delay);
    return () => window.clearTimeout(timer);
  }, [phase, selection?.source]);

  useEffect(() => {
    if (!selection || phase !== "compose" || !isPhoneViewport) return undefined;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const viewport = window.visualViewport;
    const syncViewport = () => {
      const anchor = anchorRef.current;
      if (!anchor) return;
      anchor.style.setProperty("--mobile-ask-viewport-height", `${viewport?.height ?? window.innerHeight}px`);
      anchor.style.setProperty("--mobile-ask-viewport-top", `${viewport?.offsetTop ?? 0}px`);
    };
    const keepFocus = event => {
      if (event.key !== "Tab") return;
      const controls = [...panelRef.current?.querySelectorAll('button:not([disabled]), a[href], textarea') ?? []]
        .filter(element => !element.closest('[inert]') && element.getClientRects().length);
      if (!controls.length) return;
      const first = controls[0], last = controls.at(-1);
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    };
    syncViewport();
    viewport?.addEventListener("resize", syncViewport);
    viewport?.addEventListener("scroll", syncViewport);
    document.addEventListener("keydown", keepFocus);
    return () => {
      document.body.style.overflow = previousOverflow;
      viewport?.removeEventListener("resize", syncViewport);
      viewport?.removeEventListener("scroll", syncViewport);
      document.removeEventListener("keydown", keepFocus);
    };
  }, [Boolean(selection), phase, isPhoneViewport]);

  useLayoutEffect(() => {
    if (phase !== "compose") return undefined;
    const composer = composerRef.current;
    if (!composer) return undefined;
    const header = selection?.source === "header";
    if (header && question.length === 0) {
      setComposerExpanded(false);
      setComposerHeight(HEADER_COMPOSER_HEIGHT);
      return undefined;
    }
    composer.style.height = "0px";
    const styles = window.getComputedStyle(composer);
    const lineHeight = Number.parseFloat(styles.lineHeight) || 20;
    const paddingTop = Number.parseFloat(styles.paddingTop) || ASK_LAYOUT.composer.padding.top;
    const maximumTextHeight = Math.ceil(paddingTop + lineHeight * COMPOSER_MAX_LINES);
    const naturalTextHeight = composer.scrollHeight;
    const textHeight = Math.min(naturalTextHeight, maximumTextHeight);
    const expanded = header || naturalTextHeight > Math.ceil(paddingTop + lineHeight);
    composer.style.height = "100%";
    composer.style.overflowY = naturalTextHeight > maximumTextHeight ? "auto" : "hidden";
    setComposerExpanded(expanded);
    setComposerHeight(
      Math.max(
        header ? HEADER_COMPOSER_ACTIVE_HEIGHT : ASK_LAYOUT.composer.minHeight,
        Math.ceil(
          Math.max(textHeight, header ? 0 : paddingTop + 28) +
            (header ? 2 : ASK_LAYOUT.composer.footerGap) +
            ASK_LAYOUT.composer.footerHeight +
            (header ? 6 : ASK_LAYOUT.composer.padding.bottom),
        ),
      ),
    );
    return undefined;
  }, [phase, question, composerExpanded, selection?.source]);

  function promptForChatGPT(dataAppReference, viewUrl) {
    if (!selection || !question.trim()) return null;
    const { sourceUrl, projectId, htmlPath, root } = dataAppReference;
    return dashboardAskPrompt({
      question,
      dashboardTitle,
      dashboardUrl: viewUrl ?? (htmlPath ? undefined : sourceUrl),
      dashboardProjectId: projectId,
      dashboardProjectRoot: htmlPath ? root : undefined,
      componentKind: selection.context.componentKind,
      componentTitle: selection.context.componentTitle,
      selectedContext: contextLabel(selection.context),
      selectedContextLabel: selection.context.row ? "Selected point" : "Selected context",
    });
  }

  const contextValue = useMemo(
    () => ({ openDashboardComposer, selectChartMark, selectChartSection, selectionEnabled, canSelectChartMark: canSelect, dismissChartMark,
      selectedMarkElement: selection ? anchorSourceRef.current?.markElement : null,
      pinnedChartElement: selection ? pinnedChartRef.current : null }),
    [selectionEnabled, dashboardTitle, selection, explorationEnabled],
  );
  const minimumComposerHeight = selection?.source === "header"
    ? question.trim()
      ? HEADER_COMPOSER_ACTIVE_HEIGHT
      : HEADER_COMPOSER_HEIGHT
    : ASK_LAYOUT.composer.minHeight;
  const activeComposerHeight = Math.max(minimumComposerHeight, composerHeight);
  const viewportHeight = globalThis.window?.innerHeight ?? activeComposerHeight + ASK_LAYOUT.viewportPadding * 2;
  const visibleComposerHeight = Math.min(
    activeComposerHeight,
    Math.max(0, viewportHeight - ASK_LAYOUT.viewportPadding * 2),
  );
  const headerMorph = selection?.source === "header" && selection.headerMorph;
  const anchorGap = selection?.source === "header" ? HEADER_ANCHOR_GAP : ASK_MOTION.entrance.endGap;
  const markActions = explorationEnabled ? (selection?.context?.actions ?? []).slice(0, 3) : [];
  const markMenuHeight = 8 + (markActions[0]?.context ? 28 : 0) + 32 * (markActions.length + (selectionEnabled ? 1 : 0));
  const actionPosition = selection
    ? headerMorph
      ? { left: selection.anchor.x, top: selection.anchor.y, placement: "below" }
      : panelPosition(selection.anchor, markActions.length && phase === "menu" ? "actions" : "menu", anchorGap, visibleComposerHeight, markActions.length && phase === "menu" ? markMenuHeight : undefined)
    : null;
  const position = actionPosition;
  const viewportCorrection =
    phase === "compose"
      ? composerViewportCorrection(
          position,
          visibleComposerHeight,
          selection?.source,
          headerMorph,
          selection?.triggerRight,
        )
      : { x: 0, y: 0 };
  const stageMotion = ASK_MOTION.compose;
  const dataAppReference = currentDataAppReference();
  const viewUrl = currentDataAppViewUrl() ?? undefined;
  const chatGPTPrompt = promptForChatGPT(dataAppReference, viewUrl);
  const chatGPTLink = dataAppPromptLinkProps(destination => chatGPTPrompt
    ? codexDataAppPromptUrl(chatGPTPrompt, dataAppReference, undefined, undefined, destination, viewUrl).toString()
    : undefined, () => {
      onStatus?.("Opening in ChatGPT.");
      closeAfterNavigation();
    });
  const motionStyle = {
    "--dashboard-ask-anchor-gap": `${anchorGap}px`,
    "--dashboard-ask-enter-offset": `${ASK_MOTION.entrance.endGap - ASK_MOTION.entrance.startGap}px`,
    "--dashboard-ask-enter-scale": ASK_MOTION.entrance.startScale,
    "--dashboard-ask-enter-shadow-y": `${ASK_MOTION.entrance.shadowY}px`,
    "--dashboard-ask-enter-shadow-blur": `${ASK_MOTION.entrance.shadowBlur}px`,
    "--dashboard-ask-shadow-y": `${ASK_MOTION.entrance.shadowY}px`,
    "--dashboard-ask-shadow-blur": `${ASK_MOTION.entrance.shadowBlur}px`,
    "--dashboard-ask-enter-duration": `${ASK_MOTION.entrance.duration}ms`,
    "--dashboard-ask-enter-ease": ASK_MOTION.entrance.easing,
    "--dashboard-ask-compose-y": `${selection?.source === "header" ? viewportCorrection.y : ASK_LAYOUT.composer.translateY + viewportCorrection.y}px`,
    "--dashboard-ask-compose-width": `${selection?.source === "header" ? HEADER_COMPOSER_WIDTH : ASK_LAYOUT.composer.width}px`,
    "--dashboard-ask-compose-height": `${visibleComposerHeight}px`,
    "--dashboard-ask-compose-radius": `${ASK_LAYOUT.composer.radius}px`,
    "--dashboard-ask-compose-padding-top": `${ASK_LAYOUT.composer.padding.top}px`,
    "--dashboard-ask-compose-padding-right": `${ASK_LAYOUT.composer.padding.right}px`,
    "--dashboard-ask-compose-padding-bottom": `${ASK_LAYOUT.composer.padding.bottom}px`,
    "--dashboard-ask-compose-padding-left": `${ASK_LAYOUT.composer.padding.left}px`,
    "--dashboard-ask-compose-offset-x": `${ASK_LAYOUT.composer.offsetX - viewportCorrection.x}px`,
    "--dashboard-ask-header-correction-x": `${viewportCorrection.x}px`,
    "--dashboard-ask-header-correction-y": `${viewportCorrection.y}px`,
    "--dashboard-ask-trigger-width": `${selection?.triggerWidth ?? ASK_LAYOUT.menu.width}px`,
    "--dashboard-ask-trigger-height": `${selection?.triggerHeight ?? HEADER_COMPOSER_HEIGHT}px`,
    "--dashboard-ask-trigger-radius": selection?.triggerRadius ?? `${ASK_LAYOUT.composer.radius}px`,
    "--dashboard-ask-trigger-background": selection?.triggerBackground ?? "transparent",
    "--dashboard-ask-trigger-border-color": selection?.triggerBorderColor ?? "transparent",
    "--dashboard-ask-trigger-border-width": selection?.triggerBorderWidth ?? "0px",
    "--dashboard-ask-trigger-box-shadow": selection?.triggerBoxShadow ?? "none",
    "--dashboard-ask-trigger-color": selection?.triggerColor ?? "currentColor",
    "--dashboard-ask-trigger-label-inset": selection?.triggerLabelInset ?? "12px",
    "--dashboard-ask-trigger-icon-inset": selection?.triggerIconInset ?? "12px",
    "--dashboard-ask-header-morph-duration": `${HEADER_MORPH_DURATION}ms`,
    "--dashboard-ask-header-unmorph-duration": `${HEADER_UNMORPH_DURATION}ms`,
    "--dashboard-ask-transition-ease": stageMotion.easing,
    "--dashboard-ask-resize-duration": `${stageMotion.resizeDuration}ms`,
    "--dashboard-ask-fade-duration": `${stageMotion.fadeDuration}ms`,
    "--dashboard-ask-content-duration": `${stageMotion.contentDuration}ms`,
    "--dashboard-ask-content-slide": `${stageMotion.contentSlide}px`,
    "--dashboard-ask-content-blur": `${stageMotion.contentBlur}px`,
    "--dashboard-ask-content-scale": stageMotion.contentScale,
  };
  const zeroStateVisible = phase === "compose" && Boolean(selection?.suggestions?.length)
    && (!question.length || isPhoneViewport);
  const hasQuestion = Boolean(question.trim());
  const sharedPromptLabel = closing && headerMorph
    ? selection.triggerLabel ?? "Ask ChatGPT"
    : "Ask ChatGPT";
  const hoverCard = selection?.context?.hoverCard;
  const pinned = hoverCard && phase === "menu";
  const pinnedPosition = pinned ? pinnedChartCardPosition(selection.anchor, hoverCard, { width: window.innerWidth, height: window.innerHeight }) : null;
  const panel = pinned ? <div className="dashboard-ask-anchor chart-pinned-anchor" style={{
    left: pinnedPosition.left, top: pinnedPosition.top,
    "--pinned-available-height": `${pinnedPosition.maxHeight}px`,
  }}><PinnedChartCard {...{ hoverCard, panelRef }} actions={markActions} canAsk={selectionEnabled} onAsk={() => setPhase("compose")} onClose={closeComposer} /></div> : selection && position && (
    <div
      ref={anchorRef}
      className="dashboard-ask-anchor"
      data-phase={phase}
      data-source={selection.source}
      data-header-morph={headerMorph || undefined}
      data-closing={closing || undefined}
      data-composer-expanded={composerExpanded || undefined}
      style={{ left: position.left, top: position.top, ...motionStyle }}
    >
      {phase === "compose" && <button type="button" className="dashboard-ask-mobile-scrim"
        aria-label="Close Ask ChatGPT" onClick={closeComposer} />}
      <div
        key={entranceKey}
        ref={panelRef}
        className="dashboard-ask-panel"
        data-exploration={markActions.length && phase === "menu" ? true : undefined}
        data-phase={phase}
        data-source={selection.source}
        data-header-morph={headerMorph || undefined}
        data-closing={closing || undefined}
        data-has-question={hasQuestion || undefined}
        data-composer-ready={composerReady || undefined}
        data-placement={position.placement}
        role="dialog"
        aria-modal={phase === "compose" && isPhoneViewport || undefined}
        aria-label={phase === "menu" ? "Selection actions" : "Ask ChatGPT about this dashboard"}
        onAnimationEnd={finishClosing}
      >
        {phase === "compose" && <header className="dashboard-ask-mobile-heading">
          <span>Ask ChatGPT</span>
          <button type="button" aria-label="Close Ask ChatGPT" onClick={closeComposer}><Icon name="cross" size={20} /></button>
        </header>}
        {closing && headerMorph && selection.triggerIconInset && <span className="dashboard-ask-return-icon" aria-hidden="true">
          <DashboardAskIcon name="chatBubble" size={18} />
        </span>}
        {(!markActions.length || phase === "compose") && (phase === "menu" || (phase === "compose" && (!question || closing))) && (
          <span className="dashboard-ask-shared-prompt" aria-hidden="true">
            {sharedPromptLabel}
          </span>
        )}
        <div
          className={`dashboard-ask-view dashboard-ask-menu${phase === "menu" ? " is-active" : ""}`}
          aria-hidden={phase !== "menu"}
          inert={phase !== "menu"}
        >
          {markActions[0]?.context && <span className="dashboard-exploration-context">{markActions[0].context}</span>}
          {markActions.map((action, index) => <button type="button" key={action.label} autoFocus={index === 0}
            onClick={() => { closeComposer(); action.onSelect(); }}><span>{action.label}</span><Icon name="arrowUpRight" size={14} /></button>)}
          {(selectionEnabled || !markActions.length) && <button type="button" onClick={() => setPhase("compose")}>
            <span className={markActions.length ? undefined : "dashboard-ask-menu-prompt"}>Ask ChatGPT</span>
          </button>}
        </div>
        <form
          className={`dashboard-ask-view dashboard-ask-compose${phase === "compose" ? " is-active" : ""}${zeroStateVisible ? " has-zero-state" : ""}`}
          data-source={selection.source}
          aria-hidden={phase !== "compose"}
          inert={phase !== "compose"}
          onSubmit={(event) => {
            event.preventDefault();
            submitLinkRef.current?.click();
          }}
        >
          <textarea
            ref={composerRef}
            value={question}
            rows={selection.source === "header" ? 2 : 1}
            onChange={(event) => {
              setQuestion(event.target.value);
              if (!event.target.value.trim()) setDiscardVisible(false);
            }}
            onKeyDown={(event) => {
              if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
                if (!event.currentTarget.value.trim()) return;
                event.preventDefault();
                event.currentTarget.form?.requestSubmit();
              }
            }}
            placeholder={selection.source === "header" && canEdit ? "Ask a question or request a change…" : "Ask ChatGPT"}
            aria-label="Question for ChatGPT"
          />
          {zeroStateVisible && (
            <div className="dashboard-ask-zero-state" role="group" aria-label="Suggested actions">
              <h3 className="dashboard-ask-zero-state-heading">Suggestions</h3>
              {selection.suggestions.map(({ action, href, getHandoffHref, icon, label, onSelect, subtext }) => {
                const content = (
                  <>
                    <DashboardAskIcon name={icon} />
                    <span className="dashboard-ask-zero-state-copy">
                      <span>{label}</span>
                      {subtext && <small>{subtext}</small>}
                    </span>
                  </>
                );
                return href ? (
                  <a
                    key={action}
                    className={subtext ? "has-subtext" : undefined}
                    {...dataAppPromptLinkProps(getHandoffHref ?? (() => href), closeAfterNavigation)}
                  >
                    {content}
                  </a>
                ) : (
                  <button
                    key={action}
                    className={subtext ? "has-subtext" : undefined}
                    type="button"
                    onClick={() => {
                      flushSync(completeClose);
                      onSelect?.();
                    }}
                  >
                    {content}
                  </button>
                );
              })}
            </div>
          )}
          <footer>
            {discardVisible && (
              <button
                type="button"
                className="dashboard-ask-discard"
                onClick={discardComposer}
                aria-label="Discard question"
                title="Discard question"
              >
                <Icon name="trash" size={16} />
              </button>
            )}
            <a
              ref={submitLinkRef}
              className="dashboard-ask-submit"
              {...chatGPTLink}
              aria-disabled={!chatGPTLink.href}
              aria-label="Send to ChatGPT"
            >
              {question.trim() && <span className="dashboard-ask-submit-label">Send to ChatGPT</span>}
              <span className="dashboard-ask-primary" aria-hidden="true">
                <Icon name="sendUp" size={isPhoneViewport ? 20 : 16} />
              </span>
            </a>
          </footer>
        </form>
      </div>
    </div>
  );
  const regionSource =
    (selectionEnabled || hoverCard) && selection?.source === "selection" && anchorSourceRef.current?.kind === "region" && anchorSourceRef.current.element?.isConnected
      ? anchorSourceRef.current
      : null;
  const selectedRegion = regionSource && regionSource.renderOverlay !== false && <SelectedChartRegion region={regionSource} />;
  return (
    <DashboardAskContext.Provider value={contextValue}>
      {children}
      {typeof document !== "undefined" && selectedRegion ? createPortal(selectedRegion, regionSource.element) : null}
      {typeof document !== "undefined" && panel ? createPortal(panel, document.body) : null}
    </DashboardAskContext.Provider>
  );
}
