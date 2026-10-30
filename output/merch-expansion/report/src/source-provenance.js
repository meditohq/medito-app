function values(...collections) {
  return [...new Set(collections.flat().filter((value) => typeof value === "string" && value.trim()))];
}

function reviewedRowIdentity(row) {
  return JSON.stringify(row, (_key, value) => value && typeof value === "object" && !Array.isArray(value)
    ? Object.fromEntries(Object.keys(value).sort().map((key) => [key, value[key]])) : value);
}

export function reviewedNarrativeQueries({ id, kind, chart, queryId, queryIds, sourceRowsByQuery, displayRows }, queries) {
  if (queryIds !== undefined && !Array.isArray(queryIds)) {
    throw new Error(`DataComponent "${id}" requires reviewed queryIds to be an array.`);
  }
  const ids = [...new Set([queryId, ...(queryIds ?? [])])];
  if (ids.some((candidate) => typeof candidate !== "string" || !candidate.trim())) {
    throw new Error(`DataComponent "${id}" requires non-empty reviewed query ids.`);
  }
  // Multiple sources describe provenance, not an implicit join. Quantitative
  // components must supply the rows they actually display, including empty scope.
  if (ids.length > 1 && (chart || !["narrative", "custom"].includes(kind)) && !Array.isArray(displayRows)) {
    throw new Error(`DataComponent "${id}" requires explicit displayRows when combining multiple reviewed queries.`);
  }
  for (const candidate of ids) {
    if (queries && (!Object.hasOwn(queries, candidate) || !queries[candidate])) {
      throw new Error(`DataComponent "${id}" references missing reviewed query "${candidate}".`);
    }
  }
  if (sourceRowsByQuery !== undefined) {
    if (!sourceRowsByQuery || typeof sourceRowsByQuery !== "object" || Array.isArray(sourceRowsByQuery)) {
      throw new Error(`DataComponent "${id}" requires sourceRowsByQuery to map reviewed query ids to rows.`);
    }
    for (const [candidate, rows] of Object.entries(sourceRowsByQuery)) {
      if (!ids.includes(candidate)) {
        throw new Error(`DataComponent "${id}" scopes rows for undeclared reviewed query "${candidate}".`);
      }
      if (!Array.isArray(rows)) {
        throw new Error(`DataComponent "${id}" requires an array of scoped rows for reviewed query "${candidate}".`);
      }
      if (queries) {
        const reviewedRows = queries[candidate]?.rows ?? [];
        if (rows === reviewedRows || rows.length === 0) continue;
        // Filtered snapshot rows already prove membership by reference. Rebuild
        // this set each call so in-place edits/removals cannot leave stale scope.
        const references = new Set(reviewedRows);
        const copiedRows = rows.filter((row) => !references.has(row));
        if (copiedRows.length === 0) continue;
        // Authored copies still need the same complete, key-order-independent
        // value comparison as before; never substitute derived display values.
        const reviewed = new Set(reviewedRows.map(reviewedRowIdentity));
        if (copiedRows.some((row) => !reviewed.has(reviewedRowIdentity(row)))) {
          throw new Error(`DataComponent "${id}" includes non-reviewed rows for query "${candidate}".`);
        }
      }
    }
  }
  return ids;
}

export function reviewedQueryLabel(query, queryId) {
  return query?.label ?? query?.title ?? query?.source?.label
    ?? query?.source?.query?.description ?? queryId;
}

export function reviewedRowsAsTsv(rows = []) {
  const columns = [...new Set(rows.flatMap(Object.keys))];
  return [columns.join("\t"), ...rows.map((row) => columns.map((column) =>
    String(row[column] ?? "").replace(/[\t\n\r]/gu, " ")).join("\t"))].join("\n");
}

export function reviewedComponentClipboard(component, queries, getRows) {
  const queryIds = component.queryIds?.length > 1 ? component.queryIds : [component.queryId];
  if (queryIds.length === 1) return reviewedRowsAsTsv(getRows(queryIds[0]));
  return queryIds.map((queryId) => `${reviewedQueryLabel(queries[queryId], queryId)}\n`
    + reviewedRowsAsTsv(getRows(queryId))).join("\n\n");
}

export function isTemporalField(field, type) {
  if (/^(?:date|datetime|timestamp|time)$/iu.test(String(type ?? ""))) return true;
  return String(field ?? "").replace(/([a-z\d])([A-Z])/gu, "$1_$2")
    .split(/[^a-z\d]+/iu)
    .some((token) => /^(?:date|day|week|month|quarter|year|period|time|timestamp|datetime)$/iu.test(token));
}

