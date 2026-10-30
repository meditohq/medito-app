import React from "react";

import { Icon, useDataApp } from "../../data-app-public.jsx";
import "./report-task-link.css";

// Optional authored companion to an existing editable recommendation. The
// protected shell owns current saved text, permissions, and task transport.
export function ReportTaskLink({ children, ...followUp }) {
  const { mode, reportFollowUpHref } = useDataApp();
  if (mode === "edit") return null;
  let link;
  try {
    link = reportFollowUpHref(followUp);
  } catch {
    // A cleared/oversized saved recommendation or unavailable task must not
    // prevent reading the report. Leave the runtime's validation in charge.
    return null;
  }
  if (!link?.href) return null;
  return <a className="report-task-link" {...link}>
    <span>{children}</span><Icon name="arrowUpRight" size={20} />
  </a>;
}
