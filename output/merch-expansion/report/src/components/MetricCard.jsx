import React, { useId, useRef } from "react";

import { MetricSparkline } from "../charting/MetricSparkline.jsx";
import { resolveDeltaTone } from "../charting/table-data.js";
import { DataComponent } from "./DataComponent.jsx";
import { useTabOverflow } from "./ui.jsx";

export { MetricSparkline };

export function MetricCard({ value, comparison, deltaTone, negative = false, trendValues = [], trendLabel, className = "", children, ...component }) {
  const delta = comparison;
  const tone = resolveDeltaTone(deltaTone, comparison, undefined, negative ? "negative" : "positive");
  const hasDelta = delta !== undefined && delta !== null && delta !== "";
  return <DataComponent variant="card" padding="spacious" {...component} kind="metric"
    className={["data-metric-card", "metric-item", className].filter(Boolean).join(" ")}>
    <div className="metric-primary data-metric-primary">
      <p className="metric-value data-metric-value">{value}</p>
      {(hasDelta || (!children && trendValues.some(Number.isFinite))) && <span className="metric-change data-metric-change">
        {!children && <MetricSparkline values={trendValues} label={trendLabel} tone={tone} />}
        {hasDelta && <span className={["comparison", "data-metric-delta", tone === "negative" && "negative"].filter(Boolean).join(" ")} data-delta={tone}>
          {delta}
        </span>}
      </span>}
    </div>
    {children && <div className="data-metric-chart">{children}</div>}
  </DataComponent>;
}

const metricCardTabSizes = Object.freeze(["small", "medium", "large"]);
const metricCardTabTones = Object.freeze(["positive", "negative", "neutral"]);
const metricCardTabOrientations = Object.freeze(["horizontal", "vertical"]);

function requireOption(name, value, options) {
  if (!options.includes(value)) {
    throw new Error(`${name} must be one of: ${options.join(", ")}.`);
  }
  return value;
}

function metricTabTone(tone, negative) {
  return requireOption(
    "MetricCardTabs item tone",
    tone ?? (negative ? "negative" : "positive"),
    metricCardTabTones,
  );
}

function MetricCardTabReading({ value, comparison, tone, trendValues = [] }) {
  const hasComparison = comparison !== undefined && comparison !== null && comparison !== "";
  return <span className="data-metric-reading data-metric-card-tab-reading" data-tone={tone}>
    <span className="data-metric-reading-value data-metric-card-tab-value">{value}</span>
    {hasComparison && <span className="data-metric-reading-change data-metric-card-tab-change">
      <MetricSparkline values={trendValues} tone={tone}
        className="data-metric-reading-sparkline" />
      <span data-tone={tone}
        className="data-metric-reading-delta data-metric-card-tab-delta">{comparison}</span>
    </span>}
  </span>;
}

function metricTabItems(items) {
  if (!Array.isArray(items) || !items.length) {
    throw new Error("MetricCardTabs requires at least one metric item.");
  }
  const ids = new Set();
  for (const item of items) {
    if (typeof item?.id !== "string" || !item.id.trim()) {
      throw new Error("Every MetricCardTabs item requires a non-empty stable id.");
    }
    if (ids.has(item.id)) throw new Error(`MetricCardTabs item ids must be unique: ${item.id}.`);
    if (typeof item.title !== "string" || !item.title.trim()) {
      throw new Error(`MetricCardTabs item "${item.id}" requires a title.`);
    }
    ids.add(item.id);
  }
  return items;
}

export function metricTabIndexForKey(key, currentIndex, itemCount, orientation = "horizontal") {
  if (!Number.isSafeInteger(currentIndex) || !Number.isSafeInteger(itemCount) || itemCount < 1) return null;
  if (!metricCardTabOrientations.includes(orientation)) return null;
  if (key === "Home") return 0;
  if (key === "End") return itemCount - 1;
  const previousKey = orientation === "vertical" ? "ArrowUp" : "ArrowLeft";
  const nextKey = orientation === "vertical" ? "ArrowDown" : "ArrowRight";
  if (key === previousKey) return (currentIndex - 1 + itemCount) % itemCount;
  if (key === nextKey) return (currentIndex + 1) % itemCount;
  return null;
}

export function MetricCardTabs({
  items,
  selectedId,
  onChange,
  size = "medium",
  orientation = "horizontal",
  ariaLabel = "Metric",
  className = "",
  children,
}) {
  const generatedId = `metric-card-tabs-${useId().replaceAll(":", "")}`;
  const tabRefs = useRef(new Map());
  const listRef = useRef(null);
  const reviewedItems = metricTabItems(items);
  const resolvedSize = requireOption("MetricCardTabs size", size, metricCardTabSizes);
  const resolvedOrientation = requireOption(
    "MetricCardTabs orientation",
    orientation,
    metricCardTabOrientations,
  );
  const selectedIndex = reviewedItems.findIndex(({ id }) => id === selectedId);
  if (selectedIndex < 0) {
    throw new Error(`MetricCardTabs selectedId must match an item id: ${String(selectedId)}.`);
  }
  const selectedItem = reviewedItems[selectedIndex];
  const panelId = `${generatedId}-panel`;
  const tabId = (item) => `${generatedId}-tab-${encodeURIComponent(item.id)}`;
  const selectedTabId = tabId(selectedItem);
  useTabOverflow(listRef, `${selectedId}:${reviewedItems.map(({ id, title }) => `${id}:${title}`).join("|")}`,
    resolvedOrientation === "horizontal");

  return <div className={["data-metric-card-tabs", className].filter(Boolean).join(" ")}
    data-size={resolvedSize} data-orientation={resolvedOrientation}>
    <div ref={listRef} className="data-metric-card-tabs-list" role="tablist" aria-label={ariaLabel}
      aria-orientation={resolvedOrientation}
      style={{ "--metric-card-tab-count": reviewedItems.length }}>
      {reviewedItems.map((item, index) => {
        const active = index === selectedIndex;
        const resolvedTone = metricTabTone(item.tone, item.negative);
        return <button key={item.id} id={tabId(item)} type="button" role="tab"
          ref={(element) => {
            if (element) tabRefs.current.set(item.id, element);
            else tabRefs.current.delete(item.id);
          }}
          className="data-metric-card-tab" data-tone={resolvedTone}
          aria-selected={active} aria-controls={panelId} tabIndex={active ? 0 : -1}
          onClick={() => onChange?.(item.id)}
          onKeyDown={(event) => {
            const nextIndex = metricTabIndexForKey(
              event.key,
              index,
              reviewedItems.length,
              resolvedOrientation,
            );
            if (nextIndex == null) return;
            event.preventDefault();
            const nextItem = reviewedItems[nextIndex];
            onChange?.(nextItem.id);
            tabRefs.current.get(nextItem.id)?.focus();
          }}>
          <span className="data-metric-card-tab-title">{item.title}</span>
          <MetricCardTabReading value={item.value} comparison={item.comparison}
            tone={resolvedTone} trendValues={item.trendValues} />
        </button>;
      })}
    </div>
    <div id={panelId} role="tabpanel" aria-labelledby={selectedTabId}
      className="data-metric-card-tabs-panel" tabIndex={0}>
      {typeof children === "function"
        ? children({ item: selectedItem, selectedId: selectedItem.id })
        : children}
    </div>
  </div>;
}
