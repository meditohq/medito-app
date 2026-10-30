// Revisions stay immutable once published so an in-flight stream remains valid.
const currentId = "current";
const encoder = new TextEncoder();
const maxBatchBytes = 256 * 1024;
const batchEnvelopeReserve = 1024;
const maxBindings = 100;
const rowsPerStatement = Math.floor(maxBindings / 5);
const pageCandidates = 1024;
const pageBytes = 256 * 1024;
const schemas = [
  `CREATE TABLE IF NOT EXISTS data_app_execution_times_v2 (
    revision TEXT PRIMARY KEY, executed_at TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_snapshot_head_v2 (
    id TEXT PRIMARY KEY, current_generation TEXT NOT NULL, seed_sha256 TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_generations_v2 (
    generation TEXT PRIMARY KEY, metadata_json TEXT NOT NULL, seed_sha256 TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_query_revisions_v2 (
    generation TEXT NOT NULL, query_id TEXT NOT NULL, position INTEGER NOT NULL,
    query_json TEXT NOT NULL, revision TEXT NOT NULL, row_count INTEGER NOT NULL,
    PRIMARY KEY (generation, query_id)
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_rows_v2 (
    generation TEXT NOT NULL, query_id TEXT NOT NULL, revision TEXT NOT NULL,
    position INTEGER NOT NULL, row_json TEXT NOT NULL,
    PRIMARY KEY (generation, query_id, revision, position)
  )`,
];

function failure(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

function checkDatabase(database) {
  if (typeof database?.prepare !== "function" || typeof database.batch !== "function") {
    throw failure("DATABASE_UNAVAILABLE", "The Sites D1 database is unavailable.");
  }
}

function descriptor(sql, params = []) {
  if (params.length > maxBindings) throw failure("BINDING_LIMIT", "A statement exceeds 100 bindings.");
  const bytes = encoder.encode(JSON.stringify({ sql, params })).byteLength;
  if (bytes > maxBatchBytes - batchEnvelopeReserve - 2) {
    throw failure("SNAPSHOT_VALUE_TOO_LARGE", "One snapshot value exceeds the bounded database-write budget.");
  }
  return { sql, params, bytes };
}

async function execute(database, descriptors) {
  if (!descriptors.length) return [];
  const size = 2 + descriptors.reduce((sum, item) => sum + item.bytes + 1, 0);
  if (size > maxBatchBytes - batchEnvelopeReserve) {
    throw failure("BATCH_LIMIT", "The database batch exceeds its serialized byte budget.");
  }
  const result = await database.batch(descriptors.map(({ sql, params }) => database.prepare(sql).bind(...params)));
  if (!Array.isArray(result) || result.length !== descriptors.length || result.some(item => item?.success === false)) {
    throw failure("DATABASE_BATCH_FAILED", "The database did not complete the snapshot batch.");
  }
  return result;
}

function writer(database) {
  let pending = [], size = 2;
  return {
    async push(item) {
      if (size + item.bytes + 1 > maxBatchBytes - batchEnvelopeReserve) await this.flush();
      pending.push(item);
      size += item.bytes + 1;
    },
    async flush() {
      if (!pending.length) return;
      const batch = pending;
      pending = [];
      size = 2;
      await execute(database, batch);
    },
  };
}

async function ensureSchema(database) {
  checkDatabase(database);
  await execute(database, schemas.map(sql => descriptor(sql)));
}

function head(database) {
  return database.prepare(
    "SELECT current_generation, seed_sha256 FROM data_app_snapshot_head_v2 WHERE id = ?",
  ).bind(currentId).first();
}

async function rejectPopulatedLegacy(database) {
  // Old tables may contain reviewed query updates. Never silently replace them,
  // even if their seed hash happens to match the deployed seed.
  const existing = await database.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN " +
    "('data_app_snapshots', 'data_app_queries', 'data_app_query_rows')",
  ).all();
  for (const { name } of existing.results ?? []) {
    // Names originate exclusively from the fixed SQL allowlist above.
    if (await database.prepare(`SELECT 1 AS populated FROM ${name} LIMIT 1`).first()) {
      throw failure("LEGACY_SNAPSHOT_REQUIRES_MIGRATION", "Existing legacy snapshot data requires an explicit reviewed migration; no data was reset.");
    }
  }
}

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

