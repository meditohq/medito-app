import React from "react";

// The card layout is shared; each surface supplies the icon for its source.
export function SourcePreviewCardContent({ preview, icon, sourceLabel }) {
  return <>
    <div className="source-preview-meta">{icon}
      <span>{[sourceLabel, preview.date].filter(Boolean).join(" · ")}</span></div>
    <div className="source-preview-title">{preview.title}</div>
    {preview.summary && <p className="source-preview-summary">{preview.summary}</p>}
  </>;
}
