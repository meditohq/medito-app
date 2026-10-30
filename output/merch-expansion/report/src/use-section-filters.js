import { useState } from "react";

import { useDataAppShell } from "./DataAppContext.jsx";
import { validFilterValue } from "./dashboard-url-state.js";
import { resolveSectionRows } from "./use-data-app.js";

/** Section selections stay independent of page filters and reviewed rows. */
export function useSectionFilters(definitions = [], initialValues = {}, sectionScope) {
  const { snapshot, queries, filters: pageValues, activeTabId, sectionViews, setSectionView } = useDataAppShell();
  const [selected, setSelected] = useState(initialValues);
  const scopeId = sectionScope?.id ?? sectionScope?.rowId;
  const shared = Boolean(typeof scopeId === "string" && scopeId.trim() && typeof setSectionView === "function");
  const scopeKey = shared ? `${activeTabId ?? "dashboard"}:${scopeId}` : null;
  const placementScope = sectionScope?.rowId && Array.isArray(sectionScope.componentIds) ? sectionScope : undefined;
  const fromView = shared && Object.hasOwn(sectionViews ?? {}, scopeKey) ? sectionViews[scopeKey] : null;
  const validationSnapshot = { ...snapshot, queries, filters: definitions };
  const values = Object.fromEntries(definitions.map((definition) => {
    const { id, defaultValue } = definition;
    const fallback = (shared ? initialValues : selected)[id] ?? defaultValue ?? "all";
    const candidate = fromView && Object.hasOwn(fromView, id) ? fromView[id] : undefined;
    // Sections explicitly offer All / All dates, including with a narrower initial selection.
    const value = candidate === "all" || validFilterValue(validationSnapshot, definition, candidate)
      ? candidate : fallback;
    return [id, value];
  }));
  const setFilter = (id, value) => {
    if (!definitions.some((definition) => definition.id === id)) return;
    if (shared) setSectionView(scopeKey, { ...values, [id]: value });
    else setSelected((previous) => ({ ...previous, [id]: value }));
  };
  // Share one resolution between the renderer and its source/copy metadata.
  // The cache lives for this render only, so changed scopes cannot reuse stale rows.
  const resolved = new Map();
  const reviewedRows = (queryId, breakdown = []) => {
    const key = JSON.stringify([queryId, breakdown]);
    if (!resolved.has(key)) resolved.set(key, resolveSectionRows(
      queries[queryId]?.rows ?? [], snapshot.filters ?? [], pageValues,
      definitions, values, queryId, breakdown,
    ));
    return resolved.get(key);
  };
  const filterProps = { filters: definitions, queries, values, onChange: setFilter,
    ariaLabel: sectionScope?.label ?? "Section filters", showClear: false,
    dateAllValue: "all", sticky: false, sectionScope: placementScope };
  const componentProps = (queryId, breakdown = []) => {
    const rows = reviewedRows(queryId, breakdown);
    return {
      displayRows: rows, sourceRows: rows,
      ...(placementScope ? { sectionFilters: filterProps } : {}),
      scopeFilters: definitions.filter(({ id, queryIds }) => values[id] !== "all"
        && (!Array.isArray(values[id]) || values[id].length > 0)
        && (!Array.isArray(queryIds) || queryIds.includes(queryId)))
        .map(({ id, field, label }) => ({ field, label, value: values[id] })),
    };
  };
  return { values, setFilter, reviewedRows, componentProps, filterProps };
}