export function formatReviewedSql(sql) {
  if (!sql) return "No reviewed SQL provided.";
  const protectedTokens = [];
  const masked = String(sql).trim()
    .replace(/'(?:''|[^'])*'|"(?:""|[^"])*"|`(?:``|[^`])*`|--[^\r\n]*(?:\r?\n|$)|\/\*[\s\S]*?\*\//gu,
      (token) => `\u0000${protectedTokens.push(token) - 1}\u0000`);
  return masked.replace(/\s+/gu, " ")
    .replace(/^SELECT\s+/iu, "SELECT\n  ")
    .replace(/,\s*/gu, ",\n  ")
    .replace(/\s+(FROM|WHERE|GROUP BY|ORDER BY|HAVING|LIMIT|LEFT JOIN|RIGHT JOIN|INNER JOIN|JOIN)\s+/giu,
      "\n$1\n  ")
    .replace(/\s+(AND|OR)\s+/giu, "\n  $1 ")
    .replace(/\u0000(\d+)\u0000/gu, (_, index) => protectedTokens[Number(index)]);
}

export function reviewedDateRange(rows = [], { component, query, filters = [] } = {}) {
  const isDate = (value) => typeof value === "string" && /^\d{4}-\d{2}-\d{2}(?:T|$)/u.test(value)
    && Number.isFinite(Date.parse(value));
  const columns = [...new Set(rows.flatMap((row) => Object.keys(row)))];
  const containsDates = (field) => columns.includes(field) && rows.some((row) => isDate(row[field]));
  const metadataFields = [query?.reportingField, query?.dateField, query?.timeField,
    query?.source?.reportingField, query?.source?.dateField, query?.source?.timeField,
    query?.source?.query?.reportingField, query?.source?.query?.dateField,
    component?.reportingField, component?.dateField, component?.chart?.x];
  let field = metadataFields.find(containsDates);
  if (!field) {
    const filterFields = [...new Set(filters.filter(({ field: candidate, type, queryIds }) =>
      (!Array.isArray(queryIds) || queryIds.includes(component?.queryId))
      && isTemporalField(candidate, type) && containsDates(candidate)).map(({ field: candidate }) => candidate))];
    if (filterFields.length === 1) [field] = filterFields;
  }
  if (!field) {
    const dateFields = columns.filter((candidate) => isTemporalField(candidate) && containsDates(candidate));
    if (dateFields.length !== 1) return "";
    [field] = dateFields;
  }
  const dates = [...new Set(rows.map((row) => row[field]).filter(isDate))].sort();
  if (!dates.length) return "";
  const formatter = new Intl.DateTimeFormat(undefined, {
    month: "short", day: "numeric", year: "numeric", timeZone: "UTC",
  });
  const first = formatter.format(new Date(dates[0]));
  const last = formatter.format(new Date(dates.at(-1)));
  return first === last ? first : `${first} – ${last}`;
}

export function safeSourceHref(value) {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    if (!["http:", "https:"].includes(url.protocol)
      || url.username || url.password || url.search || url.hash) return null;

    let pathname = url.pathname;
    for (let depth = 0; depth < 8; depth += 1) {
      pathname = decodeURIComponent(pathname);
      if (!/%[a-f\d]{2}/iu.test(pathname)) break;
      if (depth === 7) return null;
    }
    if (/(?:^|\/)(?:bearer|tokens?|access[_-]?tokens?|api[_-]?keys?|password|passwd|secrets?|credentials?|signatures?|sig|signed(?:url)?|x[_-]?(?:amz|goog)[_-]?signature)(?:\/|[=:_-]|$)/iu.test(pathname)
      || /[?#]|%(?:25)*(?:3f|23)/iu.test(pathname)
      || /(?:^|[;/])(?:j|php)?sess(?:ion)?id\s*=/iu.test(pathname)
      || /(?:^|\/)eyj[a-z\d_-]+\.eyj[a-z\d_-]+\.[a-z\d_-]+(?:\/|$)/iu.test(pathname)) {
      return null;
    }
    return url.href;
  } catch {
    return null;
  }
}

function queryLinkProvider(hostname) {
  if (hostname === "app.snowflake.com") return "Snowflake";
  if (["cloud.databricks.com", "azuredatabricks.net", "gcp.databricks.com"]
    .some((domain) => hostname.endsWith(`.${domain}`))) return "Databricks";
  return null;
}

