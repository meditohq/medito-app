import { normalizeBlockLayouts, validateBlockLayouts } from "./block-layout.js";
import { canonicalDashboardPath } from "./chart-permalink.js";
import { normalizeDataAppRefreshSchedule } from "./data-app-schedule.js";
import { normalizeChartAnnotations } from "./charting/chart-annotations.js";
import { assertChartSpec } from "./charting/chart-spec-validation.js";

export const presentationVersion = 1;

const maxPresentationBytes = 128_000;
const maxEntries = 500;
const maxTextEntryBytes = 20_000;
const allowedKeys = new Set([
  "theme", "appearance", "title", "description", "hiddenBlocks", "componentTitles", "textEdits",
  "chartOverrides", "filters", "assumptions", "notes", "refreshSchedule", "tabs", "blockLayouts", "verification", "tabViews",
]);
const objectKeys = ["componentTitles", "textEdits", "chartOverrides", "filters", "assumptions", "blockLayouts", "tabViews"];
const reviewedDataKeys = new Set(["rows", "queries", "sourceRows", "displayRows", "sql", "provenance"]);
const appearanceOptions = new Set(["system", "light", "dark"]);

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    && [Object.prototype, null].includes(Object.getPrototypeOf(value));
}

function normalizeVerification(value) {
  if (!plainObject(value) || Object.keys(value).length !== 2
    || Object.keys(value).some((key) => !["verifiedBy", "verifiedAt"].includes(key))) return undefined;
  if (typeof value.verifiedBy !== "string" || typeof value.verifiedAt !== "string") return undefined;
  const verifiedBy = value.verifiedBy.trim().toLowerCase();
  if (verifiedBy.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(verifiedBy)) return undefined;
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u.test(value.verifiedAt)) return undefined;
  const date = new Date(value.verifiedAt);
  if (Number.isNaN(date.valueOf()) || date.toISOString() !== value.verifiedAt) return undefined;
  return { verifiedBy, verifiedAt: value.verifiedAt };
}

function normalizeTabs(value) {
  if (!Array.isArray(value)) return undefined;
  const ids = new Set();
  const tabs = [];
  for (const entry of value.slice(0, 50)) {
    if (!plainObject(entry) || typeof entry.id !== "string" || typeof entry.label !== "string") continue;
    const id = entry.id.trim();
    const label = entry.label.trim();
    if (!id || id.length > 100 || !label || label.length > 100 || ids.has(id)) continue;
    ids.add(id);
    tabs.push({ id, label });
  }
  return tabs.length ? tabs : undefined;
}

export function normalizePresentation(value = {}) {
  if (!plainObject(value)) return {};
  const result = {};
  for (const key of allowedKeys) {
    const current = value[key];
    if (current === undefined || current === null) continue;
    if (key === "appearance") {
      if (appearanceOptions.has(current)) result[key] = current;
    } else if (["theme", "title", "description", "notes"].includes(key)) {
      if (typeof current === "string" && current.trim()) result[key] = current;
    } else if (key === "refreshSchedule") {
      const schedule = normalizeDataAppRefreshSchedule(current);
      if (schedule) result[key] = schedule;
    } else if (key === "verification") {
      const verification = normalizeVerification(current);
      if (verification) result.verification = verification;
    } else if (key === "hiddenBlocks") {
      if (Array.isArray(current)) result[key] = [...new Set(current.filter((entry) =>
        typeof entry === "string" && entry.length <= 200))].slice(0, maxEntries);
    } else if (key === "tabs") {
      const tabs = normalizeTabs(current);
      if (tabs) result.tabs = tabs;
    } else if (key === "blockLayouts") {
      const layouts = normalizeBlockLayouts(current);
      if (Object.keys(layouts).length) result.blockLayouts = layouts;
    } else if (["componentTitles", "textEdits"].includes(key) && plainObject(current)) {
      result[key] = Object.fromEntries(Object.entries(current).filter(([entry, text]) =>
        entry.trim() && entry.length <= 200 && typeof text === "string" && (text.trim() || (key === "textEdits" && text === ""))
          && text.length <= maxTextEntryBytes).slice(0, maxEntries));
    } else if (plainObject(current)) {
      result[key] = Object.fromEntries(Object.entries(current)
        .filter(([entry]) => entry.length <= 200).slice(0, maxEntries));
    }
  }
  return result;
}

