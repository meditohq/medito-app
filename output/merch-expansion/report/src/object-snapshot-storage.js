// The reviewed R2 object remains immutable. Only owner query replacements have
// D1 pointers; large rows and source metadata never pass through D1 values.
const encoder = new TextEncoder();
const schemas = [
  `CREATE TABLE IF NOT EXISTS data_app_object_execution_times_v1 (
    revision TEXT PRIMARY KEY, executed_at TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_object_head_v1 (
    id TEXT PRIMARY KEY, seed_sha256 TEXT NOT NULL, generation TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_object_snapshots_v1 (
    seed_sha256 TEXT PRIMARY KEY, generated_at TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_object_queries_v1 (
    seed_sha256 TEXT NOT NULL, query_id TEXT NOT NULL, revision TEXT NOT NULL,
    bytes INTEGER NOT NULL, PRIMARY KEY (seed_sha256, query_id)
  )`,
];

function failure(code, message) {
  return Object.assign(new Error(message), { code });
}

export function validateSnapshotIndex(index, asset) {
  const offset = value => Number.isSafeInteger(value) && value >= 0 && value < asset.bytes;
  const range = value => Array.isArray(value) && value.length === 2
    && offset(value[0]) && Number.isSafeInteger(value[1])
    && value[1] > value[0] && value[1] <= asset.bytes;
  if (!index || index.version !== 1 || index.sha256 !== asset.sha256 || index.bytes !== asset.bytes
    || !offset(index.end) || (index.generatedAt !== null && !range(index.generatedAt))
    || !index.queries || typeof index.queries !== "object" || Array.isArray(index.queries)
    || Object.values(index.queries).some(query => !query || !offset(query.end)
      || typeof query.empty !== "boolean" || (query.rows !== null && !range(query.rows))
      || (query.source != null && (!range(query.source.range) || typeof query.source.object !== "boolean"
        || typeof query.source.empty !== "boolean" || (query.source.executedAt !== null && !range(query.source.executedAt)))))
    || (index.replacements !== undefined && (!Array.isArray(index.replacements)
      || index.replacements.some(item => !range([item.start, item.end]) || !["0", "null"].includes(item.text))))) {
    throw failure("INVALID_SNAPSHOT_INDEX", "The hosted snapshot index does not match its immutable asset.");
  }
}

export async function usesObjectSnapshot(database) {
  if (typeof database?.prepare !== "function" || typeof database.batch !== "function") {
    throw failure("DATABASE_UNAVAILABLE", "The Sites D1 database is unavailable.");
  }
  // A failed old publication may have created tables, or even activated data.
  // Never infer absence of owner edits from its publication/readback outcome.
  const tables = await database.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name IN " +
    "('data_app_snapshot_head_v2', 'data_app_snapshots', 'data_app_queries', 'data_app_query_rows', 'data_app_object_queries_v1')").all();
  let legacy = false, objectEdits = false;
  for (const { name } of tables.results ?? []) {
    if (await database.prepare(`SELECT 1 AS populated FROM ${name} LIMIT 1`).first()) {
      if (name === "data_app_object_queries_v1") objectEdits = true;
      else legacy = true;
    }
  }
  if (legacy && objectEdits) {
    throw failure("LEGACY_SNAPSHOT_REQUIRES_MIGRATION", "Both snapshot storage versions contain data; an explicit reviewed migration is required. No owner edits were reset.");
  }
  return !legacy;
}

function activeHead(database) {
  return database.prepare("SELECT seed_sha256, generation FROM data_app_object_head_v1 WHERE id = 'current'").first();
}