// Query links retain only recorded destinations. Provider route parameters are
// locators, never a way to embed SQL, credentials, or arbitrary navigation state.
function providerQueryLink(value, explicit) {
  if (typeof value !== "string" || !value || value.length > 4096 || /[\s\\]/u.test(value)) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || url.port
      || !safeSourceHref(`${url.origin}${url.pathname}`)) return null;
    const provider = queryLinkProvider(url.hostname);
    if (!provider) return explicit && safeSourceHref(value) ? { href: value, label: "Open query" } : null;
    const uuid = "[a-f\\d]{8}-[a-f\\d]{4}-[a-f\\d]{4}-[a-f\\d]{4}-[a-f\\d]{12}";
    if (provider === "Databricks") {
      const isHistory = /^\/sql\/history\/?$/u.test(url.pathname);
      const allowed = isHistory ? { o: /^\d{1,30}$/u, queryId: new RegExp(`^${uuid}$`, "iu") }
        : { o: /^\d{1,30}$/u };
      const seen = new Set();
      for (const [key, locator] of url.searchParams) {
        if (!Object.hasOwn(allowed, key) || !allowed[key].test(locator) || seen.has(key)) return null;
        seen.add(key);
      }
      const route = new RegExp(`^/sql/(?:editor/(?:\\d{1,30}|${uuid})|queries/${uuid})/?$`, "iu");
      const legacyRoute = new RegExp(`^#/?(?:sql/queries|query)/${uuid}/?$`, "iu");
      if (!(route.test(url.pathname) && !url.hash
        || isHistory && seen.has("queryId") && !url.hash
        || url.pathname === "/" && legacyRoute.test(url.hash))) return null;
    } else {
      if (url.search) return null;
      const account = "[a-z\\d_-]{1,128}/[a-z\\d_-]{1,128}";
      const worksheet = "[a-z\\d_-]{1,128}";
      const history = new RegExp(`^#/compute/history/queries/${uuid}/(?:detail|profile)/?$`, "iu");
      const worksheetRoute = new RegExp(`^#/worksheets/${worksheet}/?$`, "iu");
      const sharedWorksheet = new RegExp(`^/${account}/(?:ws|worksheets)/${worksheet}/?$`, "iu");
      if (!(new RegExp(`^/${account}/?$`, "iu").test(url.pathname)
        && (history.test(url.hash) || worksheetRoute.test(url.hash))
        || sharedWorksheet.test(url.pathname) && !url.hash)) return null;
      // Apply the normal path checks to the fragment route as well.
      if (url.hash && !safeSourceHref(`${url.origin}/${url.hash.slice(1).replace(/^\//u, "")}`)) return null;
    }
    return { href: value, label: `Open in ${provider}` };
  } catch {
    return null;
  }
}

export function reviewedQueryLink(source = {}) {
  if (!source || typeof source !== "object" || Array.isArray(source)) return null;
  const query = source.query && typeof source.query === "object" && !Array.isArray(source.query) ? source.query : {};
  const explicit = [source.queryUrl, source.query_url, query.queryUrl, query.query_url, query.url];
  for (const value of explicit) {
    const link = providerQueryLink(value, true);
    if (link) return link;
  }
  const candidates = [source.url, source.href, ...(Array.isArray(source.links) ? source.links : []),
    ...(Array.isArray(query.links) ? query.links : [])];
  for (const entry of candidates) {
    const link = providerQueryLink(typeof entry === "string" ? entry : entry?.href ?? entry?.url, false);
    if (link) return link;
  }
  return null;
}

function sourceLinks(...collections) {
  const reviewed = new Map();
  for (const entry of collections.flat()) {
    const href = safeSourceHref(typeof entry === "string" ? entry : entry?.href ?? entry?.url);
    if (!href) continue;
    const label = typeof entry !== "string" && typeof entry?.label === "string" ? entry.label.trim() : "";
    const trust = typeof entry === "string" ? null : reviewedTrust(entry?.trust ?? entry?.trustSignals);
    const kind = typeof entry !== "string" && entry?.kind === "dashboard" ? "dashboard" : null;
    const existing = reviewed.get(href);
    const existingRecord = typeof existing === "string" ? {} : existing ?? {};
    const nextLabel = existingRecord.label || label;
    const nextTrust = existingRecord.trust ?? trust;
    const nextKind = existingRecord.kind ?? kind;
    reviewed.set(href, nextLabel || nextTrust || nextKind
      ? { href, ...(nextLabel ? { label: nextLabel } : {}), ...(nextTrust ? { trust: nextTrust } : {}),
        ...(nextKind ? { kind: nextKind } : {}) }
      : href);
  }
  return [...reviewed.values()];
}

