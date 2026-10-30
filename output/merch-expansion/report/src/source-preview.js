import { safeSourceHref } from "./source-provenance.js";

// Destination identity, not an assertion about source authority. Never infer a
// provider from authored prose or load remote favicons into a shared artifact.
export function sourcePreviewProvider(href) {
  const safeHref = safeSourceHref(href);
  if (!safeHref?.startsWith("https:")) return { id: "web", label: "Source" };
  const { hostname, pathname } = new URL(safeHref);
  const within = (domain) => hostname === domain || hostname.endsWith(`.${domain}`);
  if (hostname === "docs.google.com") {
    if (pathname.startsWith("/document/")) return { id: "google-docs", label: "Google Docs" };
    if (pathname.startsWith("/spreadsheets/")) return { id: "google-sheets", label: "Google Sheets" };
    if (pathname.startsWith("/presentation/")) return { id: "google-slides", label: "Google Slides" };
    return { id: "google-drive", label: "Google Drive" };
  }
  if (hostname === "drive.google.com") return { id: "google-drive", label: "Google Drive" };
  if (within("slack.com")) return { id: "slack", label: "Slack" };
  if (within("notion.so") || within("notion.site")) return { id: "notion", label: "Notion" };
  if (hostname === "github.com") return { id: "github", label: "GitHub" };
  if (within("statsig.com")) return { id: "database", label: "Statsig" };
  if (hostname === "app.snowflake.com" || hostname === "console.cloud.google.com" && pathname.startsWith("/bigquery"))
    return { id: "database", label: hostname === "app.snowflake.com" ? "Snowflake" : "BigQuery" };
  return { id: "web", label: "Source" };
}

// Previews are authored, audience-approved report content, never fetched on hover.
export function sourcePreviewForHref(previews, href) {
  if (typeof href !== "string" || !previews || !Object.hasOwn(previews, href)) return null;
  const safeHref = safeSourceHref(href);
  if (!safeHref?.startsWith("https:")) return null;
  const entry = previews[href];
  if (!entry || entry.approvedForReport !== true) return null;
  const text = (value, max) => typeof value === "string" && value.trim().length <= max ? value.trim() : "";
  const title = text(entry.title, 200);
  const summary = text(entry.summary, 900);
  if (!title || !summary) return null;
  return { href: safeHref, title, summary, source: text(entry.source, 120), date: text(entry.date, 80) };
}

export function sourcePreviewLineIndex(rects, point) {
  if (!point || !rects.length) return 0;
  const distance = (rect) => {
    const x = Math.max(rect.left - point.x, 0, point.x - rect.right);
    const y = Math.max(rect.top - point.y, 0, point.y - rect.bottom);
    return x * x + y * y;
  };
  return rects.reduce((nearest, rect, index) => distance(rect) < distance(rects[nearest]) ? index : nearest, 0);
}

export function sourcePreviewPosition(anchor, panel, viewport) {
  const inset = 12;
  const gap = 8;
  const centeredLeft = anchor.left + anchor.width / 2 - panel.width / 2;
  const left = Math.max(inset, Math.min(centeredLeft, viewport.width - panel.width - inset));
  const aboveSpace = Math.max(0, Math.min(anchor.top, viewport.height - inset) - inset - gap);
  const belowSpace = Math.max(0, viewport.height - inset - Math.max(anchor.bottom, inset) - gap);
  const above = panel.height <= aboveSpace || (panel.height > belowSpace && aboveSpace >= belowSpace);
  const maxHeight = above ? aboveSpace : belowSpace;
  const height = Math.min(panel.height, maxHeight);
  const preferredTop = above ? anchor.top - height - gap : anchor.bottom + gap;
  const top = Math.max(inset, Math.min(preferredTop, viewport.height - height - inset));
  return { left, top, maxHeight };
}