async function writeRows(batch, generation, queryId, revision, rows) {
  if (!Array.isArray(rows) || rows.some(row => !plainObject(row))) {
    throw failure("INVALID_QUERY_ROWS", "Data app query rows must be an array of objects.");
  }
  let values = [];
  const sql = count => "INSERT INTO data_app_rows_v2 " +
    "(generation, query_id, revision, position, row_json) VALUES " +
    Array.from({ length: count }, () => "(?, ?, ?, ?, ?)").join(", ");
  for (let position = 0; position < rows.length; position += 1) {
    const row = [generation, queryId, revision, position, JSON.stringify(rows[position])];
    // Test a single row first so an oversized value fails explicitly instead of
    // escaping the byte budget or producing a partially visible snapshot.
    descriptor(sql(1), row);
    const combined = values.concat(row);
    const combinedBytes = encoder.encode(JSON.stringify({ sql: sql(combined.length / 5), params: combined })).byteLength;
    if (values.length && (combined.length > maxBindings || combinedBytes > maxBatchBytes - batchEnvelopeReserve - 3)) {
      await batch.push(descriptor(sql(values.length / 5), values));
      values = row;
    } else {
      values = combined;
    }
    if (values.length === rowsPerStatement * 5) {
      await batch.push(descriptor(sql(rowsPerStatement), values));
      values = [];
    }
  }
  if (values.length) await batch.push(descriptor(sql(values.length / 5), values));
}

async function initializeSnapshot(database, loadSeed, seedSha256) {
  if (typeof loadSeed !== "function" || typeof seedSha256 !== "string" || !/^[a-f\d]{64}$/u.test(seedSha256)) {
    throw failure("INVALID_SEED_DESCRIPTOR", "A lazy reviewed seed loader and its precomputed SHA-256 are required.");
  }
  await ensureSchema(database);
  const previous = await head(database);
  if (previous?.seed_sha256 === seedSha256) return previous;
  if (!previous) await rejectPopulatedLegacy(database);

  const seed = await loadSeed();
  if (!plainObject(seed) || !plainObject(seed.queries)) {
    throw failure("INVALID_SEED", "The reviewed snapshot must contain a queries object.");
  }
  const generation = crypto.randomUUID();
  const { queries, ...metadata } = seed;
  const batch = writer(database);
  await batch.push(descriptor(
    "INSERT INTO data_app_generations_v2 (generation, metadata_json, seed_sha256) VALUES (?, ?, ?)",
    [generation, JSON.stringify(metadata), seedSha256],
  ));
  let position = 0;
  for (const [queryId, query] of Object.entries(queries)) {
    if (!plainObject(query)) throw failure("INVALID_SEED", "Each reviewed query must be an object.");
    const { rows = [], ...definition } = query;
    if (!Array.isArray(rows)) throw failure("INVALID_QUERY_ROWS", "Reviewed query rows must be an array.");
    const revision = crypto.randomUUID();
    await batch.push(descriptor(
      "INSERT INTO data_app_query_revisions_v2 (generation, query_id, position, query_json, revision, row_count) VALUES (?, ?, ?, ?, ?, ?)",
      [generation, queryId, position, JSON.stringify(definition), revision, rows.length],
    ));
    await writeRows(batch, generation, queryId, revision, rows);
    position += 1;
  }
  await batch.flush();
  const incomplete = await database.prepare(
    "SELECT q.query_id FROM data_app_query_revisions_v2 q " +
    "LEFT JOIN data_app_rows_v2 r ON r.generation = q.generation AND r.query_id = q.query_id AND r.revision = q.revision " +
    "WHERE q.generation = ? GROUP BY q.query_id, q.row_count HAVING COUNT(r.position) <> q.row_count LIMIT 1",
  ).bind(generation).first();
  if (incomplete) throw failure("INCOMPLETE_SNAPSHOT", "Staged snapshot row counts are incomplete.");

  // D1 writes are serialized. Compare against the head observed before loading
  // the seed; a delayed older initializer must not overwrite a newer winner.
  const activation = previous ? descriptor(
    "UPDATE data_app_snapshot_head_v2 SET current_generation = ?, seed_sha256 = ? " +
    "WHERE id = ? AND current_generation = ? AND seed_sha256 = ?",
    [generation, seedSha256, currentId, previous.current_generation, previous.seed_sha256],
  ) : descriptor(
    "INSERT INTO data_app_snapshot_head_v2 (id, current_generation, seed_sha256) VALUES (?, ?, ?) ON CONFLICT(id) DO NOTHING",
    [currentId, generation, seedSha256],
  );
  const [activated] = await execute(database, [activation]);
  if (activated.meta?.changes === 1) return { current_generation: generation, seed_sha256: seedSha256 };
  // Same-seed concurrent initialization is idempotent. A different-seed winner
  // requires the caller to retry from the current deployment, never a reset.
  const winner = await head(database);
  if (winner?.seed_sha256 === seedSha256) return winner;
  throw failure("SNAPSHOT_HEAD_CONFLICT", "The snapshot head changed during initialization; retry the current deployment.");
}