function reviewedUsageTimestamp(value) {
  if (typeof value !== "string") return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})T(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d+)?)?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$/u.exec(value);
  if (!match || !Number.isFinite(Date.parse(value))) return null;
  const [year, month, day] = match.slice(1).map(Number);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];
  return day >= 1 && day <= daysInMonth ? value : null;
}

function reviewedTrust(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const trust = {};
  if (typeof value.provider === "string" && value.provider.trim()) trust.provider = value.provider.trim();
  for (const [name, alias] of [
    ["uniqueUsers", "unique_users"], ["uniqueViewers", "unique_viewers"],
    ["queryCount", "query_count"], ["viewCount", "view_count"],
    ["favoriteCount", "favorite_count"], ["windowDays", "window_days"],
  ]) {
    const count = value[name] ?? value[alias];
    if (Number.isSafeInteger(count) && count >= (name === "windowDays" ? 1 : 0)) trust[name] = count;
  }
  const editedAt = value.editedAt ?? value.edited_at;
  if (typeof editedAt === "string" && Number.isFinite(Date.parse(editedAt))) trust.editedAt = editedAt;
  for (const [name, alias] of [["lastQueriedAt", "last_queried_at"], ["usageAsOf", "usage_as_of"]]) {
    const timestamp = reviewedUsageTimestamp(value[name] ?? value[alias]);
    if (timestamp) trust[name] = timestamp;
  }
  const usageNote = value.usageNote ?? value.usage_note;
  if (typeof usageNote === "string" && usageNote.trim()) trust.usageNote = usageNote.trim();
  if (value.verified === true) trust.verified = true;
  return Object.keys(trust).length ? trust : null;
}

export function sourceTrustLabels(trust) {
  if (!trust) return [];
  const exact = new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 });
  const count = (value, singular, plural) => `${exact.format(value)} ${value === 1 ? singular : plural}`;
  const metrics = [];
  if (Number.isSafeInteger(trust.uniqueUsers)) metrics.push(count(trust.uniqueUsers, "user", "users"));
  else if (Number.isSafeInteger(trust.uniqueViewers)) {
    metrics.push(count(trust.uniqueViewers, "viewer", "viewers"));
  }
  if (Number.isSafeInteger(trust.queryCount)) metrics.push(count(trust.queryCount, "query", "queries"));
  else if (Number.isSafeInteger(trust.viewCount)) metrics.push(count(trust.viewCount, "view", "views"));
  if (metrics.length < 2 && Number.isSafeInteger(trust.favoriteCount)) {
    metrics.push(count(trust.favoriteCount, "favorite", "favorites"));
  }
  const visibleMetrics = metrics.slice(0, 2);
  const usageDate = (timestamp) => new Intl.DateTimeFormat(undefined, {
    month: "short", day: "numeric", year: "numeric", timeZone: "UTC",
  }).format(new Date(timestamp));
  if (Number.isSafeInteger(trust.windowDays) && visibleMetrics.length) {
    const window = `${trust.windowDays} ${trust.windowDays === 1 ? "day" : "days"}`;
    visibleMetrics[visibleMetrics.length - 1] += trust.usageAsOf
      ? ` over ${window} ending ${usageDate(trust.usageAsOf)}` : ` in last ${window}`;
  }
  const edited = trust.editedAt ? `Edited ${new Intl.DateTimeFormat(undefined, {
    month: "short", day: "numeric",
  }).format(new Date(trust.editedAt))}` : "";
  return [
    trust.provider,
    ...visibleMetrics,
    trust.lastQueriedAt ? `Last queried ${usageDate(trust.lastQueriedAt)}` : "",
    trust.verified ? "Verified" : "",
    edited,
  ].filter(Boolean);
}

function sourceTables(...collections) {
  const tables = new Map();
  for (const entry of collections.flat()) {
    const name = typeof entry === "string" ? entry.trim() : String(entry?.name ?? entry?.table ?? "").trim();
    if (!name) continue;
    const href = typeof entry === "string" ? null : safeSourceHref(entry.href ?? entry.url);
    const trust = typeof entry === "string" ? null : reviewedTrust(entry.trust ?? entry.trustSignals);
    const existing = tables.get(name);
    tables.set(name, { href: href ?? existing?.href ?? null, trust: existing?.trust ?? trust });
  }
  return tables;
}

