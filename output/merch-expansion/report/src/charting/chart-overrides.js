import { chartDataInputKeys } from "./chart-data-shape.js";

/** Saved settings are complete snapshots. Reviewed inputs stay current with the rows. */
export function resolveChartSpec(authored, saved, dataInputs) {
  if (saved == null && dataInputs == null) return authored;
  const chart = { ...(saved ?? authored) };
  // Older apps put these data inputs in spec. Preserve that API without merging settings.
  for (const inputs of [authored, dataInputs]) {
    for (const key of chartDataInputKeys) {
      if (Object.hasOwn(inputs ?? {}, key)) chart[key] = inputs[key];
    }
  }
  return chart;
}
