import { isTemporalField } from "./source-provenance.js";

const filterParameterPrefix = "f.";
const maximumFilterIdLength = 200;
// A view contains selections, never reviewed rows. Keep each parameter bounded
// while permitting large reviewed multi-select sets without the old 100-item cap.
const maximumFilterValueLength = 65_536;
const maximumMapEntries = 2_048;
const auxiliaryParameters = { a: "assumptions", s: "sections", c: "charts", t: "tabViews", focus: "focus" };
const reservedParameters = new Set(["view", "tab", ...Object.keys(auxiliaryParameters)]);
const unsafeKeys = new Set(["__proto__", "prototype", "constructor"]);
const safeKey = value => typeof value === "string" && value.length > 0
  && value.length <= maximumFilterIdLength && !unsafeKeys.has(value) && !/[\u0000-\u001f\u007f]/u.test(value);
const plainObject = value => value !== null && typeof value === "object" && !Array.isArray(value)
  && [Object.prototype, null].includes(Object.getPrototypeOf(value));
let encoder;
function safeString(value) {
  // Metadata extraction imports this module without web globals or URL validation.
  return typeof value === "string" && value.length <= maximumFilterValueLength
    && (encoder ??= new TextEncoder()).encode(value).length <= maximumFilterValueLength;
}
const scalar = value => safeString(value) || typeof value === "boolean"
  || typeof value === "number" && Number.isFinite(value);
const selection = value => scalar(value) || Array.isArray(value)
  && value.length <= maximumFilterValueLength && value.every(scalar);

function oversizedView() {
  const error = new RangeError("This dashboard view is too large to share in a link.");
  error.code = "DATA_APP_VIEW_TOO_LARGE";
  return error;
}

function assertParameterSize(value) {
  let serialized;
  try { serialized = typeof value === "string" ? value : JSON.stringify(value); }
  catch { return; } // Invalid shapes are rejected by the schema checks below.
  if (!safeString(serialized)) throw oversizedView();
  const checkMap = item => {
    if (!plainObject(item)) return;
    if (Object.keys(item).length > maximumMapEntries) throw oversizedView();
    Object.values(item).forEach(checkMap);
  };
  if (typeof value !== "string") checkMap(value);
}

function checkedMap(value, accept) {
  if (!plainObject(value)) return null;
  const entries = Object.entries(value);
  if (entries.length > maximumMapEntries || entries.some(([key, item]) => !safeKey(key) || !accept(item))) return null;
  return Object.fromEntries(entries.sort(([left], [right]) => left.localeCompare(right)));
}

function auxiliaryValue(name, value) {
  if (name === "a") return checkedMap(value, item => typeof item === "number" && Number.isFinite(item));
  if (name === "focus") return checkedMap(value, safeString);
  if (name === "s") {
    const sections = checkedMap(value, item => checkedMap(item, selection) !== null);
    return sections && Object.fromEntries(Object.entries(sections).map(([id, filters]) => [id, checkedMap(filters, selection)]));
  }
  if (name === "t") {
    const views = checkedMap(value, item => plainObject(item) && Object.keys(item).every(key =>
      key === "filters" ? checkedMap(item[key], selection) !== null
        : key === "focus" ? checkedMap(item[key], safeString) !== null : false));
    return views && Object.fromEntries(Object.entries(views).map(([id, view]) => [id, {
      ...(view.filters && Object.keys(view.filters).length ? { filters: checkedMap(view.filters, selection) } : {}),
      ...(view.focus && Object.keys(view.focus).length ? { focus: checkedMap(view.focus, safeString) } : {}),
    }]));
  }
  if (name !== "c") return null;
  const charts = checkedMap(value, item => plainObject(item) && Object.keys(item).every(key => {
    if (!["inlineFilters", "visibleSeries", "zoomRange"].includes(key)) return false;
    if (item[key] == null) return true;
    if (key === "inlineFilters") return checkedMap(item[key], selection) !== null;
    if (key === "visibleSeries") return Array.isArray(item[key]) && item[key].every(safeString);
    return plainObject(item[key]) && Object.keys(item[key]).length === 2
      && Object.hasOwn(item[key], "start") && Object.hasOwn(item[key], "end")
      && scalar(item[key].start) && scalar(item[key].end);
  }));
  return charts && Object.fromEntries(Object.entries(charts).map(([id, chart]) => [id, {
    ...(chart.inlineFilters && Object.keys(chart.inlineFilters).length
      ? { inlineFilters: checkedMap(chart.inlineFilters, selection) } : {}),
    ...(chart.visibleSeries ? { visibleSeries: [...new Set(chart.visibleSeries)].sort() } : {}),
    ...(chart.zoomRange ? { zoomRange: { start: chart.zoomRange.start, end: chart.zoomRange.end } } : {}),
  }]));
}

