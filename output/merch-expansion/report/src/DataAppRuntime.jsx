import React, { useEffect, useState } from "react";

import { DataAppShell } from "./DataAppShell.jsx";
import { loadHostedSnapshot } from "./hosted-query-bootstrap.js";
import { createQueryDataStore } from "./query-data-store.js";
import { DataAppLoadingContent } from "./components/DataAppLoadingContent.jsx";

function DataAppLoading() {
  return (
    <main className="dashboard-shell-loading" aria-busy="true">
      <div className="dashboard-shell-loading-topbar" aria-hidden="true">
        <div className="dashboard-shell-loading-line is-brand" />
        <div className="dashboard-shell-loading-line is-action" />
      </div>
      <DataAppLoadingContent />
    </main>
  );
}


// The protected runtime accepts authored content and reviewed data at its boundary.
// Neither the source-build wrapper nor the prebuilt browser bundle owns a second
// copy of the shell, its contexts, or the hosted permission/fetch behavior.
export function DataAppRuntime({
  reviewedSnapshot,
  createContent,
  DashboardContent,
  ReportContent,
  staticDemo = false,
  hosted = globalThis.location?.hostname.endsWith(".chatgpt.site") ?? false,
} = {}) {
  const [snapshot, setSnapshot] = useState(hosted ? null : reviewedSnapshot);
  const [presentationRecord, setPresentationRecord] = useState({ presentation: {}, revision: 0 });
  const [error, setError] = useState(null);
  const [queryDataStore, setQueryDataStore] = useState(null);

  useEffect(() => {
    if (!hosted) return;
    const controller = new AbortController();
    let active = true;
    let store;
    Promise.all([
      loadHostedSnapshot(reviewedSnapshot, { signal: controller.signal }),
      fetch("/api/presentation", { signal: controller.signal }).then(response => {
        if (!response.ok) throw new Error("Data app presentation is unavailable.");
        return response.json();
      }),
    ])
      .then(([{ snapshot: snapshotValue, deferred }, record]) => {
        if (!active) return;
        if (deferred) {
          store = createQueryDataStore(snapshotValue, {
            snapshotSha256: snapshotValue._dataAppQueryLoading.snapshotSha256,
            onChange: queries => {
              if (active) setSnapshot(current => ({ ...current, queries }));
            },
          });
          setQueryDataStore(store);
        }
        setPresentationRecord(record);
        setSnapshot(snapshotValue);
      })
      .catch((failure) => {
        controller.abort();
        if (active) setError(failure);
      });
    return () => {
      active = false;
      controller.abort();
      store?.dispose();
    };
  }, [hosted]);

  if (!snapshot) return error
    ? <main className="dashboard-shell-loading-error" role="alert">{error.message}</main>
    : <DataAppLoading />;
  return <ResolvedDataApp
    snapshot={snapshot}
    createContent={createContent}
    DashboardContent={DashboardContent}
    ReportContent={ReportContent}
    hosted={hosted}
    staticDemo={staticDemo}
    onSnapshotChange={setSnapshot}
    presentationRecord={presentationRecord}
    queryDataStore={queryDataStore}
  />;
}

function ResolvedDataApp({ snapshot, createContent, DashboardContent, ReportContent,
  hosted, staticDemo, onSnapshotChange, presentationRecord, queryDataStore }) {
  // Eager apps retain complete module-scope imports. Explicit on-demand apps
  // declare dependencies through QueryDataBoundary before reading reviewed rows.
  // Keep component identities stable through later data updates and edits.
  const [content] = useState(() => createContent
    ? createContent(snapshot) : { DashboardContent, ReportContent });
  const Content = snapshot.surface === "report" ? content.ReportContent : content.DashboardContent;

  return (
    <DataAppShell
      snapshot={snapshot}
      hosted={hosted}
      onSnapshotChange={onSnapshotChange}
      canEdit={!staticDemo && (!hosted || presentationRecord.canEdit === true)}
      persistLocally={!staticDemo}
      initialPresentation={presentationRecord.presentation}
      initialRevision={presentationRecord.revision}
      queryDataStore={queryDataStore}
    >
      <Content />
    </DataAppShell>
  );
}