export function validatePresentation(value) {
  if (!plainObject(value)) throw new Error("Presentation must be a JSON object.");
  const unexpected = Object.keys(value).filter((key) => !allowedKeys.has(key));
  if (unexpected.length) throw new Error(`Unsupported presentation fields: ${unexpected.join(", ")}.`);
  if (JSON.stringify(value).length > maxPresentationBytes) throw new Error("Presentation exceeds the size limit.");
  if (value.hiddenBlocks !== undefined && (!Array.isArray(value.hiddenBlocks)
    || value.hiddenBlocks.length > maxEntries || value.hiddenBlocks.some((entry) => typeof entry !== "string"))) {
    throw new Error("Hidden blocks must be a bounded list of component IDs.");
  }
  if (value.refreshSchedule !== undefined && !normalizeDataAppRefreshSchedule(value.refreshSchedule)) {
    throw new Error("Refresh schedule must include a valid repeat and any required time and selected days.");
  }
  if (value.verification !== undefined && !normalizeVerification(value.verification)) {
    throw new Error("Verification must contain only a valid creator email and canonical UTC timestamp.");
  }
  if (value.tabs !== undefined && (!Array.isArray(value.tabs) || value.tabs.length === 0 || value.tabs.length > 50
    || value.tabs.some((entry) => !plainObject(entry) || Object.keys(entry).some((key) => !["id", "label"].includes(key))
      || typeof entry.id !== "string" || !entry.id.trim() || entry.id.length > 100
      || typeof entry.label !== "string" || !entry.label.trim() || entry.label.length > 100)
    || new Set(value.tabs.map(({ id }) => id.trim())).size !== value.tabs.length)) {
    throw new Error("Tabs must be a bounded list of unique page IDs and labels.");
  }
  if (value.appearance !== undefined && !appearanceOptions.has(value.appearance)) {
    throw new Error("Appearance must be system, light, or dark.");
  }
  if (value.blockLayouts !== undefined) validateBlockLayouts(value.blockLayouts);
  for (const key of objectKeys) {
    if (value[key] !== undefined && (!plainObject(value[key]) || Object.keys(value[key]).length > maxEntries)) {
      throw new Error(`${key} must be a bounded JSON object.`);
    }
  }
  for (const key of ["componentTitles", "textEdits"]) {
    if (Object.entries(value[key] ?? {}).some(([entry, text]) => !entry.trim() || entry.length > 200
      || typeof text !== "string" || (!text.trim() && !(key === "textEdits" && text === "")) || text.length > maxTextEntryBytes)) {
      throw new Error(`${key} must contain bounded text values${key === "componentTitles" ? " with nonempty titles" : " (empty strings may clear text)"}.`);
    }
  }
  for (const [id, spec] of Object.entries(value.chartOverrides ?? {})) {
    if (!plainObject(spec)) throw new Error("Chart overrides must contain chart configuration objects.");
    if (Object.keys(spec).some((key) => reviewedDataKeys.has(key))) {
      throw new Error("Chart overrides cannot contain reviewed data or provenance.");
    }
    // Older saved presentation-only overrides may omit bindings. Check each provided binding.
    assertChartSpec(spec, { id, partial: true });
    if ("referenceLines" in spec) throw new Error("Chart annotations are not supported.");
    if ("annotations" in spec) normalizeChartAnnotations(spec.annotations);
    if ("showAnnotations" in spec && typeof spec.showAnnotations !== "boolean") {
      throw new Error("Chart annotation visibility must be a boolean.");
    }
  }
  for (const key of ["theme", "title", "description", "notes"]) {
    if (value[key] !== undefined && typeof value[key] !== "string") {
      throw new Error(`${key} must be a string.`);
    }
  }
  return normalizePresentation(value);
}

export function presentationStorageKey(snapshot, pathname = globalThis.location?.pathname ?? "") {
  const dashboardPath = canonicalDashboardPath(pathname);
  return `data-app:presentation:v${presentationVersion}:${dashboardPath}:${snapshot.id ?? snapshot.title ?? "app"}`;
}

function legacyPresentationStorageKey(snapshot) {
  const title = snapshot?.legacyPresentationTitle;
  if (typeof snapshot?.id !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/u.test(snapshot.id)
    || !Object.hasOwn(snapshot, "legacyPresentationTitle") || typeof title !== "string"
    || !title.trim() || title.length > 300 || /[\u0000-\u001f\u007f]/u.test(title)) return undefined;
  // The alias is one exact old title at this artifact's canonical path. Never
  // search other paths, enumerate storage, or infer aliases from the new title.
  return presentationStorageKey({ title });
}

function validLegacyPresentation(value) {
  try {
    if (typeof value !== "string" || value.length > maxPresentationBytes + 4096) return false;
    const record = JSON.parse(value);
    if (!plainObject(record) || record.version !== presentationVersion) return false;
    validatePresentation(record.presentation);
    return true;
  } catch {
    return false;
  }
}

