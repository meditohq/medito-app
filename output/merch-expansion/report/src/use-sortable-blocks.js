import { startTransition, useCallback, useEffect, useRef, useState } from "react";

import { directionalBlockTilt, moveBlockBefore, resolveBlockInsertion } from "./block-layout.js";

export const blockDragActivationDistance = 6;

export function keyboardBlockTarget(order, activeId, key, lockedIds = []) {
  const index = order.indexOf(activeId);
  if (index < 0) return null;
  const locked = new Set(lockedIds);
  let target = index;
  if (key === "Home") {
    while (target > 0 && !locked.has(order[target - 1])) target -= 1;
  } else if (key === "End") {
    while (target < order.length - 1 && !locked.has(order[target + 1])) target += 1;
  } else {
    target = Math.max(0, Math.min(order.length - 1,
      index + (["ArrowDown", "ArrowRight"].includes(key) ? 1 : -1)));
  }
  return target === index || locked.has(order[target]) ? null : { index: target, id: order[target] };
}

function sameOrder(left, right) {
  return left.length === right.length && left.every((id, index) => id === right[index]);
}

function motionMilliseconds(element, token, fallback) {
  const value = globalThis.getComputedStyle?.(element)?.getPropertyValue(token).trim();
  const duration = Number.parseFloat(value);
  return Number.isFinite(duration) ? duration * (value.endsWith("ms") ? 1 : value.endsWith("s") ? 1000 : 1)
    : fallback;
}

function fixedDragRects(items, scrollX, scrollY) {
  const offsetX = (globalThis.scrollX ?? 0) - scrollX;
  const offsetY = (globalThis.scrollY ?? 0) - scrollY;
  return items.map(({ id, rect }) => ({
    id,
    rect: {
      left: rect.left - offsetX,
      right: rect.right - offsetX,
      top: rect.top - offsetY,
      bottom: rect.bottom - offsetY,
      width: rect.width,
      height: rect.height,
    },
  }));
}

function motionConfiguration(element) {
  const styles = globalThis.getComputedStyle?.(element);
  const number = (token, fallback) => {
    const value = Number.parseFloat(styles?.getPropertyValue(token));
    return Number.isFinite(value) ? value : fallback;
  };
  const milliseconds = (token, fallback) => {
    const value = styles?.getPropertyValue(token).trim() ?? "";
    const duration = Number.parseFloat(value);
    return Number.isFinite(duration)
      ? duration * (value.endsWith("ms") ? 1 : value.endsWith("s") ? 1000 : 1) : fallback;
  };
  return {
    activationDistance: number("--block-drag-activation-distance", blockDragActivationDistance),
    smoothing: number("--block-drag-velocity-smoothing", .18),
    maxTilt: number("--block-drag-max-tilt", 1.5),
    deadZone: number("--block-drag-direction-dead-zone", .04),
    hysteresis: number("--block-drag-insertion-hysteresis", 10),
    rowZone: number("--block-layout-row-insertion-zone", 40),
    rowAttraction: number("--block-layout-row-attraction", 8),
    autoResize: number("--block-layout-auto-resize", 1) > 0,
    maxItems: Math.max(1, Math.round(number("--block-layout-max-row-items", 6))),
    minimumSpans: {
      metric: Math.max(1, Math.round(number("--block-layout-min-metric-span", 2))),
      chart: Math.max(1, Math.round(number("--block-layout-min-chart-span", 3))),
      custom: Math.max(1, Math.round(number("--block-layout-min-custom-span", 3))),
      table: Math.max(1, Math.round(number("--block-layout-min-table-span", 3))),
      block: Math.max(1, Math.round(number("--block-layout-min-block-span", 3))),
    },
    rowHoverDelay: milliseconds("--block-layout-row-hover-delay", 450),
    touchRowHoverDelay: milliseconds("--block-layout-touch-row-hover-delay", 650),
    scrollEdge: number("--block-drag-scroll-edge", 56),
    scrollSpeed: number("--block-drag-scroll-speed", 18),
    reducedMotion: Boolean(globalThis.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches),
  };
}

