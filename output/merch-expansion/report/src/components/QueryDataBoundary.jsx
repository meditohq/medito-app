import React, { useEffect, useSyncExternalStore } from "react";

import { useOptionalDataAppShell } from "../DataAppContext.jsx";
import { ComponentSkeleton, ComponentState } from "../charting/ChartState.jsx";
import { DataAppLoadingContent } from "./DataAppLoadingContent.jsx";

const subscribeNone = () => () => {};
const eagerVersion = () => 0;

/** Put query-dependent calculations and controls inside this boundary. */
export function QueryDataBoundary({ queryIds = [], children, loadingLayout = "page", loadingKind = "chart", loadingHeight = 240 }) {
  const shell = useOptionalDataAppShell();
  const store = shell?.queryDataStore;
  useSyncExternalStore(store?.subscribe ?? subscribeNone, store?.getVersion ?? eagerVersion, store?.getVersion ?? eagerVersion);
  const key = JSON.stringify(queryIds);
  useEffect(() => {
    if (store) void store.ensure(JSON.parse(key)).catch(() => {});
  }, [store, key]);
  const ready = !store || store.isReady(queryIds);
  const error = store?.error(queryIds);
  if (ready) return children;
  const retry = () => { void store.ensure(queryIds).catch(() => {}); };
  if (!error && loadingLayout === "page") return <div className="dashboard-shell-loading-embedded" aria-busy="true">
    <DataAppLoadingContent status="Loading reviewed data" />
  </div>;
  return <div className="component-skeleton" aria-busy={!error || undefined}
    style={{ "--component-state-height": typeof loadingHeight === "number" ? `${loadingHeight}px` : loadingHeight }}>
    {error?.code === "SNAPSHOT_CHANGED" ? <div className="component-data-state" role="alert" style={{ minHeight: loadingHeight }}>
      <strong>Dashboard data changed.</strong><p>Reload the page to load the current data.</p>
    </div> : error ? <ComponentState error kind={loadingKind} height={loadingHeight} onRetry={retry} />
      : <div className="component-loading-body" role="status" aria-label="Loading reviewed data">
        <ComponentSkeleton kind={loadingKind} />
      </div>}
  </div>;
}
