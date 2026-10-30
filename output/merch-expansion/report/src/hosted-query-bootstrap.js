import { parseJsonResponse } from "./streaming-json.js";

// Only explicitly packaged, dependency-aware content uses the partial bootstrap.
// Older clients, ordinary apps and snapshots with owner edits keep the full path.
export async function loadHostedSnapshot(reviewedSnapshot, { signal, request = fetch } = {}) {
  const loading = reviewedSnapshot?._dataAppQueryLoading;
  if (loading?.version === 1) {
    const response = await request("/api/snapshot/head", { signal });
    if (response.ok) {
      const head = await response.json();
      if (head.supported === true) {
        if (head.snapshotSha256 !== loading.snapshotSha256
          || !head.queries || Array.isArray(head.queries)
          || Object.keys(head.queries).length !== Object.keys(reviewedSnapshot.queries).length
          || Object.keys(reviewedSnapshot.queries).some(id => !Object.hasOwn(head.queries, id)
            || head.queries[id]?.revision !== "seed")) {
          throw new Error("This dashboard deployment changed. Reload the page to load its current data.");
        }
        return { snapshot: reviewedSnapshot, deferred: true };
      }
      if (head.supported !== false) throw new Error("Data app query loading is unavailable.");
    } else if (response.status !== 404 && response.status !== 405) {
      throw new Error("Data app query loading is unavailable.");
    }
  }
  const response = await request("/api/snapshot", { signal });
  if (!response.ok) throw new Error("Data app snapshot is unavailable.");
  return { snapshot: await parseJsonResponse(response), deferred: false };
}