function captureSpatialGrid(region, references, itemRefs) {
  if (!region || !references?.length || references.length > 60 || typeof getComputedStyle !== "function") return null;
  const styles = getComputedStyle(region);
  if (!styles.display.includes("grid") || styles.gridAutoFlow.includes("dense")) return null;
  const tracks = [...styles.gridTemplateColumns.matchAll(/(?:^|\s)([\d.]+)px(?=\s|$)/g)]
    .map(([, value]) => Number(value));
  if (tracks.length < 2 || tracks.some((track) => Math.abs(track - tracks[0]) > 1)) return null;
  const columnGap = Number.parseFloat(styles.columnGap) || 0;
  const rowGap = Number.parseFloat(styles.rowGap) || 0;
  const footprints = {};
  for (const { id, rect } of references) {
    const element = itemRefs.current.get(id);
    const itemStyles = element && getComputedStyle(element);
    if (!itemStyles) return null;
    for (const value of [itemStyles.gridColumnStart, itemStyles.gridRowStart]) {
      if (value && value !== "auto" && !/^span\s+\d+$/.test(value)) return null;
    }
    const columnSpan = /^span\s+(\d+)$/.exec(itemStyles.gridColumnStart)?.[1]
      ?? /^span\s+(\d+)$/.exec(itemStyles.gridColumnEnd)?.[1];
    const rowSpan = /^span\s+(\d+)$/.exec(itemStyles.gridRowStart)?.[1]
      ?? /^span\s+(\d+)$/.exec(itemStyles.gridRowEnd)?.[1];
    footprints[id] = {
      columns: Math.max(1, Math.min(tracks.length, Number(columnSpan)
        || Math.round((rect.width + columnGap) / (tracks[0] + columnGap)))),
      rows: Math.max(1, Number(rowSpan) || 1),
    };
  }
  const firstTop = Math.min(...references.map(({ rect }) => rect.top));
  const singleRows = references.filter(({ id }) => footprints[id].rows === 1)
    .map(({ rect }) => rect.height);
  const heights = references.map(({ id, rect }) =>
    (rect.height - rowGap * (footprints[id].rows - 1)) / footprints[id].rows);
  const rowHeight = Math.min(...(singleRows.length ? singleRows : heights));
  if (!Number.isFinite(rowHeight) || rowHeight <= 0) return null;
  const bounds = region.getBoundingClientRect();
  return {
    columns: tracks.length,
    left: bounds.left + (Number.parseFloat(styles.paddingLeft) || 0),
    top: firstTop,
    columnWidth: tracks[0],
    columnGap,
    rowHeight,
    rowGap,
    footprints,
  };
}