function parseAuxiliary(name, value) {
  if (!safeString(value)) return null;
  try { return auxiliaryValue(name, JSON.parse(value)); } catch { return null; }
}

const emptyState = () => ({ tab: null, filters: {}, hasViewState: false, complete: false,
  assumptions: {}, sections: {}, charts: {}, tabViews: {}, focus: {} });

function shareableFilterDefinitions(snapshot, complete = false) {
  return (snapshot?.filters ?? [])
    .filter(({ id, shareInUrl }) => safeKey(id) && (complete || shareInUrl !== false))
    .sort((left, right) => left.id.localeCompare(right.id));
}

function rowFilterChoice(row, field) {
  const value = row?.[field];
  return value !== undefined && value !== null && String(value).length > 0 ? String(value) : null;
}

/** Keep exact choices per query so explicit queryIds retain their eager ordering. */
export function createDashboardFilterChoicesAccumulator(filters = []) {
  const entries = new Map();
  for (const filter of filters) {
    if (typeof filter.id !== "string" || entries.has(filter.id)) {
      throw new Error("On-demand query loading requires unique string filter IDs.");
    }
    entries.set(filter.id, { filter, queries: new Map() });
  }
  return {
    addRow(queryId, row) {
      for (const { filter, queries } of entries.values()) {
        if (Array.isArray(filter.queryIds) && !filter.queryIds.includes(queryId)) continue;
        const choice = rowFilterChoice(row, filter.field);
        if (choice === null) continue;
        if (!queries.has(queryId)) queries.set(queryId, new Set());
        queries.get(queryId).add(choice);
      }
    },
    finish() {
      return Object.fromEntries([...entries].map(([id, { filter, queries }]) => {
        const ids = Array.isArray(filter.queryIds) ? filter.queryIds : [...queries.keys()];
        return [id, [...new Set(ids.flatMap(queryId => [...(queries.get(queryId) ?? [])]))]];
      }));
    },
  };
}

function filterChoices(snapshot, filter) {
  const metadata = snapshot?._dataAppQueryLoading;
  if (metadata?.version === 1 && Object.hasOwn(metadata.filterChoices ?? {}, filter.id)) {
    return new Set(metadata.filterChoices[filter.id]);
  }
  const queries = Array.isArray(filter.queryIds)
    ? filter.queryIds.map((id) => snapshot?.queries?.[id]).filter(Boolean)
    : Object.values(snapshot?.queries ?? {});
  return new Set(queries.flatMap(({ rows = [] }) => rows
    .map(row => rowFilterChoice(row, filter.field)).filter(value => value !== null)));
}

export function validFilterValue(snapshot, filter, value) {
  if (Array.isArray(value)) {
    if (!filter.multiple || isTemporalField(filter.field, filter.type ?? filter.valueType)
      || !value.every(item => typeof item === "string" && item !== "all")
      || !safeString(JSON.stringify(value))) return false;
    const choices = filterChoices(snapshot, filter);
    return value.every(item => choices.has(item));
  }
  if (!safeString(value)) return false;
  if (value !== "all") {
    const choices = filterChoices(snapshot, filter);
    if (filter.mode === "through" && /^\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}$/.test(value)) {
      const [start, end] = value.split("..");
      const validDay = day => /^\d{4}-\d{2}-\d{2}$/.test(day) && Number.isFinite(Date.parse(day))
        && new Date(day).toISOString().slice(0, 10) === day;
      const dates = [...choices].filter(validDay).sort();
      // Calendar presets can start or end between sparse observations. Preserve
      // their exact scope while keeping both boundaries inside reviewed coverage.
      return validDay(start) && validDay(end) && start <= end && dates.length > 0
        && start >= dates[0] && end <= dates.at(-1);
    }
    return choices.has(value);
  }
  return !isTemporalField(filter.field, filter.type ?? filter.valueType)
    || !filter.defaultValue || filter.defaultValue === "all";
}

function locationUrl(location) {
  try {
    return new URL(typeof location === "string" ? location : location?.href ?? "");
  } catch {
    return null;
  }
}

export function readDashboardUrlState(snapshot, tabs = [], location = globalThis.location) {
  const url = locationUrl(location);
  if (!url) return emptyState();
  const complete = url.searchParams.getAll("view").length === 1 && url.searchParams.get("view") === "1";

  const requestedTabs = url.searchParams.getAll("tab");
  const requestedTab = requestedTabs.length === 1 ? requestedTabs[0] : null;
  const tab = safeKey(requestedTab) && tabs.some(({ id }) => id === requestedTab) ? requestedTab : null;
  const filterEntries = [];

  for (const filter of shareableFilterDefinitions(snapshot, complete)) {
    const parameter = `${filterParameterPrefix}${filter.id}`;
    if (!url.searchParams.has(parameter)) continue;
    const values = url.searchParams.getAll(parameter);
    if (values.length !== 1 || !safeString(values[0])) continue;
    let value = values[0];
    if (filter.multiple && value.startsWith("[")) {
      try { value = JSON.parse(value); } catch { continue; }
    }
    if (!validFilterValue(snapshot, filter, value)) continue;
    filterEntries.push([filter.id, value]);
  }

  const state = { ...emptyState(), tab, filters: Object.fromEntries(filterEntries), complete,
    hasViewState: complete || tab !== null || filterEntries.length > 0 };
  if (complete) {
    for (const [parameter, property] of Object.entries(auxiliaryParameters)) {
      const values = url.searchParams.getAll(parameter);
      if (values.length === 1) state[property] = parseAuxiliary(parameter, values[0]) ?? {};
    }
  }
  return state;
}

