import React, { useLayoutEffect, useState } from "react";

import { SortableItem, SortableRegion, useDataApp } from "../../data-app-public.jsx";

function sortableMetadata(element) {
  if (!React.isValidElement(element) || typeof element.type !== "function") return null;
  if (typeof element.props.id !== "string") return null;
  if (!["kind", "queryId", "spec", "rows", "displayRows", "sourceRows", "value", "feature"]
    .some((field) => field in element.props)) return null;
  const kind = element.props.kind ?? ("value" in element.props ? "metric" : "chart");
  const classes = (element.props.className ?? "").split(/\s+/u).filter(Boolean);
  const authoredSize = element.props.size ?? ("displayRows" in element.props && "spec" in element.props
    ? "half" : undefined);
  if (["full", "two-thirds", "half", "third"].includes(authoredSize)) {
    classes.push(`engineering-panel--${authoredSize}`);
  }
  return { id: element.props.id, kind, label: element.props.title ?? element.props.id,
    className: [...new Set(classes)].join(" ") };
}

function regionLabel(items, attributes) {
  return attributes["aria-label"] ?? (items.every(({ metadata }) => metadata.kind === "metric")
    ? "Dashboard metrics" : "Dashboard visualizations");
}

function measuredCanvasLayout(region, items, metrics) {
  if (!region || items.length < 2) return null;
  const styles = getComputedStyle(region);
  if (!styles.display.includes("grid") || styles.gridAutoFlow.includes("dense")
    || styles.gridTemplateAreas !== "none") return null;
  const elements = [...region.querySelectorAll(":scope > [data-sortable-item-id]")];
  if (elements.length !== items.length) return null;
  const measured = elements.map((element) => ({
    id: element.dataset.sortableItemId,
    bounds: element.getBoundingClientRect(),
    rowSpan: getComputedStyle(element).gridRowEnd,
  }));
  if (measured.some(({ bounds, rowSpan }) => !bounds.width || !bounds.height
    || /^span\s+(?:[2-9]|\d{2,})$/u.test(rowSpan))) return null;

  const grouped = [];
  for (const item of measured) {
    const row = grouped.find((entry) => Math.abs(entry.top - item.bounds.top) < 3);
    if (row) row.items.push(item);
    else grouped.push({ top: item.bounds.top, items: [item] });
  }
  grouped.sort((left, right) => left.top - right.top);
  for (const row of grouped) row.items.sort((left, right) => left.bounds.left - right.bounds.left);
  if (!grouped.some(({ items: rowItems }) => rowItems.length > 1)
    || grouped.some(({ items: rowItems }) => rowItems.length > 6)) return null;

  const columns = metrics && grouped.every(({ items: rowItems }) => rowItems.length === 5) ? 10 : 12;
  const minimum = metrics ? 2 : 3;
  const gap = Number.parseFloat(styles.columnGap) || 0;
  const spans = {};
  for (const row of grouped) {
    if (row.items.length * minimum > columns) return null;
    const totalWidth = row.items.reduce((sum, { bounds }) => sum + bounds.width + gap, 0);
    const allocations = row.items.map(({ id, bounds }) => {
      const exact = (bounds.width + gap) / totalWidth * columns;
      return { id, exact, span: Math.max(minimum, Math.floor(exact)) };
    });
    let remaining = columns - allocations.reduce((sum, { span }) => sum + span, 0);
    while (remaining !== 0) {
      const eligible = allocations.filter(({ span }) => remaining > 0 || span > minimum)
        .sort((left, right) => remaining > 0
          ? right.exact - right.span - (left.exact - left.span)
          : left.exact - left.span - (right.exact - right.span));
      if (!eligible.length) return null;
      eligible[0].span += Math.sign(remaining);
      remaining -= Math.sign(remaining);
    }
    for (const { id, span } of allocations) spans[id] = span;
  }

  return {
    columns,
    spans,
    rows: grouped.map(({ items: rowItems }) => ({
      id: `row:${rowItems[0].id}`,
      items: rowItems.map(({ id }) => id),
      label: metrics ? "Dashboard metrics" : "Dashboard visualizations",
      className: "authored-dashboard-row",
    })),
    gap,
    rowGap: Number.parseFloat(styles.rowGap) || 0,
  };
}