async function initialize(database, seedSha256) {
  await database.batch(schemas.map(sql => database.prepare(sql)));
  const previous = await activeHead(database);
  if (previous?.seed_sha256 === seedSha256) return previous;
  const generation = crypto.randomUUID();
  const activate = previous
    ? database.prepare("UPDATE data_app_object_head_v1 SET seed_sha256 = ?, generation = ? " +
      "WHERE id = 'current' AND generation = ?").bind(seedSha256, generation, previous.generation)
    : database.prepare("INSERT INTO data_app_object_head_v1 (id, seed_sha256, generation) VALUES ('current', ?, ?) " +
      "ON CONFLICT(id) DO NOTHING").bind(seedSha256, generation);
  const statements = [activate,
    database.prepare("INSERT INTO data_app_object_snapshots_v1 (seed_sha256, generated_at) " +
      "VALUES (?, NULL) ON CONFLICT(seed_sha256) DO NOTHING").bind(seedSha256),
  ];
  // A seed returning after another publication starts a new generation. Reset
  // its overlay pointers only if this transaction won activation. Immutable R2
  // revisions remain available to responses that captured the previous state.
  // On first adoption of older object storage, retain the current seed's edits.
  if (previous) statements.push(
    database.prepare("DELETE FROM data_app_object_queries_v1 WHERE seed_sha256 = ? " +
      "AND EXISTS (SELECT 1 FROM data_app_object_head_v1 WHERE id = 'current' AND generation = ?)").bind(seedSha256, generation),
    database.prepare("UPDATE data_app_object_snapshots_v1 SET generated_at = NULL WHERE seed_sha256 = ? " +
      "AND EXISTS (SELECT 1 FROM data_app_object_head_v1 WHERE id = 'current' AND generation = ?)").bind(seedSha256, generation),
  );
  const [activated] = await database.batch(statements);
  if (activated?.meta?.changes === 1) return { seed_sha256: seedSha256, generation };
  const winner = await activeHead(database);
  if (winner?.seed_sha256 === seedSha256) return winner;
  throw failure("SNAPSHOT_HEAD_CONFLICT", "The snapshot head changed during initialization; retry the current deployment.");
}

function rowsKey(seed, revision) {
  return `data-app/query-rows/${seed}/${revision}`;
}

// Lazy seed reads are opt-in only while the complete snapshot has no owner
// overlays. Edited or legacy snapshots retain the existing eager read path.
export async function objectSnapshotIsUnedited(database, seedSha256) {
  const active = await initialize(database, seedSha256);
  const [head, edits] = await database.batch([
    database.prepare("SELECT s.generated_at FROM data_app_object_snapshots_v1 s " +
      "JOIN data_app_object_head_v1 h ON h.seed_sha256 = s.seed_sha256 " +
      "WHERE h.id = 'current' AND h.seed_sha256 = ? AND h.generation = ?").bind(seedSha256, active.generation),
    database.prepare("SELECT 1 AS edited FROM data_app_object_queries_v1 WHERE seed_sha256 = ? LIMIT 1").bind(seedSha256),
  ]);
  if (head.success === false || edits.success === false) {
    throw failure("SNAPSHOT_UNAVAILABLE", "The stored snapshot revision could not be read.");
  }
  if (!head.results?.length) throw failure("SNAPSHOT_HEAD_CONFLICT", "The reviewed snapshot changed before its response was captured.");
  return head.results[0].generated_at === null && edits.results?.length === 0;
}

async function* objectBytes(object, expectedBytes) {
  const reader = object.body.getReader();
  let count = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      count += value.byteLength;
      if (count > expectedBytes) throw failure("INCOMPLETE_SNAPSHOT", "A stored snapshot object has an unexpected length.");
      yield value;
    }
    if (count !== expectedBytes) throw failure("INCOMPLETE_SNAPSHOT", "A stored snapshot object is incomplete.");
  } finally { await reader.cancel(); }
}

async function* replacementBytes(bucket, seed, patch) {
  if (patch.text !== undefined) {
    yield encoder.encode(patch.text);
    return;
  }
  if (patch.prefix) yield encoder.encode(patch.prefix);
  const object = await bucket.get(rowsKey(seed, patch.revision));
  if (!object?.body || object.size !== patch.bytes || object.customMetadata?.revision !== patch.revision) {
    await object?.body?.cancel();
    throw failure("INCOMPLETE_QUERY", "An immutable query revision is unavailable.");
  }
  yield* objectBytes(object, patch.bytes);
}

