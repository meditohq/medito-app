import React from "react";

import reviewedSnapshot from "./data.json";
import { DataAppRuntime } from "./DataAppRuntime.jsx";
import { DashboardContent } from "./content/dashboard/DashboardContent.jsx";
import { ReportContent } from "./content/report/ReportContent.jsx";

export function App({ hosted = globalThis.location?.hostname.endsWith(".chatgpt.site") ?? false } = {}) {
  return (
    <DataAppRuntime
      reviewedSnapshot={reviewedSnapshot}
      DashboardContent={DashboardContent}
      ReportContent={ReportContent}
      hosted={hosted}
    />
  );
}
