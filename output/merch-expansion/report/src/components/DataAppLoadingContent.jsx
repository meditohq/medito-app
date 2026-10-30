import React from "react";

import { ComponentSkeleton } from "../charting/ChartState.jsx";

/** The shared page body skeleton, without a second top bar or page landmark. */
export function DataAppLoadingContent({ status = "Loading Data app…" }) {
  return <div className="dashboard-shell-loading-content">
    <span className="visually-hidden" role="status" aria-label={status}>{status}</span>
    <div className="dashboard-shell-loading-heading" aria-hidden="true">
      <div className="dashboard-shell-loading-line is-title" />
      <div className="dashboard-shell-loading-line is-description" />
    </div>
    <div className="dashboard-shell-loading-metrics" aria-hidden="true">
      {Array.from({ length: 4 }, (_, index) => (
        <div className="dashboard-shell-loading-card" key={index}>
          <div className="dashboard-shell-loading-line is-label" />
          <div className="dashboard-shell-loading-line is-value" />
          <div className="dashboard-shell-loading-line is-caption" />
        </div>
      ))}
    </div>
    <div className="dashboard-shell-loading-charts" aria-hidden="true">
      {["line", "bar"].map(type => (
        <div className="dashboard-shell-loading-card" key={type}>
          <div className="dashboard-shell-loading-line is-label" />
          <ComponentSkeleton chart={{ type }} />
        </div>
      ))}
    </div>
  </div>;
}
