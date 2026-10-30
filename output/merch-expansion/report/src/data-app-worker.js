import { validatePresentation } from "./presentation-state.js";
import { snapshotResponse, storedQueryExists, updateBoundedQueries, storedSnapshot, updateStoredQueries } from "./snapshot-storage.js";
import { validateSnapshotIndex, usesObjectSnapshot, objectSnapshotIsUnedited, objectQueryRowsResponse, objectSnapshotResponse, updateObjectQueries } from "./object-snapshot-storage.js";

import { normalizeOwnerEmail } from "./owner-email.js";

export { validatePresentation };

const id = "current";
const presentationSchemaSql = `
  CREATE TABLE IF NOT EXISTS data_app_presentation_v1 (
    id TEXT PRIMARY KEY,
    presentation_json TEXT NOT NULL,
    revision INTEGER NOT NULL,
    updated_at TEXT NOT NULL
  )
`;

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "private, no-store",
    },
  });
}

function componentPermalinkPath(pathname) {
  const match = /^\/_data\/(charts|components)\/([^/]+)(\/detail)?$/u.exec(pathname);
  if (!match || (match[1] === "components" && match[3])) return false;

  try {
    const componentId = decodeURIComponent(match[2]);
    return (
      componentId.length <= 200 &&
      Boolean(componentId.trim()) &&
      componentId !== "." &&
      componentId !== ".." &&
      !/[\\/\0]/u.test(componentId)
    );
  } catch {
    return false;
  }
}

function authenticatedViewerEmail(request) {
  return normalizeOwnerEmail(request.headers.get("oai-authenticated-user-email"));
}