async function capturedSnapshot(database, seedSha256) {
  // D1 batch executes these reads in one transaction. Capture every revision
  // pointer with its matching snapshot metadata before streaming. Query
  // definitions are immutable within a generation and can be read separately;
  // aggregating their SQL/source metadata here would defeat the read budget.
  const [metadata, definitions] = await execute(database, [
    descriptor("SELECT h.current_generation, h.seed_sha256, g.metadata_json FROM data_app_snapshot_head_v2 h " +
      "JOIN data_app_generations_v2 g ON g.generation = h.current_generation WHERE h.id = ?", [currentId]),
    descriptor("SELECT q.generation, q.query_id, q.revision, q.row_count, e.executed_at FROM data_app_query_revisions_v2 q " +
      "LEFT JOIN data_app_execution_times_v2 e ON e.revision = q.revision " +
      "JOIN data_app_snapshot_head_v2 h ON h.current_generation = q.generation WHERE h.id = ? ORDER BY q.position", [currentId]),
  ]);
  const captured = metadata.results?.[0];
  if (!captured || captured.seed_sha256 !== seedSha256) {
    throw failure("SNAPSHOT_HEAD_CONFLICT", "The reviewed snapshot changed before its response was captured.");
  }
  return { metadata: captured.metadata_json, queries: definitions.results ?? [] };
}

function objectPrefix(json) {
  if (typeof json !== "string" || !json.startsWith("{") || !json.endsWith("}")) {
    throw failure("INVALID_STORED_JSON", "Stored snapshot metadata is invalid.");
  }
  return json.slice(0, -1) + (json.length > 2 ? "," : "");
}

