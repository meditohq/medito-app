import React, {
  Children, createContext, isValidElement, useCallback, useContext, useEffect, useLayoutEffect, useRef, useState,
} from "react";
import { createPortal } from "react-dom";

import {
  defaultBlockMinimumSpans, maxBlockLayoutRevision, preserveHiddenBlockPositions, rebalanceBlockRow, reconcileBlockOrder,
  reconcileBlockRows, resizeBlockRow, resolveCanvasInsertion, resolveCanvasMove, validBlockLayoutId,
} from "../block-layout.js";
import { useDataAppBlockLayouts, useDataAppShell } from "../DataAppContext.jsx";
import { useSortableBlocks } from "../use-sortable-blocks.js";

const SortableRegionContext = createContext(null);
const sortableTransferBoards = new Map();

function transferBoard(group) {
  if (!sortableTransferBoards.has(group)) {
    sortableTransferBoards.set(group, { regions: new Map(), subscribers: new Set() });
  }
  return sortableTransferBoards.get(group);
}

function notifyTransferBoard(board) {
  if (board.notificationPending) return;
  board.notificationPending = true;
  queueMicrotask(() => {
    board.notificationPending = false;
    for (const notify of board.subscribers) notify((version) => version + 1);
  });
}

function transferredRegionLayout(previous, order, incomingId, sourceLayout) {
  const next = { ...(previous ?? {}), order };
  for (const field of ["spans", "preferredSpans"]) {
    if (!previous?.[field] && !sourceLayout?.[field]?.[incomingId]) continue;
    const spans = Object.fromEntries(Object.entries(previous?.[field] ?? {})
      .filter(([itemId]) => order.includes(itemId)));
    if (sourceLayout?.[field]?.[incomingId]) spans[incomingId] = sourceLayout[field][incomingId];
    if (Object.keys(spans).length) next[field] = spans;
    else delete next[field];
  }
  return next;
}

export function useOptionalSortableBlock() {
  return useContext(SortableRegionContext);
}
const interactiveTarget = [
  "button", "a", "input", "textarea", "select", "[contenteditable='true']",
  "[role='button']", "[role='menu']", ".recharts-wrapper", ".chart-frame",
  ".table-wrap", ".toolbar", ".scenario-lever", ".scenario-levers", ".forecast-details",
  "[data-editable-narrative]", "[data-reviewed-rows]", "[data-reviewed-value]", "[data-block-no-drag]",
].join(", ");

function blockPreviewClone(source, destination, width, height) {
  if (!source || !destination) return;
  const clone = source.cloneNode(true);
  clone.style.width = `${width}px`;
  clone.style.minWidth = `${width}px`;
  clone.style.maxWidth = `${width}px`;
  clone.style.height = `${height}px`;
  clone.removeAttribute("id");
  clone.removeAttribute("data-component-id");
  clone.removeAttribute("data-query-id");
  clone.removeAttribute("data-sortable-item-id");
  clone.querySelectorAll("[id], [data-component-id], [data-query-id], [data-sortable-item-id]")
    .forEach((element) => {
      element.removeAttribute("id");
      element.removeAttribute("data-component-id");
      element.removeAttribute("data-query-id");
      element.removeAttribute("data-sortable-item-id");
    });
  clone.querySelectorAll("[data-block-drag-handle], [aria-live]").forEach((element) => element.remove());
  clone.querySelectorAll("button, a, input, textarea, select, [tabindex], [contenteditable]")
    .forEach((element) => {
      element.setAttribute("tabindex", "-1");
      element.removeAttribute("contenteditable");
    });
  destination.replaceChildren(clone);
}

function BlockDragPreview({ active, surface, contextClassName = "" }) {
  const ref = useCallback((element) => blockPreviewClone(active.source, element, active.width, active.height),
    [active.source, active.width, active.height]);
  const authoredContext = contextClassName.split(/\s+/).filter((name) => name
    && name !== "sortable-region" && !name.startsWith("sortable-region--")
    && name !== "is-block-dragging");
  return createPortal(<div ref={ref} aria-hidden="true" inert
    className={["block-drag-preview", ...authoredContext, active.settling && "is-settling"]
      .filter(Boolean).join(" ")}
    data-data-app-surface={surface}
    data-drag-settling={active.settling || undefined}
    data-drag-direction={active.tilt < -.05 ? "-1" : active.tilt > .05 ? "1" : "0"}
    style={{ left: active.left, top: active.top, width: active.width, height: active.height,
      display: "block", margin: 0, padding: 0, border: 0, background: "transparent", boxShadow: "none",
      "--block-drag-current-tilt": `${active.tilt}deg`,
      ...(active.settling ? {
        "--block-drop-offset-x": `${active.settleX}px`,
        "--block-drop-offset-y": `${active.settleY}px`,
        "--block-drop-scale-x": active.settleScaleX,
        "--block-drop-scale-y": active.settleScaleY,
        "--block-drop-duration": `${active.settleDuration}ms`,
      } : {}) }} />, document.body);
}

function orderedItems(items, order) {
  const byId = new Map(items.map((item) => [item.props.id, item]));
  return order.filter((id) => byId.has(id)).map((id) => byId.get(id));
}