function responsePatches(index, captured) {
  const changed = new Map(captured.queries.map(query => [query.query_id, query]));
  const patches = [];
  for (const [id, query] of Object.entries(index.queries)) {
    const update = changed.get(id);
    if (update) {
      patches.push({ start: query.rows?.[0] ?? query.end, end: query.rows?.[1] ?? query.end,
        ...update, prefix: query.rows ? "" : `${query.empty ? "" : ","}"rows":` });
      if (update.executed_at != null) {
        if (query.source === undefined) throw failure("INVALID_SNAPSHOT_INDEX", "Republish this dashboard with source timestamp offsets before refreshing source times.");
        const source = query.source, timestamp = JSON.stringify(update.executed_at);
        if (source?.object) {
          patches.push({ start: source.executedAt?.[0] ?? source.range[1] - 1,
            end: source.executedAt?.[1] ?? source.range[1] - 1,
            text: (source.executedAt ? "" : `${source.empty ? "" : ","}"executedAt":`) + timestamp });
        } else {
          patches.push({ start: source?.range[0] ?? query.end, end: source?.range[1] ?? query.end,
            text: (source ? "" : ',"source":') + `{"executedAt":${timestamp}}` });
        }
      }
    } else if (!query.rows) {
      patches.push({ start: query.end, end: query.end, text: `${query.empty ? "" : ","}"rows":[]` });
    }
  }
  if (captured.generatedAt !== null) {
    patches.push({ start: index.generatedAt?.[0] ?? index.end, end: index.generatedAt?.[1] ?? index.end,
      text: (index.generatedAt ? "" : ',"generatedAt":') + JSON.stringify(captured.generatedAt) });
  }
  // Normalization inside a replaced value belongs to the old revision only.
  // Scan just the sorted overlay spans, not a growing list of numeric patches.
  const overlays = patches.slice().sort((a, b) => a.start - b.start);
  let position = 0;
  for (const item of [...index.replacements ?? []].sort((a, b) => a.start - b.start)) {
    while (position < overlays.length && overlays[position].end <= item.start) position++;
    const overlay = overlays[position];
    if (!overlay || item.start < overlay.start || item.end > overlay.end) patches.push(item);
  }
  patches.sort((a, b) => a.start - b.start);
  for (let i = 1; i < patches.length; i++) {
    if (patches[i].start < patches[i - 1].end) {
      throw failure("INVALID_SNAPSHOT_INDEX", "Hosted snapshot replacements overlap.");
    }
  }
  return patches;
}

async function* spliceSnapshot(base, index, patches, bucket, seed) {
  const reader = base.body.getReader();
  let pending, offset = 0, position = 0;
  async function* advance(end, emit) {
    while (position < end) {
      if (!pending || offset === pending.byteLength) {
        const next = await reader.read();
        if (next.done) throw failure("INCOMPLETE_SNAPSHOT", "The immutable snapshot is incomplete.");
        pending = next.value; offset = 0;
      }
      const count = Math.min(end - position, pending.byteLength - offset);
      if (emit && count) yield pending.subarray(offset, offset + count);
      position += count; offset += count;
    }
  }
  try {
    for (const patch of patches) {
      yield* advance(patch.start, true);
      yield* replacementBytes(bucket, seed, patch);
      yield* advance(patch.end, false);
    }
    yield* advance(index.bytes, true);
    if ((pending && offset !== pending.byteLength) || !(await reader.read()).done) {
      throw failure("INCOMPLETE_SNAPSHOT", "The immutable snapshot has an unexpected length.");
    }
  } finally { await reader.cancel(); }
}