async function* snapshotChunks(database, captured) {
  yield objectPrefix(captured.metadata) + '"queries":{';
  let firstQuery = true;
  for (const query of captured.queries) {
    // The write budget bounds each definition, so read one at a time. Select
    // the captured generation, not the live head or mutable row revision: an
    // owner update changes the row pointer without changing this definition.
    const definition = await database.prepare(
      "SELECT query_json FROM data_app_query_revisions_v2 WHERE generation = ? AND query_id = ?",
    ).bind(query.generation, query.query_id).first();
    if (!definition) throw failure("INCOMPLETE_SNAPSHOT", "An immutable snapshot query definition is missing.");
    if (query.executed_at != null) {
      const value = JSON.parse(definition.query_json);
      value.source = { ...value.source, executedAt: query.executed_at };
      definition.query_json = JSON.stringify(value);
    }
    yield (firstQuery ? "" : ",") + JSON.stringify(query.query_id) + ":" + objectPrefix(definition.query_json) + '"rows":[';
    firstQuery = false;
    let position = 0, firstRow = true;
    while (position < query.row_count) {
      // The inner LIMIT bounds database work, and the cumulative UTF-8 length
      // bounds rows returned to this Worker. Write validation guarantees a
      // single stored row fits within the page byte budget.
      const page = await database.prepare(
        "SELECT position, row_json FROM (SELECT position, row_json, " +
        "SUM(length(CAST(row_json AS BLOB))) OVER (ORDER BY position) AS page_bytes FROM (" +
        "SELECT position, row_json FROM data_app_rows_v2 WHERE generation = ? AND query_id = ? AND revision = ? " +
        "AND position >= ? ORDER BY position LIMIT ?)) WHERE page_bytes <= ? ORDER BY position",
      ).bind(query.generation, query.query_id, query.revision, position, pageCandidates, pageBytes).all();
      const rows = page.results ?? [];
      if (!rows.length) throw failure("INCOMPLETE_SNAPSHOT", "An immutable snapshot revision is missing rows.");
      for (const row of rows) {
        if (row.position !== position) throw failure("INCOMPLETE_SNAPSHOT", "Snapshot row positions are not contiguous.");
        position += 1;
      }
      // Emit one bounded page rather than one stream pull per individual row.
      yield (firstRow ? "" : ",") + rows.map(row => row.row_json).join(",");
      firstRow = false;
    }
    yield "]}";
  }
  yield "}}";
}

export async function snapshotResponse(database, loadSeed, seedSha256) {
  await initializeSnapshot(database, loadSeed, seedSha256);
  const captured = await capturedSnapshot(database, seedSha256);
  const iterator = snapshotChunks(database, captured);
  const body = new ReadableStream({
    async pull(controller) {
      try {
        const { value, done } = await iterator.next();
        if (done) controller.close();
        else controller.enqueue(encoder.encode(value));
      } catch (error) {
        controller.error(error);
        await iterator.return?.();
      }
    },
    async cancel() { await iterator.return?.(); },
  });
  return new Response(body, { headers: {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "private, no-store",
  } });
}

export async function storedQueryExists(database, loadSeed, seedSha256, queryId) {
  await initializeSnapshot(database, loadSeed, seedSha256);
  const query = await database.prepare(
    "SELECT 1 AS found FROM data_app_query_revisions_v2 q JOIN data_app_snapshot_head_v2 h " +
    "ON h.current_generation = q.generation WHERE h.id = ? AND h.seed_sha256 = ? AND q.query_id = ?",
  ).bind(currentId, seedSha256, queryId).first();
  return Boolean(query);
}

export async function updateBoundedQuery(database, queryId, rows, generatedAt, seedSha256) {
  return updateBoundedQueries(database, [{ queryId, rows }], generatedAt, seedSha256);
}

