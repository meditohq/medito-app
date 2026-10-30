import { isCodexBrowser, safeDataAppSourceHref } from "./runtime-environment.js";

const LOCAL_PREVIEW_HOSTNAMES = new Set(["localhost", "127.0.0.1", "::1", "[::1]", "terminal.local"]);

// Freeze the rendered datum, not the distance between the axis's display labels.
// Tick density is a readability decision and says nothing about selection scope.
export function chartPointSelection(wrapper, target, readStyle = globalThis.getComputedStyle) {
  const wrapperBounds = wrapper.getBoundingClientRect();
  if (!wrapperBounds.width || !wrapperBounds.height) return null;
  const explicitMark = target?.closest?.(".recharts-dot");
  const explicitDot = explicitMark?.matches?.("circle") ? explicitMark : explicitMark?.querySelector?.("circle");
  const activeDots = [...wrapper.querySelectorAll(".recharts-active-dot circle")];
  const cursor = wrapper.querySelector(".recharts-tooltip-cursor");
  const cursorBounds = cursor?.getBoundingClientRect();
  const dotBounds = (explicitDot ?? activeDots[0])?.getBoundingClientRect();
  const thinCursor = cursorBounds?.height > 2 && cursorBounds.width <= 2;
  const center = explicitDot && dotBounds?.width > 0 ? dotBounds.left + dotBounds.width / 2
    : thinCursor ? cursorBounds.left + cursorBounds.width / 2
      : dotBounds?.width > 0 ? dotBounds.left + dotBounds.width / 2 : null;
  if (!Number.isFinite(center)) return null;
  const plot = thinCursor ? cursorBounds : wrapper.querySelector(".recharts-cartesian-grid")?.getBoundingClientRect() ?? wrapperBounds;
  if (!(plot.height > 0)) return null;
  const scaleX = (wrapper.offsetWidth || wrapperBounds.width) / wrapperBounds.width;
  const scaleY = (wrapper.offsetHeight || wrapperBounds.height) / wrapperBounds.height;
  const left = (center - wrapperBounds.left) * scaleX - 0.5;
  const top = (plot.top - wrapperBounds.top) * scaleY;
  const activeAtCenter = activeDots.filter(dot => {
    const bounds = dot.getBoundingClientRect();
    return Math.abs(bounds.left + bounds.width / 2 - center) <= 2;
  });
  const dots = activeAtCenter.length ? activeAtCenter : explicitDot ? [explicitDot] : [];
  const points = dots.flatMap(dot => {
    const bounds = dot.getBoundingClientRect();
    const x = bounds.left + bounds.width / 2;
    if (!bounds.width || !bounds.height || Math.abs(x - center) > 2) return [];
    const style = readStyle?.(dot);
    return [{ x: (x - wrapperBounds.left) * scaleX - left,
      y: (bounds.top + bounds.height / 2 - wrapperBounds.top) * scaleY - top,
      radius: bounds.width * scaleX / 2,
      fill: style?.fill || "var(--chart-1)", stroke: style?.stroke || "var(--surface)",
      strokeWidth: Number.parseFloat(style?.strokeWidth) || 0,
      opacity: style?.opacity || 1, fillOpacity: style?.fillOpacity || 1 }];
  });
  return { kind: "region", element: wrapper, left, top, width: 1, height: plot.height * scaleY,
    selectionType: "point", points, cursorStroke: cursor ? readStyle?.(cursor)?.stroke : "var(--border)" };
}

export function pinnedChartCardPosition(anchor, card, viewport, padding = 12) {
  const width = Math.min(card.width, Math.max(0, viewport.width - 2 * padding));
  const left = Math.max(padding, Math.min(anchor.x, viewport.width - width - padding));
  const top = Math.max(padding, Math.min(anchor.y, Math.max(padding, viewport.height - 80)));
  return { left, top, width, maxHeight: Math.max(0, viewport.height - top - padding) };
}

