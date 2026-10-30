import { dataAppPromptTarget } from "./runtime-environment.js";

// The hosted shell registers one chooser for every action. It reads the shared
// browser preference when an action runs, including changes from other dashboards.
let handoffHandler;

export function registerDataAppHandoff(handler) {
  handoffHandler = handler;
  return () => {
    if (handoffHandler === handler) handoffHandler = undefined;
  };
}

export function hasDataAppHandoff() {
  return Boolean(handoffHandler);
}

export function navigateDataAppHandoff(href, onNavigate) {
  if (!href || !globalThis.document?.body) return false;
  const link = document.createElement("a");
  link.href = href;
  link.target = dataAppPromptTarget(href);
  link.rel = "noopener noreferrer";
  link.hidden = true;
  link.setAttribute("data-data-app-handoff-navigation", "");
  document.body.appendChild(link);
  try {
    link.click();
    onNavigate?.();
    return true;
  } finally {
    link.remove();
  }
}

export function openDataAppHandoff(getHref, onNavigate, { requireTap = false } = {}) {
  if (!getHref()) return false;
  if (handoffHandler) return handoffHandler({ getHref, onNavigate, requireTap });
  return navigateDataAppHandoff(getHref(), onNavigate);
}

export function dataAppPromptLinkProps(getHref, onNavigate) {
  const href = getHref();
  return {
    href,
    target: dataAppPromptTarget(href),
    rel: "noopener noreferrer",
    onClick(event) {
      if (event.defaultPrevented) return;
      if (!href) {
        event.preventDefault();
        return;
      }
      if (handoffHandler) {
        event.preventDefault();
        openDataAppHandoff(getHref, onNavigate);
      } else {
        onNavigate?.();
      }
    },
  };
}