function blockDescriptor(item) {
  return { id: item.props.id, kind: item.props.kind ?? "block", span: item.props.span,
    minSpan: item.props.minSpan, locked: item.props.locked };
}

function measuredBlockDescriptors(descriptors, itemRefs, columns, canvasWidth) {
  if (!canvasWidth || !columns) return descriptors;
  const measured = new Map();
  const columnWidth = canvasWidth / columns;
  for (const [id, descriptor] of descriptors) {
    const element = itemRefs.current.get(id);
    if (!element) { measured.set(id, descriptor); continue; }
    const component = element.querySelector("[data-component-id]");
    const header = component?.querySelector(".component-header");
    const title = header?.querySelector(".component-title-text")
      ?? header?.querySelector(".component-title");
    const menu = header?.querySelector(".menu-trigger");
    const titleWidth = Math.min(title?.scrollWidth ?? 0, 220);
    const menuWidth = menu?.getBoundingClientRect().width ?? 0;
    const componentWidth = component?.getBoundingClientRect().width ?? 0;
    const headerWidth = header?.getBoundingClientRect().width ?? componentWidth;
    const padding = Math.max(0, componentWidth - headerWidth);
    const semanticMinimum = descriptor.minSpan
      ?? defaultBlockMinimumSpans[descriptor.kind] ?? defaultBlockMinimumSpans.block;
    const minimum = Math.min(semanticMinimum,
      Math.ceil((titleWidth + menuWidth + padding + 40) / columnWidth));
    measured.set(id, { ...descriptor, measuredMinSpan: Math.min(columns, Math.max(1, minimum)) });
  }
  return measured;
}

