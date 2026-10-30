import { reviewedSource } from "./source-provenance.js";
import { formatDateRange } from "./date-range.js";
import { dataAppThemes, dataAppThemePalette, dataAppThemeTokens } from "./theme-presets.js";

export const chartExportPresets = [
  { id: "original", label: "Original" },
  { id: "slide", label: "Slide", width: 920, height: 480, description: "Wide image for a slide" },
  { id: "document", label: "Document", width: 720, height: 400, description: "Image within a text column", adaptiveHeight: true },
  { id: "slack", label: "Slack", width: 640, height: 400, description: "Compact image for a message", adaptiveHeight: true },
  { id: "custom", label: "Custom" },
];

export function chartExportSize(width, height) {
  const bounded = (value, fallback, minimum) => Number.isFinite(Number(value))
    ? Math.max(minimum, Math.min(2400, Math.round(Number(value)))) : fallback;
  return { width: bounded(width, 1000, 320), height: bounded(height, 600, 240) };
}

export function chartExportControls(spec) {
  return {
    values: !spec.presentation && !["waterfall", "funnel", "sparkline", "heatmap", "boxPlot", "rankedList"].includes(spec.type),
    axes: !spec.presentation && !["pie", "funnel", "sparkline", "rankedList", "sankey"].includes(spec.type),
  };
}

export function chartExportSpec(spec, options) {
  const controls = chartExportControls(spec);
  return { ...spec,
    ...(spec.presentation ? { barOptions: { ...spec.barOptions, valueWidth: spec.barOptions?.valueWidth ?? 64 } } : {}),
    ...(controls.values ? { showValues: options.values } : {}),
    ...(controls.axes ? { showXAxisLabel: options.axes && spec.showXAxisLabel !== false,
      showYAxisLabel: options.axes && spec.showYAxisLabel !== false } : {}),
  };
}

export function chartExportMetadata(query, filters = []) {
  const source = reviewedSource(query?.source);
  const names = [...new Set([
    source.label !== "Reviewed query" ? source.label : "",
    ...source.tables,
    ...source.files.map(file => file.label.split(/[\\/]/u).at(-1)),
    ...source.links.map(link => typeof link === "string" ? new URL(link).hostname : link.label ?? new URL(link.href).hostname),
  ].filter(Boolean))];
  const captured = Number.isFinite(Date.parse(source.executedAt))
    ? `Captured ${formatDateRange(new Date(source.executedAt).toISOString().slice(0, 10))}` : "";
  return {
    source: [names.length ? `Source: ${names.join(" · ")}` : "", captured].filter(Boolean).join(" · "),
    filters: filters.filter(filter => filter.value !== "all" && filter.value != null)
      .map(filter => `${filter.label ?? filter.field}: ${Array.isArray(filter.value)
        ? filter.value.map(formatDateRange).join(", ") : formatDateRange(filter.value)}`).join(" · "),
  };
}

export function chartExportProvenance(query, filters = []) {
  return Object.values(chartExportMetadata(query, filters)).filter(Boolean).join(" · ");
}

export function chartExportFilename(title) {
  return `${String(title).normalize("NFKC").replace(/[^\p{L}\p{N}._ -]/gu, "")
    .trim().replace(/\s+/gu, "-").slice(0, 100) || "chart"}.png`;
}

export function chartExportAppearance(themeId, appearance, currentScheme = "light") {
  if (!["light", "dark"].includes(appearance)) return currentScheme === "dark" ? {} : { "--surface": "#fff" };
  const theme = dataAppThemes.find(theme => theme.id === themeId && theme.tokens && !(theme.darkOnly && appearance === "light"))
    ?? dataAppThemes.find(theme => theme.id === "codex-classic");
  const palette = dataAppThemePalette(theme, appearance);
  return { colorScheme: appearance,
    ...Object.fromEntries(dataAppThemeTokens.map((token, index) => [`--${token}`, palette[index]])),
    ...(appearance === "light" ? { "--surface": "#fff" } : {}),
    "--lightningcss-light": appearance === "light" ? "initial" : " ",
    "--lightningcss-dark": appearance === "dark" ? "initial" : " ",
  };
}
