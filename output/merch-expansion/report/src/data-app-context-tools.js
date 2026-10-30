const maximumRows = 500;
const defaultRows = 100;
const emptyRows = [];
const plainObject = value => value !== null && typeof value === "object" && !Array.isArray(value)
  && [Object.prototype, null].includes(Object.getPrototypeOf(value));

function validateInput(input, keys) {
  if (!plainObject(input) || Object.keys(input).some(key => !keys.includes(key))) {
    throw new Error("Invalid Data app context tool input.");
  }
}

function copy(value) {
  // The shell supplies JSON snapshot/presentation/view values. Return detached
  // data so a tool consumer cannot mutate the live dashboard through a result.
  return JSON.parse(JSON.stringify(value));
}

function reviewedRows(query, queryId) {
  if (query.rows === undefined) return emptyRows;
  if (!Array.isArray(query.rows)) throw new Error(`Reviewed rows for ${JSON.stringify(queryId)} are unavailable.`);
  return query.rows;
}

// Context is a metadata-only read. Row requests may load a complete published
// query through the same Site; they never execute source-system queries.
export function createDataAppContextTools({ getContext }) {
  let active = true;
  let revision = 0;
  let previousSignature = null;
  let rowSequence = 0;
  const rowIdentities = new WeakMap();
  const pageId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  const assertActive = () => {
    if (!active) throw new Error("This Data app is no longer open. Fetch its tools again.");
  };

  function readContext() {
    assertActive();
    const context = getContext();
    if (!plainObject(context?.snapshot) || !plainObject(context.snapshot.queries)) {
      throw new Error("The reviewed Data app context is not available yet.");
    }
    const { queries: snapshotQueries, ...metadata } = context.snapshot;
    const queries = context.queryDataStore?.getQueries() ?? snapshotQueries;
    const queryMetadata = [];
    const rowsByQuery = new Map();
    const rowVersions = [];
    for (const [queryId, query] of Object.entries(queries)) {
      if (!plainObject(query)) throw new Error(`Reviewed query ${JSON.stringify(queryId)} is unavailable.`);
      const deferred = context.queryDataStore && metadata._dataAppQueryLoading?.queries?.[queryId];
      const rows = deferred && query.rows === undefined ? undefined : reviewedRows(query, queryId);
      rowsByQuery.set(queryId, rows);
      const { rows: _rows, ...definition } = query;
      queryMetadata.push([queryId, definition]);
      if (rows && !rowIdentities.has(rows)) rowIdentities.set(rows, ++rowSequence);
      // Reviewed rows are replaced by the shell on refresh/query edits. The
      // snapshot's generatedAt also changes on stored query updates.
      rowVersions.push(deferred
        ? [queryId, metadata._dataAppQueryLoading.snapshotSha256, deferred.rowCount]
        : [queryId, rowIdentities.get(rows), rows.length]);
    }
    const result = {
      schemaVersion: 1,
      live: true,
      immutable: false,
      versionScope: "This open page; fetch context again after reopening or when its version changes.",
      generatedAt: context.snapshot.generatedAt ?? null,
      artifact: {
        id: context.snapshot.id ?? null,
        surface: context.snapshot.surface ?? context.view?.surface ?? "dashboard",
        title: context.presentation?.title ?? context.snapshot.title ?? null,
      },
      dataAppReference: context.dataAppReference ?? {},
      viewUrl: context.viewUrl ?? null,
      canEdit: context.canEdit === true,
      presentation: context.presentation ?? {},
      view: context.view ?? {},
      snapshot: { ...metadata, queries: Object.fromEntries(queryMetadata) },
      rows: { included: false, tool: "get_data_app_query_rows", maximumPageSize: maximumRows,
        scope: "All reviewed rows, before the current view's filters or modeled assumptions." },
      text: { included: false, tool: "get_data_app_text", scope: "Exact rendered text by stable narrative or component ID." },
    };
    const signature = JSON.stringify([result, rowVersions]);
    if (signature !== previousSignature) {
      revision += 1;
      previousSignature = signature;
    }
    return { result, rowsByQuery, queryDataStore: context.queryDataStore,
      getText: context.getText, contextVersion: `${pageId}:${revision}` };
  }

  const annotations = { readOnlyHint: true, untrustedContentHint: true };
  const tools = [{
    name: "get_data_app_context",
    description: "Read this open Data dashboard or report's exact live presentation and view, artifact identity, and complete snapshot metadata including every query definition and SQL. Reviewed query rows are excluded; fetch them with get_data_app_query_rows. This is the current live page, not an immutable historical capture. Read-only: no navigation, network requests, storage, source queries, or writes.",
    annotations,
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    execute: async (input = {}) => {
      validateInput(input, []);
      const { result, rowsByQuery, contextVersion } = readContext();
      const queries = Object.fromEntries([...rowsByQuery].map(([queryId, rows]) => {
        const definition = result.snapshot.queries[queryId];
        const source = definition.source ?? {};
        const columns = new Set();
        for (const row of rows ?? []) {
          if (plainObject(row)) for (const column of Object.keys(row)) columns.add(column);
        }
        return [queryId, {
          rowCount: rows?.length ?? result.snapshot._dataAppQueryLoading?.queries?.[queryId]?.rowCount,
          columns: rows ? [...columns] : result.snapshot._dataAppQueryLoading?.queries?.[queryId]?.columns ?? [],
          ...(result.snapshot._dataAppQueryLoading ? { loaded: rows !== undefined } : {}),
          label: definition.label ?? definition.title ?? source.label ?? source.query?.description ?? queryId,
          sql: source.sql ?? source.query?.sql ?? definition.sql ?? null,
        }];
      }));
      return copy({ ...result, contextVersion, queries });
    },
  }, {
    name: "get_data_app_query_rows",
    description: "Read a page of reviewed rows for an exact queryId from get_data_app_context. If deferred, first loads that complete published query from this same Site. Returns at most 500 rows, exact totals, nextOffset, and the live contextVersion/generatedAt. Pass contextVersion from the context or previous page to refuse mixed-version pagination; on mismatch fetch context again and restart. Rows are the reviewed source rows before view filters and modeled assumptions. Does not execute SQL, navigate, or write anything.",
    annotations,
    inputSchema: { type: "object", properties: {
      queryId: { type: "string", minLength: 1, maxLength: 1_000 },
      offset: { type: "integer", minimum: 0, default: 0 },
      limit: { type: "integer", minimum: 1, maximum: maximumRows, default: defaultRows },
      contextVersion: { type: "string", minLength: 1, maxLength: 200 },
    }, required: ["queryId"], additionalProperties: false },
    execute: async (input) => {
      validateInput(input, ["queryId", "offset", "limit", "contextVersion"]);
      const { queryId, offset = 0, limit = defaultRows, contextVersion: expectedVersion } = input;
      if (!Object.hasOwn(input, "queryId") || typeof queryId !== "string" || !queryId.length || queryId.length > 1_000) {
        throw new Error("Use an exact queryId returned by get_data_app_context.");
      }
      if (!Number.isSafeInteger(offset) || offset < 0 || !Number.isSafeInteger(limit) || limit < 1 || limit > maximumRows) {
        throw new Error(`Provide a nonnegative integer offset and a limit between 1 and ${maximumRows}.`);
      }
      if (expectedVersion !== undefined && (typeof expectedVersion !== "string" || !expectedVersion.length || expectedVersion.length > 200)) {
        throw new Error("Provide the contextVersion returned by get_data_app_context or the previous row page.");
      }
      let { result, rowsByQuery, contextVersion, queryDataStore } = readContext();
      if (expectedVersion !== undefined && expectedVersion !== contextVersion) {
        throw new Error("The Data app context changed. Fetch get_data_app_context again and restart row pagination.");
      }
      if (!rowsByQuery.has(queryId)) throw new Error(`Reviewed query ${JSON.stringify(queryId)} does not exist in this Data app.`);
      if (rowsByQuery.get(queryId) === undefined) {
        await queryDataStore.ensure([queryId]);
        const current = readContext();
        if (current.contextVersion !== contextVersion) {
          throw new Error("The Data app context changed. Fetch get_data_app_context again and restart row pagination.");
        }
        ({ result, rowsByQuery, contextVersion } = current);
      }
      const allRows = rowsByQuery.get(queryId);
      const rows = allRows.slice(offset, offset + limit);
      const nextOffset = offset + rows.length < allRows.length ? offset + rows.length : null;
      return copy({
        schemaVersion: 1, live: true, immutable: false, contextVersion, generatedAt: result.generatedAt,
        artifact: result.artifact, queryId, offset, limit, totalRows: allRows.length,
        returnedRows: rows.length, nextOffset, hasMore: nextOffset !== null,
        rowScope: "reviewed_source_rows_before_view_filters_and_assumptions", rows,
      });
    },
  }, {
    name: "get_data_app_text",
    description: "Read the full currently rendered text of one Data app narrative or component by its exact stable id, including authored default prose and applied text edits. The shell resolves only content in this open page; missing, hidden, or duplicate IDs fail explicitly. Use an ID from the action request or list_data_app_cards. Returns full text without clipping, plus the live contextVersion/generatedAt. Does not navigate, expand controls, or write anything.",
    annotations,
    inputSchema: { type: "object", properties: {
      id: { type: "string", minLength: 1, maxLength: 1_000 },
      contextVersion: { type: "string", minLength: 1, maxLength: 200 },
    }, required: ["id"], additionalProperties: false },
    execute: async (input) => {
      validateInput(input, ["id", "contextVersion"]);
      const { id, contextVersion: expectedVersion } = input;
      if (!Object.hasOwn(input, "id") || typeof id !== "string" || !id.length || id.length > 1_000) {
        throw new Error("Use an exact narrative or component id from the action request or list_data_app_cards.");
      }
      if (expectedVersion !== undefined && (typeof expectedVersion !== "string" || !expectedVersion.length || expectedVersion.length > 200)) {
        throw new Error("Provide the contextVersion returned by get_data_app_context.");
      }
      const { result, getText, contextVersion } = readContext();
      if (expectedVersion !== undefined && expectedVersion !== contextVersion) {
        throw new Error("The Data app context changed. Fetch get_data_app_context again and retry reading text.");
      }
      if (typeof getText !== "function") throw new Error("Rendered text retrieval is unavailable in this Data app view.");
      const text = getText(id);
      if (text == null) throw new Error(`Text for ${JSON.stringify(id)} is not visible in this view. Open its tab and try again.`);
      if (typeof text !== "string") throw new Error(`Text for ${JSON.stringify(id)} could not be read unambiguously.`);
      return copy({ schemaVersion: 1, live: true, immutable: false, contextVersion, generatedAt: result.generatedAt,
        artifact: result.artifact, id, scope: "rendered_current_view", text });
    },
  }];
  return { tools, dispose: () => { active = false; } };
}

export function registerDataAppContextTools(modelContext, getContext, report = console.error) {
  if (typeof modelContext?.registerTool !== "function") return () => {};
  const controller = new AbortController();
  const { tools, dispose } = createDataAppContextTools({ getContext });
  for (const tool of tools) {
    const failed = error => {
      if (!controller.signal.aborted) report(`Unable to register Data app tool ${tool.name}.`, error);
    };
    try { Promise.resolve(modelContext.registerTool(tool, { signal: controller.signal })).catch(failed); }
    catch (error) { failed(error); }
  }
  return () => {
    dispose();
    controller.abort();
    for (const tool of tools) modelContext.unregisterTool?.(tool.name);
  };
}
