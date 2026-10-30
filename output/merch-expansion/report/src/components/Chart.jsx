import React from "react";

import { ChartRenderer } from "../charting/ChartRenderer.jsx";
import { resolveChartSpec } from "../charting/chart-overrides.js";
import { useOptionalDataAppShell } from "../DataAppContext.jsx";

/** Connect authored charts to saved settings; editor previews use the pure renderer. */
export function Chart({ chartId, spec, dataInputs, ...props }) {
  const shell = useOptionalDataAppShell();
  const chart = resolveChartSpec(spec, chartId ? shell?.chartOverrides?.[chartId] : undefined, dataInputs);
  return <ChartRenderer {...props} chartId={chartId} spec={chart} />;
}