export async function updateBoundedQueries(database, updates, generatedAt, seedSha256) {
  await ensureSchema(database);
  if (typeof generatedAt !== "string" || !Number.isFinite(Date.parse(generatedAt))) {
    throw failure("INVALID_GENERATED_AT", "A valid generatedAt timestamp is required.");
  }
  const current = await head(database);
  if (!current) throw failure("SNAPSHOT_NOT_INITIALIZED", "Initialize the reviewed snapshot before updating a query.");
  if (seedSha256 && current.seed_sha256 !== seedSha256) {
    throw failure("SNAPSHOT_HEAD_CONFLICT", "The reviewed snapshot changed before this query update.");
  }
  const generation = current.current_generation;
  const batch = writer(database), replacements = [];
  for (const { queryId, rows, executedAt } of updates) {
    const previous = await database.prepare(
      "SELECT revision FROM data_app_query_revisions_v2 WHERE generation = ? AND query_id = ?",
    ).bind(generation, queryId).first();
    if (!previous) throw failure("QUERY_NOT_FOUND", "Data app query was not found.");
    const revision = crypto.randomUUID();
    await writeRows(batch, generation, queryId, revision, rows);
    await batch.push(descriptor(
      "INSERT INTO data_app_execution_times_v2 (revision, executed_at) VALUES (?, " +
      "COALESCE(?, (SELECT executed_at FROM data_app_execution_times_v2 WHERE revision = ?)))",
      [revision, executedAt ?? null, previous.revision],
    ));
    await batch.flush();
    const written = await database.prepare(
      "SELECT COUNT(*) AS count FROM data_app_rows_v2 WHERE generation = ? AND query_id = ? AND revision = ?",
    ).bind(generation, queryId, revision).first();
    if (written?.count !== rows.length) throw failure("INCOMPLETE_QUERY", "The staged query revision is incomplete.");
    replacements.push({ queryId, revision, previous: previous.revision, count: rows.length });
  }
  // Materialize the eligibility check before changing any pointer. Every query
  // must still have its observed revision, or the entire update stays hidden.
  const payload = JSON.stringify(replacements);
  const expected = "WITH expected AS MATERIALIZED (SELECT " +
    "json_extract(value, '$.queryId') AS id, json_extract(value, '$.revision') AS revision, " +
    "json_extract(value, '$.previous') AS previous, json_extract(value, '$.count') AS count FROM json_each(?)) ";
  const [updated] = await execute(database, [
    descriptor(expected.slice(0, -1) + ", allowed AS MATERIALIZED (SELECT 1 WHERE " +
      "EXISTS (SELECT 1 FROM data_app_snapshot_head_v2 WHERE id = ? AND current_generation = ?) " +
      "AND NOT EXISTS (SELECT 1 FROM expected e LEFT JOIN data_app_query_revisions_v2 q " +
      "ON q.generation = ? AND q.query_id = e.id WHERE q.revision IS NOT e.previous)) " +
      "UPDATE data_app_query_revisions_v2 SET " +
      "revision = (SELECT revision FROM expected WHERE id = query_id), " +
      "row_count = (SELECT count FROM expected WHERE id = query_id) " +
      "WHERE generation = ? AND query_id IN (SELECT id FROM expected) AND EXISTS (SELECT 1 FROM allowed)",
      [payload, currentId, generation, generation, generation]),
    descriptor(expected + "UPDATE data_app_generations_v2 SET metadata_json = json_set(metadata_json, '$.generatedAt', ?) " +
      "WHERE generation = ? AND NOT EXISTS (SELECT 1 FROM expected e LEFT JOIN data_app_query_revisions_v2 q " +
      "ON q.generation = ? AND q.query_id = e.id WHERE q.revision IS NOT e.revision)",
      [payload, generatedAt, generation, generation]),
  ]);
  if (updated.meta?.changes !== updates.length) {
    throw failure("QUERY_REVISION_CONFLICT", "The query or snapshot changed while new rows were staged; retry against the current revision.");
  }
}

// Existing inline factory calls keep their original storage contract.
// External-asset publication uses the bounded generation API above; it does not
// migrate or reset populated legacy databases.
const legacySnapshotId = "current";
const legacyRowsPerStatement = 30;

const legacySchemas = [
  `CREATE TABLE IF NOT EXISTS data_app_snapshots (
    id TEXT PRIMARY KEY,
    metadata_json TEXT NOT NULL,
    seed_sha256 TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_queries (
    id TEXT PRIMARY KEY,
    position INTEGER NOT NULL,
    query_json TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS data_app_query_rows (
    query_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    row_json TEXT NOT NULL,
    PRIMARY KEY (query_id, position)
  )`,
];

