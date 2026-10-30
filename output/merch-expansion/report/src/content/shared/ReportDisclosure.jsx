import React, { useState } from "react";

import { Icon } from "../../data-app-public.jsx";
import "./report-disclosure.css";

// Optional authored layout. Keep the enclosing source-aware component visible
// so its source menu and component permalink still have a reachable target.
export function ReportDisclosure({ id, label, children }) {
  const [open, setOpen] = useState(false);
  const contentId = `${id}:details`;
  return <div className="report-evidence-disclosure">
    <button type="button" className="report-evidence-disclosure-trigger"
      aria-expanded={open} aria-controls={contentId}
      onClick={() => setOpen((value) => !value)}>
      <Icon name={open ? "chevronDown" : "chevronRight"} />{label}
    </button>
    <div id={contentId} className="report-evidence-disclosure-content" hidden={!open}>
      {children}
    </div>
  </div>;
}