function readIdentityValue(snapshot, storage, suffix, validLegacyValue) {
  const key = `${presentationStorageKey(snapshot)}${suffix}`;
  const current = storage?.getItem(key);
  // Even a corrupt current record wins: recovering an older record must never
  // overwrite newer work or resurrect a preference the reader already cleared.
  if (current !== null && current !== undefined) return current;
  const legacyBase = legacyPresentationStorageKey(snapshot);
  if (!legacyBase || `${legacyBase}${suffix}` === key) return undefined;
  const legacy = storage?.getItem(`${legacyBase}${suffix}`);
  if (!validLegacyValue(legacy)) return undefined;
  const latest = storage?.getItem(key);
  if (latest !== null && latest !== undefined) return latest;
  try { storage?.setItem(key, legacy); } catch { /* Read-only storage can still preserve the current view. */ }
  return legacy;
}

export function normalizeAppearance(value, fallback = "system") {
  return appearanceOptions.has(value) ? value : fallback;
}

export function readViewerAppearance(snapshot, storage) {
  try {
    if (storage === undefined) storage = globalThis.localStorage;
    const value = readIdentityValue(snapshot, storage, ":viewer-appearance", (value) => appearanceOptions.has(value));
    return appearanceOptions.has(value) ? value : "";
  } catch {
    return "";
  }
}

export function writeViewerAppearance(snapshot, value, storage) {
  try {
    if (storage === undefined) storage = globalThis.localStorage;
    const key = `${presentationStorageKey(snapshot)}:viewer-appearance`;
    if (appearanceOptions.has(value)) storage?.setItem(key, value);
    // Keep an explicit reset when a retained legacy key could otherwise restore
    // its old preference on the next read.
    else if (legacyPresentationStorageKey(snapshot)) storage?.setItem(key, "");
    else storage?.removeItem(key);
    return true;
  } catch {
    return false;
  }
}

export function readLocalPresentation(snapshot, storage) {
  try {
    if (storage === undefined) storage = globalThis.localStorage;
    const value = readIdentityValue(snapshot, storage, "", validLegacyPresentation);
    const record = JSON.parse(value ?? "null");
    return record?.version === presentationVersion ? normalizePresentation(record.presentation) : {};
  } catch {
    return {};
  }
}

export function writeLocalPresentation(snapshot, presentation, storage) {
  try {
    const normalized = validatePresentation(presentation);
    if (storage === undefined) storage = globalThis.localStorage;
    storage?.setItem(presentationStorageKey(snapshot), JSON.stringify({
      version: presentationVersion, updatedAt: new Date().toISOString(), presentation: normalized,
    }));
    return true;
  } catch {
    return false;
  }
}

function mergeBlockLayout(previous, next, latest) {
  if (!previous || !latest || JSON.stringify(previous) === JSON.stringify(latest)) return next;
  if (JSON.stringify(previous) === JSON.stringify(next)) return latest;
  const previousRevision = previous.authoredRevision ?? 1;
  const nextRevision = next.authoredRevision ?? 1;
  const latestRevision = latest.authoredRevision ?? 1;
  if (nextRevision !== latestRevision && Math.max(nextRevision, latestRevision) > previousRevision) {
    return nextRevision > latestRevision ? next : latest;
  }

  const previousPositions = new Map(previous.order.map((id, index) => [id, index]));
  const tails = [];
  const links = new Map();
  for (const id of next.order) {
    const position = previousPositions.get(id);
    if (position === undefined) continue;
    let low = 0;
    let high = tails.length;
    while (low < high) {
      const middle = Math.floor((low + high) / 2);
      if (previousPositions.get(tails[middle]) < position) low = middle + 1;
      else high = middle;
    }
    links.set(id, low > 0 ? tails[low - 1] : undefined);
    tails[low] = id;
  }
  const stable = new Set();
  for (let id = tails.at(-1); id !== undefined; id = links.get(id)) stable.add(id);
  const locallyRemoved = new Set(previous.order.filter((id) => !next.order.includes(id)));
  const moved = new Set(next.order.filter((id) => !stable.has(id)));
  const mergedOrder = latest.order.filter((id) => !locallyRemoved.has(id));

  for (const [index, id] of next.order.entries()) {
    if (!moved.has(id)) continue;
    const existing = mergedOrder.indexOf(id);
    if (existing >= 0) mergedOrder.splice(existing, 1);
    const after = next.order.slice(index + 1)
      .find((candidate) => stable.has(candidate) && mergedOrder.includes(candidate));
    const before = after === undefined ? next.order.slice(0, index).reverse()
      .find((candidate) => mergedOrder.includes(candidate)) : undefined;
    const destination = after !== undefined ? mergedOrder.indexOf(after)
      : before !== undefined ? mergedOrder.indexOf(before) + 1 : mergedOrder.length;
    mergedOrder.splice(destination, 0, id);
  }

  const result = { order: mergedOrder,
    ...(next.authoredRevision !== undefined || latest.authoredRevision !== undefined
      ? { authoredRevision: Math.max(nextRevision, latestRevision) } : {}),
  };
  for (const field of ["spans", "preferredSpans", "soloSpans"]) {
    if (!next[field] && !latest[field]) continue;
    const values = { ...(latest[field] ?? {}) };
    for (const id of previous.order) {
      if (previous[field]?.[id] !== next[field]?.[id]) {
        if (next[field]?.[id] === undefined) delete values[id];
        else values[id] = next[field][id];
      }
    }
    for (const [id, value] of Object.entries(next[field] ?? {})) {
      if (!previousPositions.has(id)) values[id] = value;
    }
    for (const id of Object.keys(values)) {
      if (!mergedOrder.includes(id)) delete values[id];
    }
    if (Object.keys(values).length) result[field] = values;
  }

  if (next.rows || latest.rows) {
    const previousRows = new Map((previous.rows ?? []).flatMap((row) => row.items.map((id) => [id, row.id])));
    const nextRows = new Map((next.rows ?? []).flatMap((row) => row.items.map((id) => [id, row.id])));
    const rows = (latest.rows ?? []).map(({ id, items }) => ({
      id, items: items.filter((itemId) => mergedOrder.includes(itemId)),
    }));
    for (const [id, rowId] of nextRows) {
      if (previousRows.get(id) === rowId && rows.some((row) => row.items.includes(id))) continue;
      for (const row of rows) row.items = row.items.filter((itemId) => itemId !== id);
      let destination = rows.find((row) => row.id === rowId);
      if (!destination) {
        destination = { id: rowId, items: [] };
        const authoredIndex = (next.rows ?? []).findIndex((row) => row.id === rowId);
        const following = (next.rows ?? []).slice(authoredIndex + 1)
          .find((row) => rows.some((existing) => existing.id === row.id));
        rows.splice(following ? rows.findIndex((row) => row.id === following.id) : rows.length, 0, destination);
      }
      destination.items.push(id);
    }
    const positions = new Map(mergedOrder.map((id, index) => [id, index]));
    result.rows = rows.filter((row) => row.items.length)
      .map(({ id, items }) => ({ id, items: items.sort((left, right) => positions.get(left) - positions.get(right)) }));
    result.order = result.rows.flatMap(({ items }) => items);
  }
  return result;
}