function AdaptiveSortableRegion({ regionId, scope, items, metrics, as, attributes }) {
  const signature = items.map(({ metadata }) => metadata.id).join("|");
  const [measurement, setMeasurement] = useState(null);
  const canvas = measurement?.signature === signature ? measurement : null;
  useLayoutEffect(() => {
    if (canvas || typeof document === "undefined") return;
    const region = document.querySelector(`[data-sortable-region="${CSS.escape(regionId)}"]`);
    const measure = () => {
      const measured = measuredCanvasLayout(region, items, metrics);
      if (measured) setMeasurement({ ...measured, signature });
    };
    measure();
    // Hidden tabs and narrow previews may not have promotable geometry on mount.
    // Retry when their container changes; stop observing once promotion succeeds.
    const observer = typeof ResizeObserver === "function" ? new ResizeObserver(measure) : null;
    if (region) observer?.observe(region);
    return () => observer?.disconnect();
  }, [canvas, items, metrics, regionId, signature]);

  const canvasStyle = canvas ? {
    ...attributes.style,
    gridTemplateColumns: "minmax(0, 1fr)",
    "--block-layout-column-gap": `${canvas.gap}px`,
    "--block-layout-row-gap": `${canvas.rowGap}px`,
  } : attributes.style;

  return <SortableRegion label={regionLabel(items, attributes)}
    variant={canvas ? "canvas" : "freeform"}
    transferGroup={!canvas && !metrics ? `dashboard:${scope}:visualizations` : undefined}
    columns={canvas?.columns} rows={canvas?.rows}
    data-authored-dashboard-canvas={canvas ? "true" : undefined}
    as={as} {...attributes} id={regionId} htmlId={attributes.id} style={canvasStyle}>
    {items.map(({ element, metadata }) => <SortableItem key={metadata.id} id={metadata.id}
      label={metadata.label} kind={metadata.kind} className={metadata.className}
      span={canvas?.spans[metadata.id]}>
      {element}
    </SortableItem>)}
  </SortableRegion>;
}

export function SortableDashboardLayout({ children, scope }) {
  const { visible } = useDataApp();

  function renderRegion(elements, path, { as = "div", ...attributes } = {}) {
    const authored = elements.map((element) => ({ element, metadata: sortableMetadata(element) }))
      .filter(({ metadata }) => metadata);
    const items = authored.filter(({ metadata }) => visible(metadata.id));
    if (!items.length) return null;
    const metrics = items.every(({ metadata }) => metadata.kind === "metric");
    const stableIdentity = attributes.id ?? authored[0].metadata.id;
    const regionId = `dashboard:${scope}:${stableIdentity}`;
    return <AdaptiveSortableRegion key={regionId} regionId={regionId} scope={scope}
      items={items} metrics={metrics} as={as} attributes={attributes} />;
  }

  function visit(element, path) {
    if (!React.isValidElement(element)) return element;
    if (sortableMetadata(element)) return renderRegion([element], path);
    if (element.type !== React.Fragment && typeof element.type !== "string") return element;

    const original = React.Children.toArray(element.props.children);
    if (!original.length) return element;
    const movable = original.filter((child) => sortableMetadata(child));

    if (typeof element.type === "string" && movable.length && movable.length === original.length) {
      const { children: ignored, ...attributes } = element.props;
      return renderRegion(movable, path, { as: element.type, ...attributes });
    }

    const updated = original.map((child, index) => visit(child, [...path, index]));
    return React.cloneElement(element, undefined, ...updated);
  }

  return <>{React.Children.toArray(children).map((child, index) => visit(child, [index]))}</>;
}