function reviewedFiles(...collections) {
  const files = new Map();
  for (const entry of collections.flat()) {
    if (!entry || (typeof entry !== "string" && typeof entry !== "object")) continue;
    const label = typeof entry === "string" ? entry.trim()
      : String(entry.name ?? entry.label ?? entry.file ?? "").trim();
    if (!label) continue;
    const href = typeof entry === "string" ? null : safeSourceHref(entry.href ?? entry.url);
    const existing = files.get(label);
    files.set(label, { label, href: href ?? existing?.href ?? null });
  }
  return [...files.values()];
}

function reviewedMetricDefinitions(definitions) {
  if (!Array.isArray(definitions)) return [];
  return definitions.flatMap((entry) => {
    let record = entry;
    if (typeof entry === "string") {
      const match = entry.match(/^\s*([^:=]+?)\s*(?::|=)\s*(.+?)\s*$/su);
      if (!match) return [];
      record = { label: match[1], definition: match[2] };
    }
    if (!record || typeof record !== "object" || Array.isArray(record)) return [];
    const label = typeof record.label === "string" ? record.label.trim() : "";
    const definition = typeof record.definition === "string" ? record.definition.trim() : "";
    if (!label || !definition) return [];

    const reviewed = { ...record, label, definition };
    if (Object.hasOwn(reviewed, "componentIds")) {
      if (!Array.isArray(reviewed.componentIds)) return [];
      reviewed.componentIds = [...new Set(reviewed.componentIds
        .filter((value) => typeof value === "string" && value.trim())
        .map((value) => value.trim()))];
      if (!reviewed.componentIds.length) return [];
    }
    for (const key of ["formula", "calculationSummary", "variable", "identifier", "field", "chartLabel"]) {
      if (!Object.hasOwn(reviewed, key)) continue;
      if (typeof reviewed[key] !== "string" || !reviewed[key].trim()) delete reviewed[key];
      else reviewed[key] = reviewed[key].trim();
    }
    if (Object.hasOwn(reviewed, "dependencies")) {
      if (!Array.isArray(reviewed.dependencies)) delete reviewed.dependencies;
      else reviewed.dependencies = values(reviewed.dependencies).map((value) => value.trim());
    }
    for (const key of ["numerator", "denominator", "result"]) {
      if (!Object.hasOwn(reviewed, key)) continue;
      if (!reviewed[key] || typeof reviewed[key] !== "object" || Array.isArray(reviewed[key])) {
        delete reviewed[key];
      } else {
        reviewed[key] = { ...reviewed[key] };
        for (const field of ["field", "label", "definition"]) {
          if (!Object.hasOwn(reviewed[key], field)) continue;
          if (typeof reviewed[key][field] !== "string" || !reviewed[key][field].trim()) {
            delete reviewed[key][field];
          } else reviewed[key][field] = reviewed[key][field].trim();
        }
      }
    }
    if (Object.hasOwn(reviewed, "sourceLineage")) {
      if (!Array.isArray(reviewed.sourceLineage)) delete reviewed.sourceLineage;
      else reviewed.sourceLineage = reviewed.sourceLineage.flatMap((lineage) => {
        if (!lineage || typeof lineage !== "object" || Array.isArray(lineage)) return [];
        const tables = Array.isArray(lineage.tables) ? values(lineage.tables).map((value) => value.trim()) : [];
        const files = Array.isArray(lineage.files) ? values(lineage.files).map((value) => value.trim()) : [];
        return tables.length || files.length ? [{
          ...(tables.length ? { tables } : {}), ...(files.length ? { files } : {}),
        }] : [];
      });
    }
    return [reviewed];
  });
}

function definitionNames(definition) {
  return [definition.label, definition.chartLabel, definition.variable, definition.identifier,
    definition.field, definition.result?.field]
    .filter((value) => typeof value === "string" && value.trim())
    .map((value) => value.trim().toLowerCase());
}

function referencesIdentifier(formula, identifier) {
  if (typeof formula !== "string" || typeof identifier !== "string" || !identifier.trim()) return false;
  const escaped = identifier.trim().replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
  return new RegExp(`(^|[^A-Za-z0-9_])${escaped}(?=$|[^A-Za-z0-9_])`, "u").test(formula);
}

function definitionDependencies(definition, candidates) {
  const explicit = [definition.numerator?.field, definition.numerator?.label,
    definition.denominator?.field, definition.denominator?.label,
    ...(Array.isArray(definition.dependencies) ? definition.dependencies : [])]
    .filter((value) => typeof value === "string" && value.trim())
    .map((value) => value.trim().toLowerCase());
  const matching = new Set(explicit);
  for (const candidate of candidates) {
    for (const identifier of [candidate.variable, candidate.identifier, candidate.field, candidate.result?.field]) {
      if (referencesIdentifier(definition.formula, identifier)) matching.add(identifier.trim().toLowerCase());
    }
  }
  return matching;
}