export function SortableRegion({
  id,
  htmlId,
  label = "Sortable blocks",
  variant = "stack",
  transferGroup,
  authoredRevision = 1,
  authoredOrder,
  columns,
  rows,
  spacing = "authored",
  as: Tag = "div",
  className = "",
  style,
  children,
  ...attributes
}) {
  if (!validBlockLayoutId(id)) throw new Error("SortableRegion requires a stable, safe region id.");
  if (!["stack", "grid", "canvas", "freeform"].includes(variant)) {
    throw new Error("SortableRegion variant must be stack, grid, canvas, or freeform.");
  }
  if (!Number.isSafeInteger(authoredRevision) || authoredRevision < 1 || authoredRevision > maxBlockLayoutRevision) {
    throw new Error("SortableRegion authoredRevision must be a safe positive bounded integer.");
  }
  if (columns !== undefined && (!Number.isInteger(columns) || columns < 1 || columns > 12)) {
    throw new Error("SortableRegion columns must be an integer between 1 and 12.");
  }
  if (variant === "canvas" && (!Array.isArray(rows) || !rows.length)) {
    throw new Error("Canvas sortable regions require stable authored row definitions.");
  }
  if (!["authored", "standard"].includes(spacing)) {
    throw new Error("SortableRegion spacing must be authored or standard.");
  }
  if (transferGroup !== undefined && (variant !== "freeform" || !validBlockLayoutId(transferGroup))) {
    throw new Error("Compatible section transfers require a safe freeform transfer group.");
  }
  const shell = useDataAppShell();
  const { blockLayouts, setBlockLayout } = useDataAppBlockLayouts();
  const itemRefs = useRef(new Map());
  const previousPositions = useRef(new Map());
  const regionRef = useRef(null);
  const resizeGesture = useRef(null);
  const measurementCache = useRef(null);
  const appliedAuthoredRevision = useRef("");
  const transferDefinition = useRef(null);
  const transferTarget = useRef(null);
  const [, setTransferVersion] = useState(0);
  const [measurementVersion, setMeasurementVersion] = useState(0);
  const [resizePreview, setResizePreview] = useState(null);
  const board = transferGroup ? transferBoard(transferGroup) : null;
  const localElements = Children.toArray(children).filter(isValidElement);
  const transferredAway = new Set(board ? [...board.regions]
    .filter(([regionId]) => regionId !== id)
    .flatMap(([regionId]) => blockLayouts[regionId]?.order ?? []) : []);
  const incomingIds = board ? (blockLayouts[id]?.order ?? [])
    .filter((itemId) => !localElements.some((item) => item.props.id === itemId)) : [];
  const incoming = incomingIds.map((itemId) => [...(board?.regions.values() ?? [])]
    .map((definition) => definition.current?.localElements.find((item) => item.props.id === itemId))
    .find(Boolean)).filter(Boolean);
  const allItemElements = board
    ? [...localElements.filter((item) => !transferredAway.has(item.props.id)), ...incoming]
    : localElements;
  // Hide at the layout owner so no empty slot remains. Retain authored identity
  // and saved placement for restore, including blocks without an author guard.
  const allAuthoredIds = allItemElements.map((item) => item.props.id);
  const itemElements = allItemElements.filter((item) => !shell.hiddenBlockIds.has(item.props.id));
  const authoredIds = itemElements.map((item) => item.props.id);
  const stableAuthoredIds = board
    ? [...(authoredOrder ?? localElements.map((item) => item.props.id))
      .filter((itemId) => allAuthoredIds.includes(itemId)),
    ...incoming.map((item) => item.props.id)]
    : authoredOrder ?? allAuthoredIds;
  if (allAuthoredIds.some((itemId) => !validBlockLayoutId(itemId))
    || new Set(allAuthoredIds).size !== allAuthoredIds.length
    || !Array.isArray(stableAuthoredIds)
    || stableAuthoredIds.some((itemId) => !validBlockLayoutId(itemId))
    || new Set(stableAuthoredIds).size !== stableAuthoredIds.length
    || allAuthoredIds.some((itemId) => !stableAuthoredIds.includes(itemId))) {
    throw new Error(`Sortable region "${id}" requires unique stable item IDs.`);
  }
  const persisted = blockLayouts[id];
  const redesignRequested = Boolean(persisted && authoredRevision > (persisted.authoredRevision ?? 1));
  const previous = redesignRequested ? undefined : persisted;
  const hiddenIds = [...shell.hiddenBlockIds].filter((itemId) =>
    persisted?.order.includes(itemId) || rows?.some((row) => row.items.includes(itemId))
      || stableAuthoredIds.includes(itemId));
  const retainedIds = new Set([...authoredIds, ...hiddenIds]);
  const descriptors = new Map(itemElements.map((item) => [item.props.id, blockDescriptor(item)]));
  const authoredRows = variant === "canvas" ? rows.map((row) => ({
    id: row.id, items: row.items.filter((itemId) => retainedIds.has(itemId)),
  })) : [];
  const fullRows = variant === "canvas"
    ? reconcileBlockRows(authoredRows, previous?.rows, authoredIds, hiddenIds) : undefined;
  const fullOrder = variant === "canvas"
    ? fullRows.flatMap((row) => row.items)
    : reconcileBlockOrder(stableAuthoredIds, previous?.order, hiddenIds);
  const visibleOrder = fullOrder.filter((itemId) => authoredIds.includes(itemId));
  transferDefinition.current = { id, variant, localElements, fullOrder,
    previous: blockLayouts[id], itemRefs, setBlockLayout };
  useLayoutEffect(() => {
    if (!board) return undefined;
    board.regions.set(id, transferDefinition);
    board.subscribers.add(setTransferVersion);
    notifyTransferBoard(board);
    return () => {
      board.regions.delete(id);
      board.subscribers.delete(setTransferVersion);
      notifyTransferBoard(board);
    };
  }, [board, id, transferGroup]);
  const labels = new Map(itemElements.map((item) => [item.props.id, item.props.label ?? item.props.id]));
  const lockedIds = itemElements.filter((item) => item.props.locked).map((item) => item.props.id);
  const authoredSpans = Object.fromEntries(itemElements.map((item) => [
    item.props.id,
    Math.min(columns ?? 12, Math.max(1, previous?.spans?.[item.props.id] ?? item.props.span
      ?? defaultBlockMinimumSpans[item.props.kind] ?? 4)),
  ]));
  const preferredSpans = Object.fromEntries(itemElements.map((item) => [
    item.props.id,
    Math.min(columns ?? 12, Math.max(1, previous?.preferredSpans?.[item.props.id]
      ?? item.props.span ?? defaultBlockMinimumSpans[item.props.kind] ?? 4)),
  ]));
  const layout = variant === "canvas" ? {
    order: visibleOrder,
    rows: fullRows.map((row) => ({ id: row.id, items: row.items.filter((itemId) => authoredIds.includes(itemId)) })),
    spans: { ...authoredSpans, ...Object.fromEntries(fullRows.flatMap((row) => {
      const visible = row.items.filter((itemId) => authoredIds.includes(itemId));
      return Object.entries(rebalanceBlockRow(visible, descriptors, {
        columns: columns ?? 12, maxItems: Math.max(visible.length, 6),
        currentSpans: visible.length === 1 ? { ...authoredSpans, ...previous?.soloSpans } : authoredSpans, preferredSpans,
        fill: visible.length !== 1 || !previous?.soloSpans?.[visible[0]],
      }) ?? {});
    })) },
    preferredSpans,
    soloSpans: previous?.soloSpans ?? {},
    retainedRowIds: fullRows.filter((row) => row.items.some((itemId) => hiddenIds.includes(itemId)))
      .map((row) => row.id),
  } : undefined;
  const capturePositions = useCallback(() => {
    previousPositions.current = new Map([...itemRefs.current].map(([itemId, element]) =>
      [itemId, element.getBoundingClientRect()]));
  }, []);
  const commit = (next) => {
    if (variant === "canvas") {
      const allRows = next.rows.map((row) => {
        const previousRow = fullRows.find((entry) => entry.id === row.id);
        return { id: row.id, items: previousRow
          ? preserveHiddenBlockPositions(previousRow.items, row.items,
            previousRow.items.filter((itemId) => hiddenIds.includes(itemId)))
          : row.items };
      });
      const order = allRows.flatMap((row) => row.items);
      setBlockLayout(id, { order, rows: allRows,
        spans: Object.fromEntries(Object.entries({ ...previous?.spans, ...next.spans })
          .filter(([itemId]) => order.includes(itemId))),
        preferredSpans: Object.fromEntries(Object.entries({ ...previous?.preferredSpans,
          ...preferredSpans, ...next.preferredSpans }).filter(([itemId]) => order.includes(itemId))),
        ...(Object.keys(next.soloSpans ?? previous?.soloSpans ?? {}).length ? {
          soloSpans: Object.fromEntries(Object.entries(next.soloSpans ?? previous.soloSpans)
            .filter(([itemId]) => order.includes(itemId))),
        } : {}),
        ...(authoredRevision > 1 || previous?.authoredRevision !== undefined ? { authoredRevision } : {}),
      });
      return;
    }
    const preserved = preserveHiddenBlockPositions(fullOrder, next, hiddenIds);
    const spans = Object.fromEntries(itemElements.filter((item) => Number.isInteger(item.props.span))
      .map((item) => [item.props.id, Math.min(12, Math.max(1, item.props.span))]));
    setBlockLayout(id, {
      order: preserved,
      ...(Object.keys(spans).length ? { spans } : previous?.spans ? { spans: previous.spans } : {}),
      ...(authoredRevision > 1 || previous?.authoredRevision !== undefined ? { authoredRevision } : {}),
    });
  };
  useEffect(() => {
    if (!redesignRequested || !shell.canEdit) return;
    const revisionKey = `${id}:${authoredRevision}`;
    if (appliedAuthoredRevision.current === revisionKey) return;
    appliedAuthoredRevision.current = revisionKey;
    const next = { order: fullOrder, authoredRevision };
    if (variant === "canvas") {
      next.rows = fullRows;
      next.spans = authoredSpans;
      next.preferredSpans = preferredSpans;
    }
    setBlockLayout(id, next);
  }, [authoredRevision, id, redesignRequested, setBlockLayout, shell.canEdit, variant]);
  const enabled = shell.canEdit && shell.mode === "edit";
  const measuredDescriptors = () => {
    const width = regionRef.current?.getBoundingClientRect().width;
    const titleOverrides = shell.componentActions?.titleOverrides ?? {};
    const signature = `${columns ?? 12}:${Math.round(width ?? 0)}:${itemRefs.current.size}:${measurementVersion}:`
      + [...descriptors].map(([itemId, descriptor]) =>
        `${itemId}:${descriptor.kind}:${descriptor.span}:${descriptor.minSpan}:`
        + `${Number(Boolean(descriptor.locked))}:${titleOverrides[itemId] ?? ""}`)
        .join("|");
    if (measurementCache.current?.signature === signature) return measurementCache.current.descriptors;
    const measured = measuredBlockDescriptors(descriptors, itemRefs, columns ?? 12, width);
    measurementCache.current = { signature, descriptors: measured };
    return measured;
  };
  const minimumSpans = () => {
    if (!regionRef.current || typeof getComputedStyle !== "function") return defaultBlockMinimumSpans;
    const styles = getComputedStyle(regionRef.current);
    return Object.fromEntries(Object.entries(defaultBlockMinimumSpans).map(([kind, fallback]) => {
      const value = Number.parseFloat(styles.getPropertyValue(`--block-layout-min-${kind}-span`));
      return [kind, Number.isFinite(value) && value > 0 ? Math.round(value) : fallback];
    }));
  };
  const clearExternalPlacement = () => {
    transferTarget.current?.removeAttribute("data-block-transfer-target");
    transferTarget.current = null;
  };
  const resolveExternalPlacement = board ? ({ activeId, pointer, dragRect }) => {
    const target = document.elementFromPoint(pointer.x, pointer.y)
      ?.closest("[data-sortable-item-id]");
    const destination = target?.closest("[data-sortable-region]");
    const destinationId = destination?.dataset.sortableRegion;
    const definition = destinationId && destinationId !== id ? board.regions.get(destinationId)?.current : null;
    const targetId = target?.dataset.sortableItemId;
    if (!definition || destination.dataset.sortableTransferGroup !== transferGroup
      || target.dataset.sortableLocked === "true") {
      clearExternalPlacement();
      return null;
    }
    const sourceItem = itemElements.find((item) => item.props.id === activeId);
    const targetItem = definition.localElements.find((item) => item.props.id === targetId)
      ?? [...board.regions.values()]
        .map((candidate) => candidate.current?.localElements.find((item) => item.props.id === targetId))
        .find(Boolean);
    const targetBounds = target.getBoundingClientRect();
    const compatible = sourceItem && targetItem
      && (sourceItem.props.kind ?? "block") === (targetItem.props.kind ?? "block")
      && Math.max(dragRect.width, targetBounds.width) / Math.max(1, Math.min(dragRect.width, targetBounds.width)) <= 1.8
      && Math.max(dragRect.height, targetBounds.height) / Math.max(1, Math.min(dragRect.height, targetBounds.height)) <= 1.8;
    if (!compatible) {
      clearExternalPlacement();
      return null;
    }
    if (transferTarget.current !== target) {
      clearExternalPlacement();
      target.setAttribute("data-block-transfer-target", "true");
      transferTarget.current = target;
    }
    return { destinationId, targetId };
  } : undefined;
  const transferBetweenSections = board ? ({ activeId, sourceOrder, destinationId, targetId }) => {
    const destination = board.regions.get(destinationId)?.current;
    if (!destination || !sourceOrder.includes(activeId) || !destination.fullOrder.includes(targetId)) return false;
    const retainedSourceOrder = preserveHiddenBlockPositions(fullOrder, sourceOrder, hiddenIds);
    const nextSourceOrder = retainedSourceOrder.map((itemId) => itemId === activeId ? targetId : itemId);
    const nextDestinationOrder = destination.fullOrder.map((itemId) => itemId === targetId ? activeId : itemId);
    const sourceLayout = blockLayouts[id];
    const destinationLayout = blockLayouts[destinationId];
    setBlockLayout(id, transferredRegionLayout(sourceLayout, nextSourceOrder, targetId, destinationLayout));
    setBlockLayout(destinationId,
      transferredRegionLayout(destinationLayout, nextDestinationOrder, activeId, sourceLayout));
    return true;
  } : undefined;
  const { active, settling, announcement, dropTarget, handleKeyDown, previewLayout, previewOrder,
    rowCandidate, startPointer, startTouchHold }
    = useSortableBlocks({
      enabled,
      regionId: id,
      variant: variant === "canvas" ? "grid" : variant,
      itemIds: visibleOrder,
      itemRefs,
      labels,
      lockedIds,
      layout,
      resolvePlacement: variant === "canvas"
        ? ({ layout: current, items, activeId, pointer, dragRect, dragDirection, hysteresis, policy }) =>
          resolveCanvasInsertion({ ...current, blocks: measuredDescriptors(), items, activeId, pointer,
            dragRect, dragDirection, hysteresis, columns: columns ?? 12, ...policy }) : undefined,
      resolveKeyboard: variant === "canvas" ? ({ layout: current, activeId, targetId, placement, key }) =>
        resolveCanvasMove({ ...current, blocks: measuredDescriptors(), activeId, targetId, placement,
          columns: columns ?? 12 })
          ?? resolveCanvasMove({ ...current, blocks: measuredDescriptors(), activeId, targetId,
            placement: ["ArrowDown", "ArrowRight", "End"].includes(key) ? "below" : "above",
            columns: columns ?? 12 }) : undefined,
      resolveExternalPlacement,
      clearExternalPlacement,
      onTransfer: transferBetweenSections,
      onCommit: commit,
      onBeforeReorder: capturePositions,
    });
  const displayedLayout = resizePreview ?? previewLayout ?? layout;
  const register = useCallback((itemId, element) => {
    if (element) itemRefs.current.set(itemId, element);
    else itemRefs.current.delete(itemId);
  }, []);

  useEffect(() => {
    if (typeof document === "undefined" || variant !== "canvas") return undefined;
    let invalidationFrame = 0;
    const invalidate = () => {
      measurementCache.current = null;
      setMeasurementVersion((current) => current + 1);
    };
    document.fonts?.addEventListener?.("loadingdone", invalidate);
    const observer = typeof MutationObserver !== "undefined" ? new MutationObserver(invalidate) : null;
    observer?.observe(document.documentElement, { attributes: true,
      attributeFilter: ["class", "style", "data-theme", "data-color-scheme"] });
    const contentObserver = typeof MutationObserver !== "undefined"
      ? new MutationObserver((mutations) => {
        if (regionRef.current?.classList.contains("is-block-dragging")) return;
        const relevant = mutations.some(({ target, addedNodes, removedNodes }) => {
          const element = target.nodeType === Node.ELEMENT_NODE ? target : target.parentElement;
          if (element?.closest("thead, .component-title-text")) return true;
          return [...addedNodes, ...removedNodes].some((node) => node.nodeType === Node.ELEMENT_NODE
            && (node.matches("table, thead, th, .component-header, .component-title-text")
              || node.querySelector("thead, th, .component-header, .component-title-text")));
        });
        if (!relevant || invalidationFrame) return;
        invalidationFrame = requestAnimationFrame(() => {
          invalidationFrame = 0;
          invalidate();
        });
      }) : null;
    if (regionRef.current) contentObserver?.observe(regionRef.current,
      { childList: true, subtree: true, characterData: true });
    return () => {
      document.fonts?.removeEventListener?.("loadingdone", invalidate);
      observer?.disconnect();
      contentObserver?.disconnect();
      if (invalidationFrame) cancelAnimationFrame(invalidationFrame);
    };
  }, [variant]);

  useLayoutEffect(() => {
    const region = regionRef.current;
    if (!region || variant !== "canvas" || !enabled) return undefined;
    const updateGutters = () => {
      for (const row of region.querySelectorAll("[data-sortable-row]")) {
        const gutter = Math.max(0, Number.parseFloat(getComputedStyle(row).columnGap) || 0);
        row.style.setProperty("--block-resize-gutter", `${gutter}px`);
        for (const item of row.querySelectorAll(":scope > [data-sortable-item-id]")) {
          const handle = item.querySelector(":scope > [data-block-resize-handle]");
          if (!handle) continue;
          const neighbor = item.nextElementSibling;
          const bounds = item.getBoundingClientRect();
          const neighborBounds = neighbor?.getBoundingClientRect();
          const aligned = Boolean(neighborBounds && Math.abs(bounds.top - neighborBounds.top) <= 2
            && neighborBounds.left >= bounds.right - 2);
          const single = row.querySelectorAll(":scope > [data-sortable-item-id]").length === 1
            && getComputedStyle(row).gridTemplateColumns.split(" ").length > 1;
          handle.hidden = !aligned && !single;
          handle.disabled = !aligned && !single;
          if (aligned) {
            const sharedCenter = (Math.max(bounds.top, neighborBounds.top)
              + Math.min(bounds.bottom, neighborBounds.bottom)) / 2;
            const sourceCenter = (bounds.top + bounds.bottom) / 2;
            handle.style.setProperty("--block-resize-center-offset", `${sharedCenter - sourceCenter}px`);
          } else handle.style.removeProperty("--block-resize-center-offset");
        }
      }
    };
    updateGutters();
    if (typeof ResizeObserver === "undefined") return undefined;
    const observer = new ResizeObserver(updateGutters);
    observer.observe(region);
    return () => observer.disconnect();
  }, [enabled, variant, displayedLayout?.rows?.length]);

  useLayoutEffect(() => {
    if (!previousPositions.current.size || !regionRef.current) return;
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const styles = getComputedStyle(regionRef.current);
    const durationToken = styles.getPropertyValue("--block-drag-reorder-duration").trim();
    const duration = (Number.parseFloat(durationToken) || 0)
      * (durationToken.endsWith("ms") ? 1 : durationToken.endsWith("s") ? 1000 : 1);
    const easing = styles.getPropertyValue("--block-drag-reorder-easing").trim() || "ease";
    for (const [itemId, element] of itemRefs.current) {
      if (itemId === active?.id) continue;
      const previousPosition = previousPositions.current.get(itemId);
      if (!previousPosition || reduceMotion || !duration) continue;
      const next = element.getBoundingClientRect();
      const deltaX = previousPosition.left - next.left;
      const deltaY = previousPosition.top - next.top;
      if (!deltaX && !deltaY) continue;
      element.getAnimations?.().forEach((animation) => animation.cancel());
      element.animate([
        { transform: `translate(${deltaX}px, ${deltaY}px)` },
        { transform: "translate(0, 0)" },
      ], { duration, easing });
    }
    previousPositions.current.clear();
  }, [active?.id, previewOrder, displayedLayout]);

  const setBlockWidth = (itemId, requestedSpan,
    { preview = false, base = displayedLayout, neighborId } = {}) => {
    if (!enabled || variant !== "canvas") return null;
    const next = resizeBlockRow({ ...base, blocks: measuredDescriptors(), activeId: itemId,
      neighborId, span: requestedSpan, columns: columns ?? 12, minimumSpans: minimumSpans() });
    if (!next) return null;
    capturePositions();
    const nextLayout = { order: next.order, rows: next.rows, spans: next.spans,
      preferredSpans: next.preferredSpans,
      soloSpans: { ...base.soloSpans, ...(!neighborId ? { [itemId]: requestedSpan } : {}) } };
    if (preview) setResizePreview(nextLayout);
    else { setResizePreview(null); commit(nextLayout); }
    return nextLayout;
  };

  const startResize = (event, itemId, neighborId) => {
    if (!enabled || variant !== "canvas" || event.button !== 0 || active || resizeGesture.current) return;
    event.preventDefault();
    event.stopPropagation();
    const original = displayedLayout;
    const width = regionRef.current?.getBoundingClientRect().width;
    if (!width) return;
    resizeGesture.current = { id: itemId, neighborId, pointerId: event.pointerId, startX: event.clientX,
      startSpan: Number(event.currentTarget.getAttribute("aria-valuenow")) || original.spans[itemId], original, latest: null };
    const move = (nextEvent) => {
      const current = resizeGesture.current;
      if (!current || nextEvent.pointerId !== current.pointerId) return;
      const delta = Math.round((nextEvent.clientX - current.startX) / width * (columns ?? 12));
      const next = setBlockWidth(itemId, Math.max(1, Math.min(columns ?? 12, current.startSpan + delta)),
        { preview: true, base: current.original, neighborId: current.neighborId });
      if (next) current.latest = next;
    };
    const finish = (nextEvent) => {
      const current = resizeGesture.current;
      if (!current || nextEvent.pointerId !== current.pointerId) return;
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", finish);
      window.removeEventListener("pointercancel", cancel);
      resizeGesture.current = null;
      setResizePreview(null);
      if (current.latest) commit(current.latest);
    };
    const cancel = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", finish);
      window.removeEventListener("pointercancel", cancel);
      resizeGesture.current = null;
      setResizePreview(null);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", finish);
    window.addEventListener("pointercancel", cancel);
  };

  let cachedResizeDescriptors;
  let cachedResizePolicy;
  const resizeRange = (itemId, rowSpans, neighborId) => {
    if (!enabled || variant !== "canvas") return null;
    const current = rowSpans[itemId] ?? displayedLayout.spans[itemId];
    const limit = columns ?? 12;
    const base = { ...displayedLayout, spans: { ...displayedLayout.spans, ...rowSpans } };
    const blocks = cachedResizeDescriptors ??= measuredDescriptors();
    const policy = cachedResizePolicy ??= minimumSpans();
    const available = Array.from({ length: limit }, (_, index) => index + 1)
      .filter((span) => span !== current && resizeBlockRow({ ...base, blocks,
        activeId: itemId, neighborId, span, columns: limit, minimumSpans: policy }));
    return available.length ? {
      minimum: Math.min(current, ...available),
      maximum: Math.max(current, ...available),
      columns: limit,
    } : null;
  };

  const context = {
    enabled,
    activeId: active?.id,
    keyboard: active?.keyboard ?? false,
    dropTarget,
    handleKeyDown,
    register,
    regionId: id,
    rowCandidate,
    setBlockWidth,
    spans: displayedLayout?.spans,
    rows: displayedLayout?.rows,
    visibleItemIds: new Set(itemElements.map((item) => item.props.id)),
    startResize,
    startPointer,
    startTouchHold,
    variant,
  };
  const items = new Map(itemElements.map((item) => [item.props.id, item]));
  const rowMetadata = new Map((rows ?? []).map((row) => [row.id, row]));

  return <SortableRegionContext.Provider value={context}>
    <Tag {...attributes} id={htmlId} ref={regionRef} aria-label={label}
      className={["sortable-region", `sortable-region--${variant}`, className,
        active ? "is-block-dragging" : ""].filter(Boolean).join(" ")}
      data-sortable-region={id} data-sortable-variant={variant}
      data-sortable-transfer-group={transferGroup}
      data-sortable-columns={variant !== "canvas" && Number.isInteger(columns) ? columns : undefined}
      style={Number.isInteger(columns) ? { ...style, "--sortable-columns": columns } : style}>
      {variant === "canvas" ? displayedLayout.rows.map((row, rowIndex) => {
        const metadata = rowMetadata.get(row.id);
        const visible = row.items.filter((itemId) => items.has(itemId));
        const precedingRow = displayedLayout.rows.slice(0, rowIndex).findLast((entry) => entry.items.some((itemId) => items.has(itemId)));
        const followsMetrics = rowMetadata.get(precedingRow?.id)?.kind === "metrics";
        const sharedSpacing = spacing === "standard" || metadata?.kind !== undefined || metadata?.spacing !== undefined;
        const rowSpacing = metadata?.spacing ?? (followsMetrics ? "after-metrics"
          : metadata?.kind === "metrics" ? "metrics" : metadata?.header ? "section" : "content");
        const rowSpans = visible.length ? rebalanceBlockRow(visible, descriptors, {
          columns: columns ?? 12, maxItems: Math.max(visible.length, 6),
          minimumSpans: minimumSpans(),
          currentSpans: displayedLayout.spans,
          preferredSpans: displayedLayout.preferredSpans,
          fill: visible.length !== 1 || !displayedLayout.soloSpans?.[visible[0]],
        }) ?? {} : {};
        return <section key={row.id} className={[
          "sortable-canvas-row", sharedSpacing ? "data-section" : "", metadata?.className ?? "",
          !visible.length ? "sortable-canvas-row--empty" : "",
        ].filter(Boolean).join(" ")} data-sortable-row={row.id}
        data-section-kind={sharedSpacing ? metadata?.kind ?? "content" : undefined}
        data-section-spacing={sharedSpacing ? rowSpacing : undefined}
        data-section-leading-space={sharedSpacing && !precedingRow && metadata?.spacing === undefined ? "auto" : undefined}
        data-sortable-columns={columns ?? 12} aria-label={metadata?.label ?? "Dashboard row"}
        data-row-drop-candidate={rowCandidate?.afterRowId === row.id ? "before"
          : rowCandidate?.beforeRowId === row.id && !rowCandidate?.afterRowId ? "after" : undefined}>
          {metadata?.header && <header className="sortable-row-header">{metadata.header}</header>}
          {active && !active.keyboard && visible.length > 0
            && <div className="sortable-row-insertion-zone" aria-hidden="true"
              data-row-dropzone={rowCandidate?.afterRowId === row.id ? "active" : "available"}>
              <span>New row</span>
            </div>}
          {visible.map((itemId, index) => {
            const neighborId = visible[index + 1];
            const availableRange = enabled && !active && (visible.length === 1 || index < visible.length - 1)
              ? resizeRange(itemId, rowSpans, neighborId) : null;
            return React.cloneElement(items.get(itemId), {
              key: itemId, effectiveSpan: rowSpans[itemId],
              soloResized: Boolean(displayedLayout.soloSpans?.[itemId]),
              resizable: Boolean(availableRange), resizeRange: availableRange,
              resizeNeighborId: neighborId, resizeNeighborLabel: labels.get(neighborId),
            });
          })}
          {active && !active.keyboard && rowIndex === displayedLayout.rows.length - 1
            && <div className="sortable-row-insertion-zone sortable-row-insertion-zone--last" aria-hidden="true"
              data-row-dropzone={rowCandidate?.beforeRowId === row.id && !rowCandidate?.afterRowId
                ? "active" : "available"}><span>New row</span></div>}
        </section>;
      }) : orderedItems(itemElements, previewOrder ?? visibleOrder)}
      <span className="sortable-announcement" role="status" aria-live="polite" aria-atomic="true">
        {announcement}
      </span>
    </Tag>
    {(active && !active.keyboard || settling) && typeof document !== "undefined"
      && <BlockDragPreview active={active && !active.keyboard ? active : settling}
        surface={shell.snapshot.surface} contextClassName={regionRef.current?.className} />}
  </SortableRegionContext.Provider>;
}