function applyPresentationChanges(previous, next, latest, includeBlockLayouts = true) {
  const result = { ...latest };
  for (const key of allowedKeys) {
    if (key === "blockLayouts" && !includeBlockLayouts) continue;
    if (JSON.stringify(previous?.[key]) === JSON.stringify(next?.[key])) continue;
    if (next?.[key] === undefined) delete result[key];
    else if (objectKeys.includes(key)) {
      const changed = {};
      for (const [entry, value] of Object.entries(next[key])) {
        if (JSON.stringify(previous?.[key]?.[entry]) !== JSON.stringify(value)) {
          changed[entry] = key === "blockLayouts"
            ? mergeBlockLayout(previous?.[key]?.[entry], value, latest?.[key]?.[entry]) : value;
        }
      }
      result[key] = { ...(latest?.[key] ?? {}), ...changed };
      for (const entry of Object.keys(previous?.[key] ?? {})) {
        if (!Object.hasOwn(next[key], entry)) delete result[key][entry];
      }
    } else result[key] = next[key];
  }
  return result;
}

export function mergePresentationChanges(previous, next, latest, pending = []) {
  let result = applyPresentationChanges(previous, next, normalizePresentation(latest));
  // A field may match the acknowledged baseline because a newer draft undid
  // an in-flight edit. Apply those reversions alongside other local changes.
  // Layout edit sessions save once; preserve their existing structural merge.
  for (const baseline of pending) result = applyPresentationChanges(baseline, next, result, false);
  return validatePresentation(result);
}
// Session undo history deliberately excludes filters, verification, queries and source data.
export const editablePresentationKeys = ["theme", "appearance", "title", "hiddenBlocks", "componentTitles",
  "textEdits", "chartOverrides", "blockLayouts", "tabs"];

export function editHistoryValue(presentation) {
  return JSON.stringify(Object.fromEntries(editablePresentationKeys
    .filter((key) => Object.hasOwn(presentation, key)).map((key) => [key, presentation[key]])));
}

// Only presentation edits are provisional. Personal filters and authoritative
// verification keep their existing persistence and permission boundaries.
export function presentationBeforeEdits(presentation, baseline) {
  const result = { ...presentation };
  for (const key of editablePresentationKeys) {
    if (Object.hasOwn(baseline, key)) result[key] = baseline[key];
    else delete result[key];
  }
  return result;
}

export function recordPresentationEdit(history, value, enabled = true) {
  if (history.entries[history.index] === value) return history;
  if (!enabled) return { entries: [value], index: 0 };
  const entries = [...history.entries.slice(0, history.index + 1), value].slice(-101);
  return { entries, index: entries.length - 1 };
}