export function scopedMetricDefinitions(definitions, componentId, {
  displayedFields = [], chartEdited = false,
} = {}) {
  if (!Array.isArray(definitions)) return [];
  const reviewed = definitions.filter((definition) => definition && typeof definition === "object"
    && !Array.isArray(definition)
    && (!Object.hasOwn(definition, "componentIds") || (Array.isArray(definition.componentIds)
      && definition.componentIds.some((value) => typeof value === "string" && value.trim()))));
  const unscoped = reviewed.filter((definition) => !Object.hasOwn(definition, "componentIds"));
  let scoped = reviewed.filter(({ componentIds }) =>
    Array.isArray(componentIds) && componentIds.includes(componentId));

  const fields = Array.isArray(displayedFields) ? [...new Set(displayedFields
    .filter((value) => typeof value === "string" && value.trim())
    .map((value) => value.trim().toLowerCase().replace(/[^a-z\d]/gu, ""))
    .filter(Boolean))] : [];
  if (chartEdited === true && fields.length) {
    const selectedFields = new Set();
    for (const field of fields) {
      const matching = reviewed.filter((definition) => definitionNames(definition)
        .some((name) => name.replace(/[^a-z\d]/gu, "") === field));
      const owned = matching.filter(({ componentIds }) =>
        Array.isArray(componentIds) && componentIds.includes(componentId));
      const shared = matching.filter((definition) => !Object.hasOwn(definition, "componentIds"));
      for (const definition of owned.length ? owned : shared.length ? shared : matching) {
        selectedFields.add(definition);
      }
    }
    scoped = reviewed.filter((definition) => selectedFields.has(definition));
    if (!scoped.length) return [];
  }
  if (!scoped.length) return reviewed.some(({ componentIds }) => componentIds?.length) ? unscoped : reviewed;

  const selected = new Set(scoped);
  let pending = scoped;
  while (pending.length) {
    const dependencies = new Set(pending.flatMap((definition) =>
      [...definitionDependencies(definition, unscoped)]));
    const next = unscoped.filter((definition) => !selected.has(definition)
      && definitionNames(definition).some((name) => dependencies.has(name)));
    next.forEach((definition) => selected.add(definition));
    pending = next;
  }
  return reviewed.filter((definition) => selected.has(definition));
}

export function referencedDefinitionVariable(definition, visibleDefinitions) {
  if (!definition || typeof definition !== "object" || !Array.isArray(visibleDefinitions)) return null;
  const variable = [definition.variable, definition.identifier, definition.field, definition.result?.field]
    .find((value) => typeof value === "string" && value.trim());
  if (!variable) return null;
  const identifier = variable.trim();
  return visibleDefinitions.some((candidate) => candidate !== definition
    && referencesIdentifier(candidate?.formula, identifier)) ? identifier : null;
}

export function reviewedDefinitionLineage(definition, { tables = [], files = [] } = {}) {
  if (!definition || !Array.isArray(definition.sourceLineage)) return [];
  const reviewedTables = new Set(tables.filter((table) => typeof table === "string"));
  const reviewedFiles = new Set(files.flatMap((file) => {
    if (typeof file === "string") return [file];
    const label = file?.label ?? file?.name ?? file?.file;
    return typeof label === "string" ? [label] : [];
  }));
  const sources = [];
  const seen = new Set();
  const include = (kind, identity) => {
    const key = `${kind}\u0000${identity}`;
    if (seen.has(key)) return;
    const parts = identity.split(kind === "table" ? /\./u : /[\\/]/u).filter(Boolean);
    if (!parts.length) return;
    seen.add(key);
    sources.push({ kind, identity, parts, separator: kind === "table" ? "." : "/", depth: 1 });
  };
  for (const lineage of definition.sourceLineage) {
    if (!lineage || typeof lineage !== "object" || Array.isArray(lineage)) continue;
    for (const table of Array.isArray(lineage.tables) ? lineage.tables : []) {
      if (reviewedTables.has(table)) include("table", table);
    }
    for (const file of Array.isArray(lineage.files) ? lineage.files : []) {
      if (reviewedFiles.has(file)) include("file", file);
    }
  }
  for (;;) {
    const labels = new Map();
    for (const source of sources) {
      const label = source.parts.slice(-source.depth).join(source.separator);
      const matching = labels.get(label) ?? [];
      matching.push(source);
      labels.set(label, matching);
    }
    let changed = false;
    for (const matching of labels.values()) {
      if (matching.length < 2) continue;
      for (const source of matching) {
        if (source.depth >= source.parts.length) continue;
        source.depth += 1;
        changed = true;
      }
    }
    if (changed) continue;
    return sources.map((source) => {
      const label = source.parts.slice(-source.depth).join(source.separator);
      return labels.get(label).length > 1
        ? `${source.kind === "table" ? "Table" : "File"}: ${source.identity}` : label;
    });
  }
}