export function useSortableBlocks({
  enabled,
  regionId,
  variant,
  itemIds,
  itemRefs,
  labels,
  lockedIds,
  layout,
  resolvePlacement,
  resolveExternalPlacement,
  clearExternalPlacement,
  resolveKeyboard,
  onCommit,
  onTransfer,
  onBeforeReorder,
}) {
  const [active, setActive] = useState(null);
  const [settling, setSettling] = useState(null);
  const [previewOrder, setPreviewOrder] = useState(null);
  const [previewLayout, setPreviewLayout] = useState(null);
  const [dropTarget, setDropTarget] = useState(null);
  const [rowCandidate, setRowCandidate] = useState(null);
  const [announcement, setAnnouncement] = useState("");
  const gesture = useRef(null);
  const pendingFrame = useRef(0);
  const scrollFrame = useRef(0);
  const rowHoverTimer = useRef(0);
  const settleTimer = useRef(0);
  const touchHold = useRef(null);
  const currentOrder = useRef(itemIds);
  const currentLayout = useRef(layout);
  const configuration = useRef({
    enabled, regionId, variant, labels, lockedIds, layout, resolvePlacement, resolveExternalPlacement,
    clearExternalPlacement, resolveKeyboard, onCommit, onTransfer, onBeforeReorder,
  });
  const handlers = useRef({ move: null, finish: null, cancel: null, keydown: null, lostCapture: null });
  currentOrder.current = previewOrder ?? itemIds;
  currentLayout.current = previewLayout ?? layout;
  configuration.current = {
    enabled, regionId, variant, labels, lockedIds, layout, resolvePlacement, resolveExternalPlacement,
    clearExternalPlacement, resolveKeyboard, onCommit, onTransfer, onBeforeReorder,
  };

  const stopListeners = useCallback(() => {
    if (typeof window === "undefined") return;
    window.removeEventListener("pointermove", handlers.current.move);
    window.removeEventListener("pointerup", handlers.current.finish);
    window.removeEventListener("pointercancel", handlers.current.cancel);
    window.removeEventListener("keydown", handlers.current.keydown);
    gesture.current?.pointerTarget?.removeEventListener("lostpointercapture", handlers.current.lostCapture);
    if (pendingFrame.current) window.cancelAnimationFrame(pendingFrame.current);
    if (scrollFrame.current) window.cancelAnimationFrame(scrollFrame.current);
    if (rowHoverTimer.current) window.clearTimeout(rowHoverTimer.current);
    pendingFrame.current = 0;
    scrollFrame.current = 0;
    rowHoverTimer.current = 0;
  }, []);

  const stopTouchHold = useCallback(() => {
    const hold = touchHold.current;
    if (!hold) return;
    window.clearTimeout(hold.timer);
    window.removeEventListener("touchmove", hold.move);
    window.removeEventListener("touchend", hold.end);
    window.removeEventListener("touchcancel", hold.cancel);
    touchHold.current = null;
  }, []);

  const announce = useCallback((id, order, action) => {
    const label = configuration.current.labels.get(id) ?? id;
    const position = order.indexOf(id) + 1;
    setAnnouncement(`${action} ${label}. Position ${position} of ${order.length}.`);
  }, []);

  const restoreFocus = useCallback((id) => {
    globalThis.requestAnimationFrame?.(() => {
      itemRefs.current.get(id)?.querySelector("[data-block-drag-handle]")?.focus({ preventScroll: true });
    });
  }, [itemRefs]);

  const finish = useCallback((commit, event) => {
    const current = gesture.current;
    if (!current || event?.pointerId !== undefined && current.pointerId !== event.pointerId) return;
    stopListeners();
    if (current.pointerTarget?.hasPointerCapture?.(current.pointerId)) {
      current.pointerTarget.releasePointerCapture(current.pointerId);
    }
    const nextOrder = currentOrder.current;
    const nextLayout = currentLayout.current;
    const changed = current.started && (!sameOrder(current.originalOrder, nextOrder)
      || current.originalLayout && JSON.stringify(current.originalLayout) !== JSON.stringify(nextLayout));
    const transferred = Boolean(commit && current.started && current.externalTarget
      && configuration.current.enabled && configuration.current.onTransfer?.({
      activeId: current.id,
      sourceOrder: nextOrder,
      ...current.externalTarget,
    }));
    configuration.current.clearExternalPlacement?.();
    setDropTarget(null);
    setRowCandidate(null);

    const committed = transferred || commit && changed && configuration.current.enabled;
    if (transferred) {
      setPreviewOrder(null);
      setPreviewLayout(null);
      announce(current.id, nextOrder, "Moved");
    } else if (committed) {
      startTransition(() => {
        configuration.current.onCommit(nextLayout && current.originalLayout ? nextLayout : nextOrder);
        setPreviewOrder(null);
        setPreviewLayout(null);
      });
      announce(current.id, nextOrder, "Moved");
    } else if (current.started) {
      announce(current.id, current.originalOrder, "Canceled move for");
    }

    const source = current.started && !current.keyboard && commit ? itemRefs.current.get(current.id) : null;
    const reducedMotion = source && globalThis.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
    const duration = source && !reducedMotion
      ? Math.min(450, Math.max(0, motionMilliseconds(source, "--block-drag-drop-duration", 220))) : 0;
    if (settleTimer.current) window.clearTimeout(settleTimer.current);
    settleTimer.current = 0;
    if (source && duration > 0) {
      const destination = source.getBoundingClientRect();
      const left = current.previewLeft;
      const top = current.previewTop;
      setSettling({
        id: current.id,
        source: current.preview,
        left,
        top,
        width: current.width,
        height: current.height,
        settling: true,
        settleX: destination.left - left + (destination.width - current.width) / 2,
        settleY: destination.top - top + (destination.height - current.height) / 2,
        settleScaleX: destination.width / Math.max(1, current.width),
        settleScaleY: destination.height / Math.max(1, current.height),
        settleDuration: duration,
        tilt: 0,
        keyboard: false,
      });
      settleTimer.current = window.setTimeout(() => {
        settleTimer.current = 0;
        setSettling(null);
      }, duration + 16);
    } else setSettling(null);
    gesture.current = null;
    setActive(null);
    if (!committed) {
      setPreviewOrder(null);
      setPreviewLayout(null);
    }
    if (current.keyboard) restoreFocus(current.id);
  }, [announce, itemRefs, restoreFocus, stopListeners]);

  const processPointer = useCallback((event, confirmedNewRow = false) => {
    const current = gesture.current;
    const config = configuration.current;
    if (!current || !config.enabled || event.pointerId !== current.pointerId) return;
    const source = itemRefs.current.get(current.id);
    if (!source) {
      finish(false, event);
      return;
    }
    const distance = Math.hypot(event.clientX - current.startX, event.clientY - current.startY);
    const threshold = current.motion.activationDistance;
    if (!current.started && distance < threshold) return;
    if (!current.started) {
      current.started = true;
      current.source = source;
      current.preview = source.cloneNode(true);
      current.previewLeft = event.clientX - current.offsetX;
      current.previewTop = event.clientY - current.offsetY;
      setActive({
        id: current.id,
        source: current.preview,
        left: current.previewLeft,
        top: current.previewTop,
        width: current.width,
        height: current.height,
        tilt: 0,
        keyboard: false,
      });
      announce(current.id, current.originalOrder, "Picked up");
    }
    const now = event.timeStamp || performance.now();
    const tilt = directionalBlockTilt(current.tilt, event.clientX,
      Math.max(1, now - current.lastTime), {
        smoothing: current.motion.smoothing,
        maxDegrees: current.motion.maxTilt,
        deadZone: current.motion.deadZone,
      });
    const deltaX = event.clientX - (current.lastPointerX ?? current.startX);
    const deltaY = event.clientY - (current.lastPointerY ?? current.startY);
    if (Math.abs(deltaX) > .5) current.directionX = Math.sign(deltaX);
    if (Math.abs(deltaY) > .5) current.directionY = Math.sign(deltaY);
    current.lastPointerX = event.clientX;
    current.lastPointerY = event.clientY;
    const dragRect = {
      left: event.clientX - current.offsetX,
      top: event.clientY - current.offsetY,
      right: event.clientX - current.offsetX + current.width,
      bottom: event.clientY - current.offsetY + current.height,
      width: current.width,
      height: current.height,
    };
    current.tilt = tilt;
    current.lastTime = now;
    current.lastEvent = event;
    const preview = current.previewElement?.isConnected ? current.previewElement
      : document.querySelector(".block-drag-preview:not(.is-settling)");
    if (preview) {
      current.previewElement = preview;
      preview.style.setProperty("--block-drag-offset-x", `${dragRect.left - current.previewLeft}px`);
      preview.style.setProperty("--block-drag-offset-y", `${dragRect.top - current.previewTop}px`);
      const degrees = current.motion.reducedMotion ? 0 : tilt.degrees;
      preview.style.setProperty("--block-drag-current-tilt", `${degrees}deg`);
      preview.dataset.dragDirection = degrees < -.05 ? "-1" : degrees > .05 ? "1" : "0";
    }

    const measurementKey = `${currentOrder.current.join("|")}:`
      + `${JSON.stringify(currentLayout.current?.rows ?? [])}:`
      + `${JSON.stringify(currentLayout.current?.spans ?? {})}:`
      + `${globalThis.scrollX ?? 0}:${globalThis.scrollY ?? 0}`;
    if (current.measurementKey !== measurementKey) {
      current.measuredItems = config.variant === "freeform" && current.referenceItems
        ? fixedDragRects(current.referenceItems, current.referenceScrollX, current.referenceScrollY)
        : [...itemRefs.current].map(([id, element]) => ({
          id,
          rect: element.getBoundingClientRect(),
        }));
      current.measurementKey = measurementKey;
    }
    const measured = current.measuredItems;
    const scrollOffsetX = (globalThis.scrollX ?? 0) - current.referenceScrollX;
    const scrollOffsetY = (globalThis.scrollY ?? 0) - current.referenceScrollY;
    const options = {
      order: currentOrder.current,
      items: measured,
      activeId: current.id,
      pointer: { x: event.clientX, y: event.clientY },
      dragRect,
      dragDirection: { x: current.directionX ?? 0, y: current.directionY ?? 0 },
      variant: config.variant,
      spatialGrid: current.spatialGrid && { ...current.spatialGrid,
        left: current.spatialGrid.left - scrollOffsetX, top: current.spatialGrid.top - scrollOffsetY },
      lockedIds: config.lockedIds,
      hysteresis: current.motion.hysteresis,
      previousBeforeId: current.previousBeforeId,
      layout: currentLayout.current,
      policy: {
        rowZone: current.motion.rowZone,
        rowAttraction: current.motion.rowAttraction,
        stickyGap: current.pendingRow?.key,
        confirmedGap: confirmedNewRow ? current.pendingRow : undefined,
        allowNewRow: confirmedNewRow,
        autoResize: current.motion.autoResize,
        maxItems: current.motion.maxItems,
        minimumSpans: current.motion.minimumSpans,
      },
    };
    const external = config.resolveExternalPlacement?.({
      activeId: current.id,
      pointer: options.pointer,
      dragRect,
    });
    current.externalTarget = external ?? undefined;
    const phoneStack = event.pointerType === "touch" && config.resolveKeyboard && currentLayout.current?.rows
      && window.matchMedia("(max-width: 599px)").matches;
    // A collapsed canvas is a vertical list on a phone. Resolve the visible
    // insertion first, then use the existing canvas move to retain row metadata.
    const insertion = phoneStack ? resolveBlockInsertion({ ...options, variant: "stack", dragRect: undefined }) : null;
    const target = external ? null : phoneStack
      ? insertion && config.resolveKeyboard?.({ layout: currentLayout.current, activeId: current.id,
        targetId: insertion.targetId, placement: insertion.placement,
        key: insertion.placement === "after" ? "ArrowDown" : "ArrowUp" })
      : config.resolvePlacement ? config.resolvePlacement(options) : resolveBlockInsertion(options);
    if (target?.pending) {
      const previous = current.pendingRow;
      const moved = previous
        ? Math.hypot(event.clientX - previous.x, event.clientY - previous.y) : 0;
      if (previous?.key !== target.key) setRowCandidate(target);
      if (!previous || previous.key !== target.key || moved > Math.max(12, options.policy.rowZone * .8)) {
        if (rowHoverTimer.current) window.clearTimeout(rowHoverTimer.current);
        current.pendingRow = { ...target, x: event.clientX, y: event.clientY };
        const delay = event.pointerType === "touch"
          ? current.motion.touchRowHoverDelay : current.motion.rowHoverDelay;
        rowHoverTimer.current = window.setTimeout(() => {
          const next = gesture.current;
          rowHoverTimer.current = 0;
          if (!next?.started || next.pendingRow?.key !== target.key || !next.lastEvent) return;
          processPointer(next.lastEvent, true);
        }, Math.max(0, delay));
      }
    } else {
      if (rowHoverTimer.current) window.clearTimeout(rowHoverTimer.current);
      rowHoverTimer.current = 0;
      current.pendingRow = undefined;
      if (current.hadRowCandidate) setRowCandidate(null);
      current.hadRowCandidate = false;
    }
    if (target?.pending) current.hadRowCandidate = true;
    if (target && !target.pending) {
      config.onBeforeReorder();
      current.previousBeforeId = target.beforeId;
      currentOrder.current = target.order;
      setPreviewOrder(target.order);
      setDropTarget({ id: target.targetId, placement: target.placement, rowId: target.rowId });
      if (target.rows) {
        const nextLayout = { order: target.order, rows: target.rows, spans: target.spans,
          preferredSpans: target.preferredSpans, soloSpans: target.soloSpans,
          retainedRowIds: target.retainedRowIds };
        currentLayout.current = nextLayout;
        setPreviewLayout(nextLayout);
      }
      announce(current.id, target.order, "Moving");
    }

    const edge = current.motion.scrollEdge;
    const maximum = current.motion.scrollSpeed;
    const topDistance = Math.max(0, edge - event.clientY);
    const bottomDistance = Math.max(0, event.clientY - (window.innerHeight - edge));
    current.scrollDelta = bottomDistance
      ? Math.ceil(Math.min(maximum, bottomDistance / edge * maximum))
      : topDistance ? -Math.ceil(Math.min(maximum, topDistance / edge * maximum)) : 0;
    if (current.scrollDelta && !scrollFrame.current) {
      const scroll = () => {
        const next = gesture.current;
        if (!next?.scrollDelta) {
          scrollFrame.current = 0;
          return;
        }
        const before = window.scrollY;
        window.scrollBy(0, next.scrollDelta);
        if (window.scrollY !== before) {
          if (next.lastEvent) processPointer(next.lastEvent);
          scrollFrame.current = window.requestAnimationFrame(scroll);
        }
        else scrollFrame.current = 0;
      };
      scrollFrame.current = window.requestAnimationFrame(scroll);
    }
  }, [announce, finish, itemRefs]);

  const startPointer = useCallback((event, id, manualTouch = false) => {
    const config = configuration.current;
    if (!config.enabled || gesture.current || event.button !== 0 || config.lockedIds.includes(id)) return;
    const source = itemRefs.current.get(id);
    if (!source) return;
    if (settleTimer.current) window.clearTimeout(settleTimer.current);
    settleTimer.current = 0;
    setSettling(null);
    event.preventDefault();
    event.stopPropagation();
    const bounds = source.getBoundingClientRect();
    const originalOrder = [...currentOrder.current];
    const pointerTarget = event.currentTarget.closest("[data-sortable-region]") ?? event.currentTarget;
    const referenceItems = config.variant === "freeform"
      ? [...itemRefs.current].map(([itemId, element]) => ({
        id: itemId,
        rect: element.getBoundingClientRect().toJSON(),
      })) : undefined;
    gesture.current = {
      id,
      pointerId: event.pointerId,
      pointerTarget,
      startX: event.clientX,
      startY: event.clientY,
      offsetX: event.clientX - bounds.left,
      offsetY: event.clientY - bounds.top,
      width: bounds.width,
      height: bounds.height,
      originalOrder,
      originalLayout: currentLayout.current,
      motion: motionConfiguration(source),
      referenceItems,
      spatialGrid: config.variant === "freeform"
        ? captureSpatialGrid(pointerTarget, referenceItems, itemRefs) : null,
      referenceScrollX: globalThis.scrollX ?? 0,
      referenceScrollY: globalThis.scrollY ?? 0,
      started: false,
      previousBeforeId: undefined,
      lastTime: event.timeStamp || performance.now(),
      tilt: { position: event.clientX, velocity: 0 },
      scrollDelta: 0,
    };
    if (!manualTouch) pointerTarget.setPointerCapture?.(event.pointerId);
    handlers.current.move = (nextEvent) => {
      if (nextEvent.pointerId !== gesture.current?.pointerId) return;
      gesture.current.lastEvent = nextEvent;
      if (!pendingFrame.current) {
        pendingFrame.current = window.requestAnimationFrame(() => {
          pendingFrame.current = 0;
          if (gesture.current?.lastEvent) processPointer(gesture.current.lastEvent);
        });
      }
    };
    handlers.current.finish = (nextEvent) => {
      // Flush the last move even when a quick gesture ends before its first frame.
      if (gesture.current && pendingFrame.current) {
        window.cancelAnimationFrame(pendingFrame.current);
        pendingFrame.current = 0;
        processPointer(gesture.current.lastEvent ?? nextEvent);
      }
      finish(true, nextEvent);
    };
    handlers.current.cancel = (nextEvent) => finish(false, nextEvent);
    handlers.current.lostCapture = (nextEvent) => finish(false, nextEvent);
    handlers.current.keydown = (nextEvent) => {
      if (nextEvent.key === "Escape") {
        nextEvent.preventDefault();
        finish(false);
      }
    };
    if (!manualTouch) {
      window.addEventListener("pointermove", handlers.current.move);
      window.addEventListener("pointerup", handlers.current.finish);
      window.addEventListener("pointercancel", handlers.current.cancel);
      pointerTarget.addEventListener("lostpointercapture", handlers.current.lostCapture);
    }
    window.addEventListener("keydown", handlers.current.keydown);
  }, [finish, itemRefs, processPointer]);

  const startTouchHold = useCallback((event, id) => {
    if (!configuration.current.enabled || gesture.current || touchHold.current || event.touches.length !== 1) return;
    const touch = event.touches[0];
    const origin = { x: touch.clientX, y: touch.clientY, id: touch.identifier,
      target: event.currentTarget, active: false, timer: 0 };
    const pointer = (point, nativeEvent) => ({ button: 0, pointerType: "touch", pointerId: origin.id,
      clientX: point.clientX, clientY: point.clientY, timeStamp: nativeEvent.timeStamp,
      currentTarget: origin.target, preventDefault() {}, stopPropagation() {} });
    origin.move = (nextEvent) => {
      const point = [...nextEvent.changedTouches].find(item => item.identifier === origin.id);
      if (!point) return;
      if (!origin.active) {
        if (Math.hypot(point.clientX - origin.x, point.clientY - origin.y) > 10) stopTouchHold();
        return;
      }
      nextEvent.preventDefault();
      nextEvent.stopPropagation();
      handlers.current.move?.(pointer(point, nextEvent));
    };
    origin.end = (nextEvent) => {
      const point = [...nextEvent.changedTouches].find(item => item.identifier === origin.id);
      if (!point) return;
      if (origin.active) handlers.current.finish?.(pointer(point, nextEvent));
      stopTouchHold();
    };
    origin.cancel = (nextEvent) => {
      if (![...nextEvent.changedTouches].some(item => item.identifier === origin.id)) return;
      if (origin.active) handlers.current.cancel?.(pointer(nextEvent.changedTouches[0], nextEvent));
      stopTouchHold();
    };
    touchHold.current = origin;
    window.addEventListener("touchmove", origin.move, { passive: false });
    window.addEventListener("touchend", origin.end);
    window.addEventListener("touchcancel", origin.cancel);
    origin.timer = window.setTimeout(() => {
      if (touchHold.current !== origin) return;
      startPointer(pointer({ clientX: origin.x, clientY: origin.y }, event), id, true);
      origin.active = Boolean(gesture.current?.id === id);
    }, 350);
  }, [startPointer, stopTouchHold]);

  const handleKeyDown = useCallback((event, id) => {
    const config = configuration.current;
    if (!config.enabled || config.lockedIds.includes(id)) return;
    const current = gesture.current;
    if ([" ", "Enter"].includes(event.key)) {
      event.preventDefault();
      if (current?.keyboard && current.id === id) {
        finish(true);
        return;
      }
      if (current) return;
      gesture.current = {
        id,
        keyboard: true,
        started: true,
        originalOrder: [...currentOrder.current],
        originalLayout: currentLayout.current,
      };
      setActive({ id, keyboard: true });
      announce(id, currentOrder.current, "Picked up");
      return;
    }
    if (!current?.keyboard || current.id !== id) return;
    if (event.key === "Escape") {
      event.preventDefault();
      finish(false);
      return;
    }
    if (!["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();
    const order = currentOrder.current;
    const index = order.indexOf(id);
    const target = keyboardBlockTarget(order, id, event.key, config.lockedIds);
    if (!target) return;
    const { index: nextIndex, id: targetId } = target;
    const remaining = order.filter((entry) => entry !== id);
    const beforeId = nextIndex > index ? remaining[nextIndex] ?? null : targetId;
    const resolved = config.resolveKeyboard?.({
      layout: currentLayout.current,
      activeId: id,
      targetId,
      placement: nextIndex > index ? "after" : "before",
      key: event.key,
    });
    if (config.resolveKeyboard && !resolved) return;
    const next = resolved?.order ?? moveBlockBefore(order, id, beforeId);
    if (next === order || config.lockedIds.some((lockedId) =>
      order.indexOf(lockedId) !== next.indexOf(lockedId))) return;
    config.onBeforeReorder();
    currentOrder.current = next;
    setPreviewOrder(next);
    if (resolved?.rows) {
      const nextLayout = { order: resolved.order, rows: resolved.rows, spans: resolved.spans,
        preferredSpans: resolved.preferredSpans, soloSpans: resolved.soloSpans,
        retainedRowIds: resolved.retainedRowIds };
      currentLayout.current = nextLayout;
      setPreviewLayout(nextLayout);
      setDropTarget({ id: resolved.targetId, placement: resolved.placement, rowId: resolved.rowId });
    }
    announce(id, next, "Moving");
  }, [announce, finish]);

  useEffect(() => {
    if (!enabled) {
      stopTouchHold();
      if (gesture.current) finish(false);
      // Exiting edit mode cancels the settling timer; remove its preview too.
      setSettling(null);
    }
    return () => {
      stopListeners();
      stopTouchHold();
      if (settleTimer.current) window.clearTimeout(settleTimer.current);
    };
  }, [enabled, finish, stopListeners, stopTouchHold]);

  return { active, settling, announcement, dropTarget, handleKeyDown, previewLayout, previewOrder,
    rowCandidate, startPointer, startTouchHold };
}