async function sha256(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function isOwnerHash(value) {
  return typeof value === "string" && /^[a-f\d]{64}$/u.test(value);
}

function htmlWithSitesProject(dataAppHtml, projectId) {
  if (!projectId) return dataAppHtml;
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]*$/u.test(projectId)) {
    throw new Error("The Sites project ID is invalid.");
  }
  // Inspect head markup, not matching strings inside scripts, styles, or comments.
  const tags = /<!--[\s\S]*?-->|<(script|style|title|textarea)\b(?:"[^"]*"|'[^']*'|[^'">])*>[\s\S]*?<\/\1\s*>|<(\/?)([a-z][a-z\d:-]*)\b((?:"[^"]*"|'[^']*'|[^'">])*)>/giu;
  let head;
  for (const tag of dataAppHtml.matchAll(tags)) {
    const closing = tag[2];
    const name = tag[3]?.toLowerCase();
    if (!head) {
      if (name === "head" && !closing) head = tag;
      continue;
    }
    if (name === "head" && closing) break;
    if (name !== "meta" || closing) continue;
    const attributes = /([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/gu;
    for (const attribute of tag[4].matchAll(attributes)) {
      if (
        attribute[1].toLowerCase() === "name" &&
        (attribute[2] ?? attribute[3] ?? attribute[4] ?? "").toLowerCase() === "data-app-sites-project"
      ) {
        throw new Error("The reviewed Data app HTML must not define its Sites project identity.");
      }
    }
  }
  if (!head) throw new Error("The reviewed Data app HTML must contain a head element.");
  const marker = `<meta name="data-app-sites-project" content="${projectId}">`;
  return `${dataAppHtml.slice(0, head.index + head[0].length)}${marker}${dataAppHtml.slice(head.index + head[0].length)}`;
}

export function createDataAppWorker({
  html: dataAppHtml,
  projectId = "",
  seedSnapshot,
  initialPresentation = {},
  deploymentAssets,
  deploymentUploadAuthorization,
  seedSnapshotSha256,
  snapshotIndex,
}) {
  if (seedSnapshotSha256 !== undefined && !isOwnerHash(seedSnapshotSha256)) {
    throw new Error("The canonical Data app seed fingerprint is invalid.");
  }
  const servedHtml = deploymentAssets ? null : htmlWithSitesProject(dataAppHtml, projectId);
  if (deploymentAssets) {
    for (const kind of ["html", "snapshot"]) {
      const asset = deploymentAssets[kind];
      if (!asset || !/^[a-f\d]{64}$/u.test(asset.sha256)
        || asset.key !== `data-app/${kind}/${asset.sha256}`
        || !Number.isSafeInteger(asset.bytes) || asset.bytes <= 0) {
        throw new Error("The Data app deployment asset descriptor is invalid.");
      }
    }
    if (snapshotIndex) validateSnapshotIndex(snapshotIndex, deploymentAssets.snapshot);
  } else if (snapshotIndex) {
    throw new Error("An indexed snapshot requires immutable deployment assets.");
  }

  async function deploymentAsset(environment, kind) {
    const asset = await environment.BUCKET?.get(deploymentAssets[kind].key);
    if (!asset || asset.size !== deploymentAssets[kind].bytes
      || asset.customMetadata?.sha256 !== deploymentAssets[kind].sha256) {
      throw new Error(`The Data app ${kind} asset is unavailable.`);
    }
    return asset;
  }

  async function reviewedSeed(environment) {
    if (!deploymentAssets) return seedSnapshot;
    return (await deploymentAsset(environment, "snapshot")).json();
  }
  // Raw immutable asset bytes may change with JSON formatting. A verified
  // canonical parsed-seed hash preserves owner edits across that repackaging.
  const seedFingerprint = seedSnapshotSha256 ?? deploymentAssets?.snapshot.sha256;
  let legacySeedFingerprint;
  const inlineSnapshot = async (database) => {
    legacySeedFingerprint ??= sha256(JSON.stringify(seedSnapshot));
    return storedSnapshot(database, seedSnapshot, await legacySeedFingerprint);
  };
  async function uploadCanProceed(request, environment) {
    if (await viewerCanEdit(request, environment)) return true;
    const token = request.headers.get("x-data-app-deployment-token");
    return Boolean(token && token.length <= 256 && deploymentUploadAuthorization
      && Date.now() < Date.parse(deploymentUploadAuthorization.expiresAt)
      && isOwnerHash(deploymentUploadAuthorization.sha256)
      && await sha256(token) === deploymentUploadAuthorization.sha256);
  }
  function storageFailure(error) {
    const conflict = ["SNAPSHOT_HEAD_CONFLICT", "QUERY_REVISION_CONFLICT"].includes(error?.code);
    return json({ error: error instanceof Error ? error.message : "Snapshot storage is unavailable.", code: error?.code ?? "SNAPSHOT_UNAVAILABLE" }, conflict ? 409 : 503);
  }
  const presentationSeed = { ...validatePresentation(initialPresentation) };
  // A reviewed local seed cannot fabricate a creator-verified badge.
  delete presentationSeed.verification;

  async function viewerCanEdit(request, environment) {
    // Sites manages the current owner's identity independently of published code.
    // Read it for each request so republishing cannot claim or retain ownership.
    const ownerEmailSha256 = environment?.DATA_APP_OWNER_EMAIL_SHA256;
    if (!isOwnerHash(ownerEmailSha256)) return false;
    // Sites replaces this header with the authenticated visitor's email.
    const email = authenticatedViewerEmail(request);
    return email !== null && (await sha256(email)) === ownerEmailSha256;
  }

  async function storedPresentation(database) {
    if (!database?.prepare) throw new Error("The Sites D1 database is unavailable.");
    await database.prepare(presentationSchemaSql).run();
    await database
      .prepare(
        "INSERT INTO data_app_presentation_v1 (id, presentation_json, revision, updated_at) " +
          "VALUES (?, ?, ?, ?) ON CONFLICT(id) DO NOTHING",
      )
      .bind(id, JSON.stringify(presentationSeed), 0, new Date().toISOString())
      .run();
    const row = await database
      .prepare("SELECT presentation_json, revision, updated_at FROM data_app_presentation_v1 WHERE id = ?")
      .bind(id)
      .first();
    return { presentation: JSON.parse(row.presentation_json), revision: row.revision, updatedAt: row.updated_at };
  }

  return {
    async fetch(request, environment) {
      const { pathname, searchParams } = new URL(request.url);
      // Sites may add infrastructure scripts to text/html responses after the
      // Worker runs. Verify the immutable uploaded bytes through a gated raw
      // read without altering normal browser HTML or its platform protections.
      if (deploymentAssets && pathname === "/api/deployment-assets/html" && request.method === "GET") {
        if (!(await uploadCanProceed(request, environment))) return json({ error: "Deployment upload authorization is required." }, 403);
        try {
          const asset = await deploymentAsset(environment, "html");
          return new Response(asset.body, { headers: {
            "content-type": "application/octet-stream",
            "cache-control": "private, no-store",
          } });
        } catch { return json({ error: "Deployment HTML is unavailable." }, 503); }
      }
      if (deploymentAssets && pathname === "/api/deployment-assets/snapshot" && request.method === "GET") {
        const parameters = [...searchParams];
        const historicalHash = parameters.length === 1 && parameters[0][0] === "sha256" ? parameters[0][1] : null;
        if (parameters.length && !isOwnerHash(historicalHash)) {
          return json({ error: "An immutable snapshot read requires one valid sha256 parameter." }, 400);
        }
        // The deployment token is scoped to the current configured asset. A
        // historical hash must not turn that token into a bucket read capability.
        if (!(historicalHash ? await viewerCanEdit(request, environment) : await uploadCanProceed(request, environment))) {
          return json({ error: "Immutable snapshot read authorization is required." }, 403);
        }
        try {
          const asset = historicalHash
            ? await environment.BUCKET?.get(`data-app/snapshot/${historicalHash}`)
            : await deploymentAsset(environment, "snapshot");
          if (!asset || !Number.isSafeInteger(asset.size) || asset.size <= 0
            || asset.customMetadata?.sha256 !== (historicalHash ?? deploymentAssets.snapshot.sha256)) {
            throw new Error("The immutable snapshot asset is unavailable.");
          }
          return new Response(asset.body, { headers: {
            "content-type": "application/octet-stream",
            "cache-control": "private, no-store",
          } });
        } catch { return json({ error: "Immutable snapshot is unavailable." }, 503); }
      }
      if (deploymentAssets && pathname.startsWith("/api/deployment-assets/") && request.method === "PUT") {
        if (!(await uploadCanProceed(request, environment))) return json({ error: "Deployment upload authorization is required." }, 403);
        const kind = pathname.slice("/api/deployment-assets/".length);
        if (kind !== "html" && kind !== "snapshot") return json({ error: "Unknown deployment asset." }, 404);
        if (kind === "snapshot" && searchParams.size) {
          return json({ error: "Only the current configured snapshot can be uploaded." }, 400);
        }
        const descriptor = deploymentAssets[kind];
        const encoding = (request.headers.get("content-encoding") ?? "identity").trim().toLowerCase();
        if (encoding !== "identity" && encoding !== "gzip") return json({ error: "Deployment asset encoding is not supported." }, 400);
        const contentLength = request.headers.get("content-length");
        if (encoding === "gzip"
          ? !/^[1-9]\d*$/u.test(contentLength ?? "") || !Number.isSafeInteger(Number(contentLength))
          : contentLength !== String(descriptor.bytes)) return json({ error: "Deployment asset size does not match." }, 400);
        if (!request.body) return json({ error: "Deployment asset body is required." }, 400);
        if (!environment.BUCKET?.put) return json({ error: "Deployment asset storage is unavailable." }, 503);
        try {
          // Compression changes transport bytes only. Bound decoded output to
          // the reviewed asset size and retain its original checksum and key.
          const body = encoding === "gzip"
            ? request.body.pipeThrough(new DecompressionStream("gzip")).pipeThrough(new FixedLengthStream(descriptor.bytes))
            : request.body;
          // R2 verifies the streamed object's checksum before storing it. Never
          // materialize a large HTML or snapshot upload in the Worker heap.
          // https://developers.cloudflare.com/r2/api/workers/workers-api-reference/#r2putoptions
          const stored = await environment.BUCKET.put(descriptor.key, body, {
            sha256: descriptor.sha256,
            httpMetadata: { contentType: kind === "html" ? "text/html; charset=utf-8" : "application/json; charset=utf-8" },
            customMetadata: { sha256: descriptor.sha256 },
          });
          if (!stored || stored.size !== descriptor.bytes) {
            return json({ error: "Deployment asset size does not match." }, 400);
          }
          return json({ kind, sha256: descriptor.sha256, bytes: stored.size });
        } catch {
          return json({ error: "Deployment asset upload failed integrity or storage validation." }, 400);
        }
      }
      const isComponentPermalink =
        (request.method === "GET" || request.method === "HEAD") && componentPermalinkPath(pathname);
      if (pathname === "/" || pathname === "/index.html" || isComponentPermalink) {
        if (deploymentAssets) {
          try {
            const asset = await deploymentAsset(environment, "html");
            return new Response(request.method === "HEAD" ? null : asset.body, {
              headers: { "content-type": "text/html; charset=utf-8", "cache-control": "private, no-store" },
            });
          } catch {
            return new Response("Data app deployment assets are unavailable.", { status: 503 });
          }
        }
        return new Response(isComponentPermalink && request.method === "HEAD" ? null : servedHtml, {
          headers: { "content-type": "text/html; charset=utf-8" },
        });
      }

      // These reads have the same Site-viewer boundary as /api/snapshot.
      // Only current, unedited indexed data advertises lazy query loading.
      if (pathname === "/api/snapshot/head" && request.method === "GET") {
        if (searchParams.size) return json({ error: "Snapshot head parameters are not supported." }, 400);
        try {
          if (!snapshotIndex || !await usesObjectSnapshot(environment.DB)
            || !await objectSnapshotIsUnedited(environment.DB, seedFingerprint)) return json({ supported: false });
          const base = await deploymentAsset(environment, "snapshot");
          await base.body?.cancel();
          return json({ supported: true, snapshotSha256: deploymentAssets.snapshot.sha256, generatedAt: null,
            queries: Object.fromEntries(Object.keys(snapshotIndex.queries).map(queryId => [queryId, { revision: "seed" }])) });
        } catch (error) { return storageFailure(error); }
      }

      if (pathname === "/api/query-rows" && request.method === "GET") {
        if (!snapshotIndex) return json({ error: "Lazy query loading is unavailable for this snapshot." }, 409);
        if (searchParams.size !== 3 || ["queryId", "snapshot", "revision"].some(name => searchParams.getAll(name).length !== 1)) {
          return json({ error: "A query ID, current snapshot and query revision are required." }, 400);
        }
        const queryId = searchParams.get("queryId");
        if (!Object.hasOwn(snapshotIndex.queries, queryId)) return json({ error: "Data app query was not found." }, 404);
        if (searchParams.get("snapshot") !== deploymentAssets.snapshot.sha256 || searchParams.get("revision") !== "seed") {
          return json({ error: "The snapshot changed; reload the complete current snapshot." }, 409);
        }
        try {
          if (!await usesObjectSnapshot(environment.DB) || !await objectSnapshotIsUnedited(environment.DB, seedFingerprint)) {
            return json({ error: "The snapshot changed; reload the complete current snapshot." }, 409);
          }
          return await objectQueryRowsResponse(environment.BUCKET, deploymentAssets.snapshot, snapshotIndex, queryId);
        } catch (error) { return storageFailure(error); }
      }

      if (pathname === "/api/snapshot" && request.method === "GET") {
        try {
          if (snapshotIndex && await usesObjectSnapshot(environment.DB)) {
            const base = await deploymentAsset(environment, "snapshot");
            return await objectSnapshotResponse(environment.DB, environment.BUCKET, base, snapshotIndex, seedFingerprint);
          }
          return deploymentAssets
            ? await snapshotResponse(environment.DB, () => reviewedSeed(environment), seedFingerprint)
            : json(await inlineSnapshot(environment.DB));
        } catch (error) { return storageFailure(error); }
      }

      if (pathname === "/api/presentation" && request.method === "GET") {
        return json({
          ...(await storedPresentation(environment.DB)),
          canEdit: await viewerCanEdit(request, environment),
          ownerEnvironmentConfigured: isOwnerHash(environment?.DATA_APP_OWNER_EMAIL_SHA256),
        });
      }

      if (pathname === "/api/presentation" && request.method === "PUT") {
        if (!(await viewerCanEdit(request, environment))) {
          return json({ error: "Only the current Site owner can edit the Data app presentation." }, 403);
        }
        let body;
        let presentation;
        try {
          body = await request.json();
          presentation = validatePresentation(body.presentation);
        } catch (error) {
          return json({ error: error instanceof Error ? error.message : "Presentation is invalid." }, 400);
        }
        if (!Number.isSafeInteger(body.revision) || body.revision < 0) {
          return json({ error: "A valid presentation revision is required." }, 400);
        }
        if (
          body.verificationAction !== undefined &&
          body.verificationAction !== "verify" &&
          body.verificationAction !== "remove"
        ) {
          return json({ error: "Dashboard verification action must be verify or remove." }, 400);
        }
        const current = await storedPresentation(environment.DB);
        if (current.revision !== body.revision) return json(current, 409);
        const updatedAt = new Date().toISOString();
        if (body.verificationAction === "remove") {
          delete presentation.verification;
        } else if (body.verificationAction === "verify") {
          presentation.verification = current.presentation.verification ?? {
            verifiedBy: authenticatedViewerEmail(request), verifiedAt: updatedAt,
          };
        } else if (presentation.verification) {
          if (!current.presentation.verification) {
            return json({ error: "Dashboard verification requires an explicit server-side verification action." }, 400);
          }
          presentation.verification = current.presentation.verification;
        }
        const result = await environment.DB.prepare(
          "UPDATE data_app_presentation_v1 SET presentation_json = ?, revision = revision + 1, " +
            "updated_at = ? WHERE id = ? AND revision = ?",
        )
          .bind(JSON.stringify(presentation), updatedAt, id, body.revision)
          .run();
        if (!result.meta?.changes) return json(await storedPresentation(environment.DB), 409);
        return json({ presentation, revision: body.revision + 1, updatedAt });
      }

      if ((pathname === "/api/queries" || pathname.startsWith("/api/queries/")) && request.method === "PUT") {
        if (!(await viewerCanEdit(request, environment))) {
          return json({ error: "Only the current Site owner can update reviewed Data app data." }, 403);
        }

        const batch = pathname === "/api/queries";
        const body = await request.json();
        if (!body || typeof body !== "object" || Array.isArray(body)
          || Object.keys(body).some((key) => !(batch ? ["updates"] : ["rows", "executedAt"]).includes(key))) {
          return json({ error: "Data app query updates are invalid." }, 400);
        }
        const updates = batch ? body.updates : [{
          queryId: decodeURIComponent(pathname.slice("/api/queries/".length)), ...body,
        }];
        if (!Array.isArray(updates) || !updates.length || updates.length > 100
          || updates.some((update) => !update || typeof update !== "object" || Array.isArray(update)
            || Object.keys(update).some((key) => !["queryId", "rows", "executedAt"].includes(key))
            || typeof update.queryId !== "string"
            || !Array.isArray(update.rows) || update.rows.length > 10_000
            || update.rows.some((row) => row === null || typeof row !== "object" || Array.isArray(row))
            || ((batch || update.executedAt !== undefined)
              && (typeof update.executedAt !== "string"
                || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(update.executedAt)
                || !Number.isFinite(Date.parse(update.executedAt)))))
          || new Set(updates.map(({ queryId }) => queryId)).size !== updates.length) {
          return json({ error: "Data app query updates require unique query IDs, valid rows, and source execution times." }, 400);
        }
        let objectStorage = false;
        try {
          objectStorage = Boolean(snapshotIndex && await usesObjectSnapshot(environment.DB));
          if (objectStorage) {
            // Validate the immutable base before creating any edit state.
            const base = await deploymentAsset(environment, "snapshot");
            await base.body?.cancel();
          }
          for (const { queryId } of updates) {
            const exists = objectStorage ? Object.hasOwn(snapshotIndex.queries, queryId) : deploymentAssets
              ? await storedQueryExists(environment.DB, () => reviewedSeed(environment), seedFingerprint, queryId)
              : Object.hasOwn((await inlineSnapshot(environment.DB)).queries, queryId);
            if (!exists) {
              return json({ error: "Data app query was not found." }, 404);
            }
          }
        } catch (error) { return storageFailure(error); }


        const generatedAt = new Date().toISOString();
        try {
          if (objectStorage) await updateObjectQueries(environment.DB, environment.BUCKET, seedFingerprint, updates, generatedAt, snapshotIndex);
          else if (deploymentAssets) await updateBoundedQueries(environment.DB, updates, generatedAt, seedFingerprint);
          else await updateStoredQueries(environment.DB, updates, generatedAt);
        }
        catch (error) { return storageFailure(error); }
        return json({ ...(batch ? { updates } : updates[0]), generatedAt });
      }

      return new Response("Not found", { status: 404 });
    },
  };
}