export function reviewedSource(source = {}) {
  const reviewed = source && typeof source === "object" && !Array.isArray(source) ? source : {};
  const query = reviewed.query && typeof reviewed.query === "object" && !Array.isArray(reviewed.query)
    ? reviewed.query : {};
  const flow = reviewed.evidenceFlow ?? reviewed.evidence_flow ?? query.evidence_flow;
  const definitions = reviewed.metricDefinitions ?? reviewed.metric_definitions
    ?? query.metricDefinitions ?? query.metric_definitions;
  const tables = sourceTables(reviewed.tables ?? [], reviewed.tablesUsed ?? [], query.tables_used ?? [],
    reviewed.tableLinks ?? [], reviewed.table_links ?? [], query.table_links ?? []);
  return {
    label: reviewed.label ?? query.description ?? "Reviewed query",
    sql: reviewed.sql ?? query.sql,
    queryLink: reviewedQueryLink(reviewed),
    executedAt: reviewed.executedAt ?? reviewed.executed_at ?? query.executed_at,
    tables: [...tables.keys()],
    tableLinks: Object.fromEntries([...tables].filter(([, entry]) => entry.href)
      .map(([name, entry]) => [name, entry.href])),
    tableTrust: Object.fromEntries([...tables].filter(([, entry]) => entry.trust)
      .map(([name, entry]) => [name, entry.trust])),
    files: reviewedFiles(reviewed.files ?? [], reviewed.sourceFiles ?? [], query.files ?? [],
      query.sourceFiles ?? []),
    filters: values(reviewed.filters ?? [], query.filters ?? []),
    definitions: reviewedMetricDefinitions(definitions),
    links: sourceLinks(reviewed.url, reviewed.href, query.url,
      Array.isArray(reviewed.links) ? reviewed.links : [], Array.isArray(query.links) ? query.links : []),
    caveats: values(reviewed.caveats ?? [], reviewed.assumptions ?? [], query.caveats ?? []),
    evidenceFlow: Array.isArray(flow) ? flow : [],
  };
}

// The same projected identities drive role validation and visible source chips.
export function receiptSourceEntries(source) {
  const entries = [
    ...source.tables.map((label) => ({ kind: "table", label, href: source.tableLinks[label],
      ...(source.tableTrust?.[label] ? { trust: source.tableTrust[label] } : {}) })),
    ...source.files.map(({ label, href }) => ({ kind: "file", label, href })),
    ...source.links.flatMap((entry, index) => {
      const href = safeSourceHref(typeof entry === "string" ? entry : entry.href);
      return href ? [{ kind: entry.kind === "dashboard" ? "dashboard" : "link", href,
        label: entry.label || `Open reviewed source${index ? ` ${index + 1}` : ""}`,
        ...(entry.trust ? { trust: entry.trust } : {}) }] : [];
    }),
  ];
  return entries.length ? entries : [{ kind: "link", label: source.label }];
}

function receiptSourceIdentity(entry) {
  return reviewedRowIdentity(entry.kind === "table"
    ? [entry.kind, entry.label, entry.href ?? null]
    : entry.href ? [entry.kind, entry.href] : [entry.kind, entry.label]);
}

// A receipt summarizes a finding, not each query independently. Consolidate
// identical presentation facts, retaining ownership where scope differs.
// Never combine the underlying row sets, SQL, or recorded method inputs.
export function receiptQueryLabel(query, queries) {
  const label = reviewedQueryLabel(query, query.id);
  return queries.some((entry) => entry !== query && reviewedQueryLabel(entry, entry.id) === label)
    ? `${label} · ${query.id}` : label;
}