export function resolveDashboardUrlFilters(snapshot, localFilters = {}, state, { reset = false } = {}) {
  if (!state?.hasViewState && !reset) return { ...localFilters };

  const resolved = new Map(Object.entries(localFilters));
  for (const filter of shareableFilterDefinitions(snapshot, state?.complete)) {
    resolved.set(filter.id, Object.hasOwn(state?.filters ?? {}, filter.id)
      ? state.filters[filter.id] : filter.defaultValue ?? "all");
  }
  return Object.fromEntries(resolved);
}

export function serializeDashboardUrlState(snapshot, tabs = [], state = {}) {
  const { tab, filters = {} } = state;
  // Even an entirely default view must override a recipient's remembered choices.
  const parameters = new URLSearchParams({ view: "1" });
  if (safeKey(tab) && tabs.some(({ id }) => id === tab)) {
    parameters.set("tab", tab);
  }

  for (const filter of shareableFilterDefinitions(snapshot, true)) {
    const value = filters[filter.id];
    const encode = selection => Array.isArray(selection)
      ? JSON.stringify([...new Set(selection)].sort()) : String(selection);
    const defaultValue = filter.defaultValue ?? "all";
    if (value === undefined || encode(value) === encode(defaultValue)) continue;
    const encoded = encode(value);
    assertParameterSize(encoded);
    if (!validFilterValue(snapshot, filter, value)) continue;
    parameters.set(`${filterParameterPrefix}${filter.id}`, encoded);
  }

  for (const [parameter, property] of Object.entries(auxiliaryParameters)) {
    const supplied = state[property] ?? {};
    if (plainObject(supplied) && Object.keys(supplied).length) assertParameterSize(supplied);
    let value = auxiliaryValue(parameter, supplied);
    if (!value) continue;
    if (parameter === "a") value = Object.fromEntries(Object.entries(value).filter(([, number]) => number !== 0));
    if (parameter === "s") value = Object.fromEntries(Object.entries(value).filter(([, filters]) => Object.keys(filters).length));
    if (parameter === "c" || parameter === "t") value = Object.fromEntries(Object.entries(value).filter(([, chart]) => Object.keys(chart).length));
    if (!Object.keys(value).length) continue;
    const serialized = JSON.stringify(value);
    if (safeString(serialized)) parameters.set(parameter, serialized);
  }
  return parameters;
}

// Handoffs know the URL but not necessarily the reviewed snapshot. Preserve only
// this view contract; tokens, task identity, and unrelated browser state stay out.
export function dashboardViewSearchParams(location) {
  const url = locationUrl(location);
  const parameters = new URLSearchParams();
  if (!url) return parameters;
  const complete = url.searchParams.getAll("view").length === 1 && url.searchParams.get("view") === "1";
  if (complete) parameters.set("view", "1");
  for (const key of new Set(url.searchParams.keys())) {
    const values = url.searchParams.getAll(key);
    if (values.length !== 1 || !safeString(values[0])) continue;
    const value = values[0];
    if (key === "tab" && safeKey(value)) parameters.set(key, value);
    else if (key.startsWith(filterParameterPrefix) && safeKey(key.slice(filterParameterPrefix.length))) {
      // Without the declaration, a value starting with "[" could be a literal
      // categorical label or a multi-select array. The dashboard validates it.
      parameters.set(key, value);
    } else if (complete && Object.hasOwn(auxiliaryParameters, key)) {
      const parsed = parseAuxiliary(key, value);
      if (parsed !== null) parameters.set(key, JSON.stringify(parsed));
    }
  }
  return parameters;
}

export function dashboardUrlWithState(location, snapshot, tabs, state, { preserveExisting = true } = {}) {
  const url = locationUrl(location);
  if (!url) return null;

  if (!preserveExisting) {
    url.username = "";
    url.password = "";
    url.search = "";
    url.hash = "";
  } else {
    for (const key of [...url.searchParams.keys()]) {
      if (reservedParameters.has(key) || key.startsWith(filterParameterPrefix)) url.searchParams.delete(key);
    }
  }

  for (const [key, value] of serializeDashboardUrlState(snapshot, tabs, state)) {
    url.searchParams.set(key, value);
  }
  return url;
}