export async function objectQueryRowsResponse(bucket, asset, index, queryId) {
  const rows = index.queries[queryId].rows;
  // Missing rows still verify that the configured immutable object exists.
  const offset = rows?.[0] ?? 0, length = rows ? rows[1] - rows[0] : 1;
  const patches = rows ? (index.replacements ?? [])
    .filter(item => item.start >= rows[0] && item.end <= rows[1])
    .map(item => ({ ...item, start: item.start - offset, end: item.end - offset }))
    .sort((a, b) => a.start - b.start) : [];
  for (let i = 1; i < patches.length; i += 1) {
    if (patches[i].start < patches[i - 1].end) throw failure("INVALID_SNAPSHOT_INDEX", "Hosted snapshot replacements overlap.");
  }
  // A ranged R2 read avoids fetching or scanning unrelated query rows. R2's
  // size describes the whole object; range describes the returned body.
  const object = await bucket?.get(asset.key, { range: { offset, length } });
  if (!object?.body || object.size !== asset.bytes || object.customMetadata?.sha256 !== asset.sha256
    || object.range?.offset !== offset || object.range?.length !== length) {
    await object?.body?.cancel();
    throw failure("INCOMPLETE_QUERY", "The immutable query rows are unavailable or incomplete.");
  }
  const headers = { "content-type": "application/json; charset=utf-8", "cache-control": "private, no-store" };
  if (!rows) {
    await object.body.cancel();
    return new Response("[]", { headers });
  }
  if (!patches.length) return new Response(object.body, { headers });
  // Match the complete snapshot's numeric normalization, without parsing rows
  // into Worker memory. Offsets are relative to this query's requested range.
  const iterator = spliceSnapshot(object, { bytes: length }, patches, bucket);
  return new Response(new ReadableStream({
    async pull(controller) {
      try {
        const { done, value } = await iterator.next();
        if (done) controller.close(); else controller.enqueue(value);
      } catch (error) { controller.error(error); await iterator.return(); }
    },
    async cancel() { await iterator.return(); },
  }), { headers });
}

export async function objectSnapshotResponse(database, bucket, base, index, seedSha256) {
  let iterator;
  try {
    const active = await initialize(database, seedSha256);
    // One D1 transaction captures both the timestamp and every immutable pointer.
    const [head, queries] = await database.batch([
      database.prepare("SELECT s.generated_at FROM data_app_object_snapshots_v1 s " +
        "JOIN data_app_object_head_v1 h ON h.seed_sha256 = s.seed_sha256 " +
        "WHERE h.id = 'current' AND h.seed_sha256 = ? AND h.generation = ?").bind(seedSha256, active.generation),
      database.prepare("SELECT q.query_id, q.revision, q.bytes, e.executed_at FROM data_app_object_queries_v1 q " +
        "LEFT JOIN data_app_object_execution_times_v1 e ON e.revision = q.revision WHERE q.seed_sha256 = ?").bind(seedSha256),
    ]);
    if (head.success === false || queries.success === false) {
      throw failure("SNAPSHOT_UNAVAILABLE", "The stored snapshot revision could not be read.");
    }
    if (!head.results?.length) throw failure("SNAPSHOT_HEAD_CONFLICT", "The reviewed snapshot changed before its response was captured.");
    const patches = responsePatches(index, { generatedAt: head.results[0].generated_at, queries: queries.results ?? [] });
    iterator = spliceSnapshot(base, index, patches, bucket, seedSha256);
  } catch (error) { await base.body?.cancel(); throw error; }
  return new Response(new ReadableStream({
    async pull(controller) {
      try {
        const { done, value } = await iterator.next();
        if (done) controller.close(); else controller.enqueue(value);
      } catch (error) { controller.error(error); await iterator.return(); }
    },
    async cancel() { await iterator.return(); },
  }), { headers: { "content-type": "application/json; charset=utf-8", "cache-control": "private, no-store" } });
}

export async function updateObjectQuery(database, bucket, seedSha256, queryId, rows, generatedAt) {
  return updateObjectQueries(database, bucket, seedSha256, [{ queryId, rows }], generatedAt);
}