export function consolidatedReceipt(queries, componentId) {
  const records = queries.map((query) => ({ query, source: reviewedSource(query.source), label: receiptQueryLabel(query, queries) }));
  const trustBySource = new Map();
  for (const { source } of records) {
    for (const entry of receiptSourceEntries(source)) {
      if (!entry.trust) continue;
      const identity = receiptSourceIdentity(entry);
      if (!trustBySource.has(identity)) trustBySource.set(identity, new Map());
      trustBySource.get(identity).set(reviewedRowIdentity(entry.trust), entry.trust);
    }
  }
  const groups = Object.fromEntries(["definitions", "summaries", "caveats", "filters", "periods", "sources", "snapshots", "evidence"]
    .map((name) => [name, new Map()]));
  const add = (name, value, owner, key = reviewedRowIdentity(value)) => {
    let entry = groups[name].get(key);
    if (!entry) {
      entry = { value, owners: new Set() };
      groups[name].set(key, entry);
    }
    entry.owners.add(owner);
    return entry;
  };
  const quantitative = records.flatMap(({ query, source }, index) =>
    query.rows !== undefined || source.sql || query.methods?.length || source.definitions.length
      || query.reportingPeriod || source.filters.length ? [index] : []);
  records.forEach(({ query, source }, owner) => {
    for (const definition of scopedMetricDefinitions(source.definitions, componentId)) {
      const { componentIds: _scope, sourceLineage: _lineage, ...meaning } = definition;
      const entry = add("definitions", { ...meaning, sourceLineage: [] }, owner, reviewedRowIdentity(meaning));
      // Validate lineage against its own source before pooling identities. A
      // table mentioned by another query must not validate an unsupported link.
      for (const lineage of definition.sourceLineage ?? []) {
        entry.value.sourceLineage.push({
          tables: (lineage.tables ?? []).filter((table) => source.tables.includes(table)),
          files: (lineage.files ?? []).filter((file) => source.files.some(({ label }) => label === file)),
        });
      }
    }
    if (query.summary) add("summaries", query.summary, owner);
    source.caveats.forEach((caveat) => add("caveats", caveat, owner));
    if (query.reportingPeriod) add("periods", query.reportingPeriod, owner);
    source.filters.forEach((filter) => {
      const delimiter = filter.indexOf(": ");
      add("filters", delimiter > 0 ? { label: filter.slice(0, delimiter), value: filter.slice(delimiter + 2) }
        : { label: "", value: filter }, owner);
    });
    receiptSourceEntries(source).forEach((entry) => {
      const identity = receiptSourceIdentity(entry);
      const snapshots = trustBySource.get(identity);
      // Fill absent metadata only when this asset has one unambiguous snapshot.
      // Conflicting windows, counts, or coverage remain independently visible.
      const trust = entry.trust ?? (snapshots?.size === 1 ? snapshots.values().next().value : null);
      const consolidated = add("sources", trust ? { ...entry, trust } : entry, owner,
        reviewedRowIdentity([identity, trust ?? null]));
      // Never borrow a role from another query or a merely similar source label.
      const roles = (query.sourceRoles ?? []).filter((role) => role.kind === entry.kind
        && role.label === entry.label && (role.href ?? null) === (entry.href ?? null)).map(({ role }) => role);
      if (roles.length) {
        consolidated.roles ??= new Set();
        roles.forEach((role) => consolidated.roles.add(role));
        consolidated.value.role = [...consolidated.roles].join("\n");
      }
    });
    if (source.executedAt) add("snapshots", { label: "Query executed", timestamp: source.executedAt }, owner);
    if (query.capturedAt) add("snapshots", { label: "Snapshot captured", timestamp: query.capturedAt }, owner);
    source.evidenceFlow.forEach((step) => add("evidence", { step }, owner));
    (query.methods ?? []).forEach(({ language, code }) => add("evidence", {
      step: { kind: "calculation", title: language === "python" ? "Python calculation" : "Calculation" }, code, language,
    }, owner));
  });
  const allSources = { tables: records.flatMap(({ source }) => source.tables), files: records.flatMap(({ source }) => source.files) };
  return Object.fromEntries(Object.entries(groups).map(([name, entries]) => [name,
    [...entries.values()].map(({ value, owners }) => {
      const scope = name === "filters" || name === "periods" ? quantitative : records.map((_, index) => index);
      const shared = scope.every((owner) => owners.has(owner));
      const sourceLabels = [...new Set([...owners].map((owner) => records[owner].label))];
      const conflict = name === "definitions" && [...entries.values()].some((entry) => entry.value !== value && entry.value.label === value.label);
      return { value, sourceLabels, scopeLabels: (name === "definitions" ? conflict : !shared) ? sourceLabels : [],
        ...(name === "definitions" ? { lineage: reviewedDefinitionLineage(value, allSources) } : {}) };
    }),
  ]));
}