export function chartMarkTooltipPosition(mark, card, viewport, padding = 12, gap = 8, pointer) {
  if (Number.isFinite(pointer?.x) && Number.isFinite(pointer?.y)) {
    if (pointer.type === "touch") {
      const clearance = Math.max(24, gap + 16);
      const above = pointer.y - clearance - card.height;
      const below = pointer.y + clearance;
      const top = above >= padding ? above : below + card.height <= viewport.height - padding ? below
        : Math.max(padding, Math.min(above, viewport.height - card.height - padding));
      return { left: Math.max(padding, Math.min(pointer.x - card.width / 2,
        viewport.width - card.width - padding)), top };
    }
    const x = pointer.x + gap + card.width <= viewport.width - padding ? pointer.x + gap : pointer.x - gap - card.width;
    const above = pointer.y - gap - card.height;
    const y = pointer.y + gap + card.height <= viewport.height - padding ? pointer.y + gap
      : above >= padding ? above : viewport.height - card.height - padding;
    return { left: Math.max(padding, Math.min(x, viewport.width - card.width - padding)),
      top: Math.max(padding, Math.min(y, viewport.height - card.height - padding)) };
  }
  const left = Math.max(padding, Math.min(mark.left + mark.width / 2 - card.width / 2, viewport.width - card.width - padding));
  const above = mark.top - gap - card.height;
  const top = Math.max(padding, Math.min(above >= padding ? above : mark.bottom + gap, viewport.height - card.height - padding));
  return { left, top };
}

// Recharts' public Tooltip.position is relative to its chart, including CSS-scaled previews.
export function chartPointerTooltipPosition(bounds, size, card, viewport, pointer) {
  const position = chartMarkTooltipPosition(bounds, card, viewport, 12, 8, pointer);
  return { x: (position.left - bounds.left) * (size.width / bounds.width || 1),
    y: (position.top - bounds.top) * (size.height / bounds.height || 1) };
}

function currentUserAgent() {
  return globalThis.navigator?.userAgent;
}

function currentHostname() {
  return globalThis.window?.location?.hostname;
}

function isLocalPreviewHostname(hostname) {
  const normalized = typeof hostname === "string" ? hostname.toLowerCase() : "";
  return LOCAL_PREVIEW_HOSTNAMES.has(normalized) || normalized.endsWith(".localhost");
}

export function canUseDashboardAsk({ mode, userAgent = currentUserAgent(), hostname = currentHostname() }) {
  return mode === "view" && !isCodexBrowser(userAgent) && !isLocalPreviewHostname(hostname);
}

function sitesProjectReference(title, projectId) {
  if (typeof projectId !== "string" || !/^[A-Za-z0-9][A-Za-z0-9_-]*$/u.test(projectId)) return null;
  // The public handoff accepts canonical Site references; Web applies composer escaping.
  const escapedTitle = String(title)
    .replace(/\r\n?|\n/g, " ")
    .replaceAll("\\", "\\\\")
    .replaceAll("[", "\\[")
    .replaceAll("](", "]\\(")
    .replaceAll("]", "\\]");
  return `[${escapedTitle}](sites-project://${encodeURIComponent(projectId).replaceAll(")", "\\)")})`;
}

export function dashboardAskPrompt({
  question,
  dashboardTitle,
  dashboardUrl,
  dashboardProjectId,
  dashboardProjectRoot,
  componentKind,
  componentTitle,
  selectedContext,
  selectedContextLabel = "Selected context",
}) {
  const trimmedQuestion = question.trim();
  if (!trimmedQuestion) return null;
  const viewUrl = safeDataAppSourceHref(dashboardUrl);
  if (viewUrl) {
    const title = String(dashboardTitle ?? "Dashboard").replace(/[\r\n]/gu, " ")
      .replace(/[\\\[\]]/gu, "\\$&");
    return [
      trimmedQuestion,
      `Reuse or open [${title}](<${viewUrl}>) in the browser pane; read its current Data app context.`,
      componentTitle ? `${componentKind === "chart" ? "Chart" : "Component"}: ${componentTitle}` : null,
      selectedContext ? `${selectedContextLabel}: ${selectedContext}` : null,
    ].filter(Boolean).join("\n\n");
  }
  const siteReference = sitesProjectReference(dashboardTitle, dashboardProjectId);

  return [
    siteReference ? `Answer this question about ${siteReference}:` : `Dashboard: ${dashboardTitle}`,
    dashboardProjectRoot ? `Dashboard project directory: ${dashboardProjectRoot}` : null,
    componentTitle ? `${componentKind === "chart" ? "Chart" : "Component"}: ${componentTitle}` : null,
    `${selectedContextLabel}: ${selectedContext}`,
    `Question: ${trimmedQuestion}`,
  ]
    .filter((entry) => entry !== null)
    .join("\n");
}
