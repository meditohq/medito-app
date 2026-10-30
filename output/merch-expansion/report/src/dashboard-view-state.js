// Authored bindings are separate from shared tab labels/order. Views are personal.
import { resolveDashboardUrlFilters, validFilterValue } from "./dashboard-url-state.js";

export function dashboardTabId(definitions, requested) {
  return definitions.find(tab => tab.id === requested || tab.aliases?.includes(requested))?.id
    ?? definitions[0]?.id ?? "dashboard";
}

export function dashboardTabSnapshot(snapshot, definitions, tabId) {
  const tab = definitions.find(tab => tab.id === tabId);
  if (!Array.isArray(tab?.filterIds)) return snapshot;
  return { ...snapshot, filters: (snapshot.filters ?? []).filter(filter => tab.filterIds.includes(filter.id))
    .map(filter => ({ ...filter, defaultValue: tab.defaultFilters?.[filter.id] ?? filter.defaultValue })) };
}

export function dashboardView(snapshot, definitions, tabId, saved = {}, urlState) {
  const scoped = dashboardTabSnapshot(snapshot, definitions, tabId);
  const values = resolveDashboardUrlFilters(scoped, saved.filters, urlState);
  const filters = Object.fromEntries((scoped.filters ?? []).map(filter =>
    [filter.id, validFilterValue(scoped, filter, values[filter.id]) ? values[filter.id] : filter.defaultValue ?? "all"]));
  const focusFields = definitions.find(tab => tab.id === tabId)?.focusFields ?? [];
  const focus = Object.fromEntries(Object.entries((urlState?.complete ? urlState.focus : saved.focus) ?? {}).filter(([key, value]) =>
    focusFields.includes(key) && typeof value === "string" && value.length <= 200));
  return { filters, focus };
}

export function drillDashboardView(snapshot, definitions, tabId, current, payload = {}) {
  // Only declared destination fields are carried, never a whole arbitrary source state.
  const base = dashboardView(snapshot, definitions, tabId, current);
  return dashboardView(snapshot, definitions, tabId, {
    filters: { ...base.filters, ...Object.fromEntries(Object.entries(payload.filters ?? {})
      .filter(([key, value]) => Object.hasOwn(base.filters, key) && (typeof value === "string" || Array.isArray(value)))) },
    focus: payload.focus,
  });
}