export async function updateObjectQueries(database, bucket, seedSha256, updates, generatedAt, index) {
  const active = await initialize(database, seedSha256);
  const replacements = [];
  for (const { queryId, rows, executedAt } of updates) {
    if (executedAt !== undefined && index?.queries[queryId]?.source === undefined) {
      throw failure("INVALID_SNAPSHOT_INDEX", "Republish this dashboard with source timestamp offsets before refreshing source times.");
    }
    const previous = await database.prepare("SELECT revision FROM data_app_object_queries_v1 WHERE seed_sha256 = ? AND query_id = ?")
      .bind(seedSha256, queryId).first();
    const revision = crypto.randomUUID(), serialized = JSON.stringify(rows);
    const bytes = encoder.encode(serialized).byteLength;
    const stored = await bucket.put(rowsKey(seedSha256, revision), serialized, {
      customMetadata: { revision }, httpMetadata: { contentType: "application/json; charset=utf-8" },
    });
    if (!stored || stored.size !== bytes) throw failure("INCOMPLETE_QUERY", "The new query revision was not completely stored.");
    await database.prepare("INSERT INTO data_app_object_execution_times_v1 (revision, executed_at) VALUES (?, " +
      "COALESCE(?, (SELECT executed_at FROM data_app_object_execution_times_v1 WHERE revision = ?)))")
      .bind(revision, executedAt ?? null, previous?.revision ?? null).run();
    replacements.push({ queryId, revision, bytes, previous: previous?.revision ?? null });
  }
  if (!await usesObjectSnapshot(database)) {
    throw failure("SNAPSHOT_HEAD_CONFLICT", "The snapshot storage changed while new rows were staged; retry the current deployment.");
  }
  // Check every old pointer before activating any of the new immutable objects.
  // One transaction publishes the whole refresh and its matching timestamp.
  const payload = JSON.stringify(replacements);
  const expected = "WITH expected AS MATERIALIZED (SELECT " +
    "json_extract(value, '$.queryId') AS id, json_extract(value, '$.revision') AS revision, " +
    "json_extract(value, '$.previous') AS previous, json_extract(value, '$.bytes') AS bytes FROM json_each(?)) ";
  const [activated] = await database.batch([
    database.prepare(expected.slice(0, -1) + ", allowed AS MATERIALIZED (SELECT 1 WHERE " +
      "EXISTS (SELECT 1 FROM data_app_object_head_v1 WHERE id = 'current' AND generation = ?) " +
      "AND NOT EXISTS (SELECT 1 FROM expected e LEFT JOIN data_app_object_queries_v1 q " +
      "ON q.seed_sha256 = ? AND q.query_id = e.id WHERE q.revision IS NOT e.previous)) " +
      "INSERT INTO data_app_object_queries_v1 (seed_sha256, query_id, revision, bytes) " +
      "SELECT ?, id, revision, bytes FROM expected WHERE EXISTS (SELECT 1 FROM allowed) " +
      "ON CONFLICT(seed_sha256, query_id) DO UPDATE SET revision = excluded.revision, bytes = excluded.bytes")
      .bind(payload, active.generation, seedSha256, seedSha256),
    database.prepare(expected + "UPDATE data_app_object_snapshots_v1 SET generated_at = ? WHERE seed_sha256 = ? " +
      "AND NOT EXISTS (SELECT 1 FROM expected e LEFT JOIN data_app_object_queries_v1 q " +
      "ON q.seed_sha256 = ? AND q.query_id = e.id WHERE q.revision IS NOT e.revision)")
      .bind(payload, generatedAt, seedSha256, seedSha256),
  ]);
  if (activated?.meta?.changes !== updates.length) {
    throw failure("QUERY_REVISION_CONFLICT", "The query changed while new rows were staged; retry against the current revision.");
  }
  await usesObjectSnapshot(database);
}