async function legacyFingerprint(snapshot) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(snapshot)));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function legacyInsertRows(database, queryId, rows) {
  const statements = [];
  for (let offset = 0; offset < rows.length; offset += legacyRowsPerStatement) {
    const chunk = rows.slice(offset, offset + legacyRowsPerStatement);
    const placeholders = chunk.map(() => "(?, ?, ?)").join(", ");
    const values = chunk.flatMap((row, index) => [queryId, offset + index, JSON.stringify(row)]);
    statements.push(database.prepare(
      `INSERT INTO data_app_query_rows (query_id, position, row_json) VALUES ${placeholders}`,
    ).bind(...values));
  }
  return statements;
}

async function legacyInitializeSnapshot(database, snapshot, seedFingerprint) {
  if (typeof database?.prepare !== "function" || typeof database.batch !== "function") {
    throw new Error("The Sites D1 database is unavailable.");
  }

  await database.batch(legacySchemas.map((schema) => database.prepare(schema)));
  const seedHash = seedFingerprint ?? await legacyFingerprint(snapshot);
  const previous = await database.prepare(
    "SELECT seed_sha256 FROM data_app_snapshots WHERE id = ?",
  ).bind(legacySnapshotId).first();
  if (previous?.seed_sha256 === seedHash) return;

  const { queries = {}, ...metadata } = snapshot;
  const statements = [
    database.prepare("DELETE FROM data_app_query_rows"),
    database.prepare("DELETE FROM data_app_queries"),
    database.prepare(
      "INSERT INTO data_app_snapshots (id, metadata_json, seed_sha256) VALUES (?, ?, ?) "
        + "ON CONFLICT(id) DO UPDATE SET metadata_json = excluded.metadata_json, seed_sha256 = excluded.seed_sha256",
    ).bind(legacySnapshotId, JSON.stringify(metadata), seedHash),
  ];

  for (const [position, [queryId, query]] of Object.entries(queries).entries()) {
    const { rows = [], ...definition } = query;
    statements.push(database.prepare(
      "INSERT INTO data_app_queries (id, position, query_json) VALUES (?, ?, ?)",
    ).bind(queryId, position, JSON.stringify(definition)));
    statements.push(...legacyInsertRows(database, queryId, rows));
  }

  await database.batch(statements);
}

export async function storedSnapshot(database, seedSnapshot, seedFingerprint) {
  await legacyInitializeSnapshot(database, seedSnapshot, seedFingerprint);
  const [snapshot, queryResult, rowResult] = await database.batch([
    database.prepare("SELECT metadata_json FROM data_app_snapshots WHERE id = ?").bind(legacySnapshotId),
    database.prepare("SELECT id, query_json FROM data_app_queries ORDER BY position"),
    database.prepare(
      "SELECT query_id, row_json FROM data_app_query_rows ORDER BY query_id, position",
    ),
  ]);

  const queries = Object.fromEntries(queryResult.results.map(({ id, query_json }) => [
    id,
    { ...JSON.parse(query_json), rows: [] },
  ]));
  for (const { query_id, row_json } of rowResult.results) queries[query_id].rows.push(JSON.parse(row_json));
  return { ...JSON.parse(snapshot.results[0].metadata_json), queries };
}

export async function updateStoredQueries(database, updates, generatedAt) {
  await database.batch([
    ...updates.flatMap(({ queryId, rows, executedAt }) => [
      database.prepare("DELETE FROM data_app_query_rows WHERE query_id = ?").bind(queryId),
      ...legacyInsertRows(database, queryId, rows),
      ...(executedAt === undefined ? [] : [database.prepare(
        "UPDATE data_app_queries SET query_json = json_set(query_json, '$.source.executedAt', ?) WHERE id = ?",
      ).bind(executedAt, queryId)]),
    ]),
    database.prepare(
      "UPDATE data_app_snapshots SET metadata_json = json_set(metadata_json, '$.generatedAt', ?) WHERE id = ?",
    ).bind(generatedAt, legacySnapshotId),
  ]);
}