export function SortableItem({
  id,
  label = id,
  kind = "block",
  span,
  minSpan,
  effectiveSpan,
  soloResized,
  resizable = false,
  resizeRange,
  resizeNeighborId,
  resizeNeighborLabel,
  locked = false,
  className = "",
  style: authoredStyle,
  children,
}) {
  const region = useContext(SortableRegionContext);
  if (!region) throw new Error("SortableItem must render inside a SortableRegion.");
  if (!validBlockLayoutId(id)) throw new Error("SortableItem requires a stable, safe item id.");
  const elementRef = useCallback((element) => region.register(id, element), [id, region.register]);
  const active = region.activeId === id;
  const width = effectiveSpan ?? region.spans?.[id] ?? span;
  const style = Number.isInteger(width) ? {
    ...authoredStyle,
    "--sortable-item-span": Math.min(12, Math.max(1, width)),
    ...(Number.isInteger(minSpan) ? { "--sortable-item-min-span": Math.max(1, minSpan) } : {}),
  } : authoredStyle;
  function startFromSurface(event) {
    if (!region.enabled || locked || event.target.closest(interactiveTarget)) return;
    if (event.pointerType === "touch" && window.matchMedia("(max-width: 599px)").matches) return;
    if (!canDragSurface(event)) return;
    region.startPointer(event, id);
  }
  function canDragSurface(event) {
    const component = event.target.closest(".dashboard-component");
    const header = component?.querySelector(":scope > .component-header");
    const componentBounds = component?.getBoundingClientRect();
    const headerBounds = header?.getBoundingClientRect();
    const inHeaderBand = Boolean(componentBounds && headerBounds
      && event.clientX >= componentBounds.left && event.clientX <= componentBounds.right
      && event.clientY >= componentBounds.top && event.clientY <= headerBounds.bottom);
    return inHeaderBand || Boolean(event.target.closest(".component-header, [data-block-drag-surface], "
      + '.dashboard-component[data-component-kind="metric"]'));
  }
  function startFromTouchSurface(event) {
    const interactive = event.target.closest(interactiveTarget);
    const editableTitle = interactive?.matches('[contenteditable="true"]')
      && interactive.closest('.component-header');
    if (!region.enabled || locked || !window.matchMedia("(max-width: 599px)").matches
      || interactive && !editableTitle || !canDragSurface(event)) return;
    region.startTouchHold(event, id);
  }
  return <div ref={elementRef}
    className={["sortable-item", className, active ? "is-dragging" : ""].filter(Boolean).join(" ")}
    data-sortable-item-id={id} data-sortable-kind={kind}
    data-block-solo-resized={soloResized || undefined}
    data-sortable-span={Number.isInteger(width) ? Math.min(12, Math.max(1, width)) : undefined}
    data-sortable-locked={locked || undefined} data-sortable-keyboard={active && region.keyboard || undefined}
    data-block-drop-placement={region.dropTarget?.id === id ? region.dropTarget.placement : undefined}
    data-block-direct-drag={region.enabled && !locked || undefined}
    style={style} onPointerDown={startFromSurface} onTouchStart={startFromTouchSurface}>
    {region.enabled && !locked && <button type="button" className="block-drag-keyboard"
      data-block-drag-handle="true" aria-label={`Move ${label}`}
      aria-keyshortcuts="Space Enter ArrowUp ArrowDown ArrowLeft ArrowRight Home End Escape"
      aria-pressed={active && region.keyboard}
      onKeyDown={(event) => region.handleKeyDown(event, id)}>
      Move {label}
    </button>}
    {resizable && !locked && <button type="button" className="block-resize-boundary"
      data-block-resize-handle="true" data-resize-neighbor={resizeNeighborId}
      aria-label={`Resize ${label}${resizeNeighborLabel ? ` and ${resizeNeighborLabel}` : ""}`} role="separator"
      title={`Drag to resize (${Math.round(resizeRange.minimum / resizeRange.columns * 100)}–${Math.round(resizeRange.maximum / resizeRange.columns * 100)}%)`}
      aria-orientation="vertical" aria-valuemin={resizeRange.minimum} aria-valuemax={resizeRange.maximum}
      aria-valuenow={width}
      aria-valuetext={`${Math.round(width / resizeRange.columns * 100)}% width`}
      onPointerDown={(event) => region.startResize(event, id, resizeNeighborId)}
      onKeyDown={(event) => {
        if (!["ArrowLeft", "ArrowRight"].includes(event.key)) return;
        event.preventDefault();
        region.setBlockWidth(id, width + (event.key === "ArrowRight" ? 1 : -1),
          { neighborId: resizeNeighborId });
      }} onDoubleClick={() => region.setBlockWidth(id, span, { neighborId: resizeNeighborId })} />}
    {children}
  </div>;
}
