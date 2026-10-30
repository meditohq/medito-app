import React from "react";
import { ChartRenderer } from "../charting/ChartRenderer.jsx";
import { resolveChartSpec } from "../charting/chart-overrides.js";
import { useOptionalDataAppShell } from "../DataAppContext.jsx";
import { DataComponent } from "./DataComponent.jsx";

/** A source-backed chart, without choosing its layout or analytical content. */
export function EvidenceChart({
  id, spec, dataInputs, rows, sourceRows, height = 240, chartOptions, renderPlot, children,
  ...componentProps
}) {
  const shell = useOptionalDataAppShell();
  if (shell?.visible?.(id) === false) return null;
  const chart = resolveChartSpec(spec, shell?.chartOverrides?.[id], dataInputs);
  const plot = <ChartRenderer {...chartOptions} {...shell?.chartProps?.(id)}
    chartId={id} spec={chart} rows={rows} height={height} />;
  return <DataComponent {...componentProps} id={id} kind="chart" chart={chart}
    displayRows={rows} sourceRows={sourceRows} loadingHeight={componentProps.loadingHeight ?? height}>
    {renderPlot ? renderPlot(plot, chart) : plot}
    {children != null && <div className="evidence-chart-details">{children}</div>}
  </DataComponent>;
}
