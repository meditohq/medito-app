import { canonicalDashboardPath } from "./chart-permalink.js";
import { dashboardViewSearchParams } from "./dashboard-url-state.js";
import { safeSourceHref } from "./source-provenance.js";

function isLocalDataApp(location) {
  if (location?.protocol === "file:") return Boolean(currentDataAppReference(location).htmlPath);
  return ["localhost", "127.0.0.1", "[::1]", "terminal.local"].includes(location?.hostname)
    || location?.hostname?.endsWith(".localhost");
}

// Keep report identity and task working directories on the same local-path
// boundary. Drive-relative paths and UNC shares are not absolute local paths.
export function isSafeLocalDataAppPath(value) {
  return typeof value === "string" && value.length <= 2048
    && /^(?:\/(?![\\/])|[A-Za-z]:[\\/])/u.test(value)
    && !/[\u0000-\u001f\u007f]/u.test(value);
}

// Older packaged Codex builds share ChatGPTBrowser with Atlas. Accept both during the client rollout.
const CODEX_BROWSER_USER_AGENT_PATTERN = /^(?:CodexBrowser|ChatGPTBrowser)(?:[ /]|$)/u;

export function isCodexBrowser(userAgent = globalThis.navigator?.userAgent) {
  // Honor an explicit host marker when its user agent is unbranded.
  return globalThis.window?.__codexBrowser === true
    || (typeof userAgent === "string" && CODEX_BROWSER_USER_AGENT_PATTERN.test(userAgent));
}

export function dataAppPromptDestination(
  location = globalThis.window?.location,
  userAgent = globalThis.navigator?.userAgent,
  destination,
) {
  if (destination !== undefined && destination !== "desktop" && destination !== "web") {
    throw new Error("Choose desktop or web for the ChatGPT destination.");
  }
  if (destination) return destination;
  return location?.protocol === "file:" || isLocalDevelopmentHost(location?.hostname) || isCodexBrowser(userAgent)
    ? "desktop"
    : "web";
}

function isLocalDevelopmentHost(hostname = "") {
  return (
    typeof hostname === "string" &&
    (["localhost", "127.0.0.1", "[::1]", "terminal.local"].includes(hostname) || hostname.endsWith(".localhost"))
  );
}

function normalizedLocalPreviewPath(value, directory = false) {
  if (typeof value !== "string" || !value || /[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u.test(value)) return null;

  const windowsDrive = /^[A-Za-z]:[\\/]/u.test(value);
  const windowsShare = /^(?:\\\\|\/\/)/u.test(value);
  const windows = windowsDrive || windowsShare;
  if (!windows && value.includes("\\")) return null;
  let path = windows ? value.replaceAll("\\", "/") : value;
  if (!directory && path.endsWith("/")) return null;

  let anchor;
  let remainder;
  if (windowsDrive) {
    anchor = path.slice(0, 3);
    remainder = path.slice(3);
  } else if (windowsShare) {
    const share = /^\/\/([^/]+)\/([^/]+)(?:\/|$)/u.exec(path);
    if (!share) return null;
    anchor = `//${share[1]}/${share[2]}`;
    remainder = path.slice(share[0].length);
  } else if (path.startsWith("/")) {
    anchor = "/";
    remainder = path.slice(1);
  } else {
    return null;
  }

  if (directory) remainder = remainder.replace(/\/+$/u, "");
  const parts = remainder ? remainder.split("/") : [];
  if (parts.some((part) => !part || part === "." || part === "..")) return null;
  if (windows) {
    const windowsParts = windowsShare ? [...anchor.slice(2).split("/"), ...parts] : parts;
    // Win32 removes trailing dots/spaces and gives colons/device prefixes special
    // meaning. Do not accept paths whose filesystem meaning differs from this
    // lexical containment check.
    if (windowsParts.some((part) => /[<>:"|?*]|[. ]$/u.test(part) || part === "." || part === "..")) return null;
  }

  path = parts.length ? `${anchor.endsWith("/") ? anchor : `${anchor}/`}${parts.join("/")}` : anchor;
  return { path, key: windows ? path.toLowerCase() : path, windows };
}

function localPreviewReference(source) {
  if (!["http:", "https:"].includes(source.protocol) || !isLocalDevelopmentHost(source.hostname)) return null;
  try {
    const entries = globalThis.document?.querySelectorAll?.('meta[name="data-app-local-reference"]');
    if (entries?.length !== 1) return null;
    const value = JSON.parse(entries[0].getAttribute("content"));
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    if (Object.keys(value).length !== 2 || !Object.hasOwn(value, "root") || !Object.hasOwn(value, "htmlPath")) {
      return null;
    }
    const root = normalizedLocalPreviewPath(value.root, true);
    const html = normalizedLocalPreviewPath(value.htmlPath);
    if (!root || !html || root.windows !== html.windows || !/\.html?$/iu.test(html.path)) return null;
    const prefix = root.key.endsWith("/") ? root.key : `${root.key}/`;
    if (!html.key.startsWith(prefix)) return null;
    return { root: root.path, htmlPath: html.path };
  } catch {
    return null;
  }
}

function hostedSitesProjectId(source) {
  if (
    source.protocol !== "https:" ||
    ![".chatgpt.site", ".chatgpt-team.site"].some((suffix) => source.hostname.endsWith(suffix))
  ) return null;
  const entries = globalThis.document?.querySelectorAll?.('meta[name="data-app-sites-project"]');
  if (entries?.length !== 1) return null;
  const projectId = entries[0].getAttribute("content");
  return typeof projectId === "string" && /^[A-Za-z0-9][A-Za-z0-9_-]*$/u.test(projectId)
    ? projectId
    : null;
}

// Dashboard navigation state is the only query data that may accompany an
// otherwise safe artifact URL. Keep source-link credential/path checks intact.
export function safeDataAppSourceHref(value) {
  if (typeof value !== "string") return null;
  try {
    const source = new URL(value);
    const view = dashboardViewSearchParams(source);
    if ([...source.searchParams].length !== [...view].length
      || [...source.searchParams.keys()].some(key => !view.has(key))) return null;
    source.search = "";
    const safe = safeSourceHref(source.href);
    if (!safe) return null;
    const result = new URL(safe);
    result.search = view.toString();
    return result.href;
  } catch {
    return null;
  }
}

// Read the current page without transferring credentials or unrelated routing
// parameters. Unlike the artifact identity, this also retains local preview URLs.
export function currentDataAppViewUrl(location = globalThis.window?.location) {
  if (!location?.href) return null;
  try {
    const source = new URL(location.href);
    if (!["http:", "https:"].includes(source.protocol)) return null;
    source.username = "";
    source.password = "";
    source.search = dashboardViewSearchParams(source).toString();
    source.hash = "";
    source.pathname = canonicalDashboardPath(source.pathname);
    return safeDataAppSourceHref(source.href);
  } catch {
    return null;
  }
}

export function codexDataAppPromptUrl(
  prompt,
  dataAppReference,
  location = globalThis.window?.location,
  userAgent = globalThis.navigator?.userAgent,
  destination,
  requiredViewUrl,
) {
  if (typeof prompt !== "string" || !prompt.trim()) {
    throw new Error("A Data app handoff requires a prompt.");
  }
  const local = isLocalDataApp(location);
  const desktop = dataAppPromptDestination(location, userAgent, destination) === "desktop";
  const viewUrl = requiredViewUrl === undefined
    ? currentDataAppViewUrl(location)
    : safeDataAppSourceHref(requiredViewUrl);
  if (requiredViewUrl !== undefined && !viewUrl) {
    throw new Error("The dashboard view link is unavailable. Reopen the dashboard before continuing.");
  }
  if (!desktop && requiredViewUrl !== undefined && isLocalDevelopmentHost(new URL(viewUrl).hostname)) {
    throw new Error("This preview is local to this task. Open it in desktop; ChatGPT on the web cannot read this local preview link.");
  }
  const threadId = local
    ? [
        globalThis.document?.querySelector?.('meta[name="data-app-local-thread"]')?.getAttribute("content"),
        new URLSearchParams(location?.hash?.slice(1)).get("codexThreadId"),
      ].find((value) => /^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/iu.test(value ?? ""))
    : null;
  const url = new URL(desktop
    ? threadId ? `codex://threads/${threadId}` : "codex://new"
    : "https://chatgpt.com/");
  url.searchParams.set(desktop ? "prompt" : "q", prompt);
  if (!desktop) {
    // Match the native handoff: prepare the composer without submitting it.
    url.searchParams.set("disable_auto_send", "1");
  } else if (local && !threadId) {
    const root = (dataAppReference ?? currentDataAppReference(location)).root;
    if (isSafeLocalDataAppPath(root)) url.searchParams.set("path", root);
  }
  if (desktop && viewUrl) url.searchParams.set("browserUrl", viewUrl);
  return url;
}

export function dataAppPromptTarget(url) {
  return url && new URL(url).protocol === "codex:" ? "_self" : "_blank";
}

export function currentDataAppReference(
  location = globalThis.window?.location,
  projectRoot = typeof __DATA_APP_PROJECT_ROOT__ === "string" ? __DATA_APP_PROJECT_ROOT__ : "",
) {
  if (!location?.href) return {};

  let source;
  try {
    source = new URL(location.href);
  } catch {
    return {};
  }
  source.username = "";
  source.password = "";
  source.search = ["http:", "https:"].includes(source.protocol)
    ? dashboardViewSearchParams(source).toString()
    : "";
  source.hash = "";
  // URL normalizes file://localhost to an empty authority. Any remaining
  // authority denotes a network path, not a local report working directory.
  if (source.protocol === "file:" && source.hostname) return {};
  if (isLocalDevelopmentHost(source.hostname)) {
    return (
      localPreviewReference(source) ??
      (projectRoot ? { root: projectRoot, htmlPath: `${projectRoot}/dist/index.html` } : {})
    );
  }
  if (["http:", "https:"].includes(source.protocol)) {
    source.pathname = canonicalDashboardPath(source.pathname);
  }

  if (source.protocol !== "file:") {
    const projectId = hostedSitesProjectId(source);
    return { sourceUrl: source.toString(), ...(projectId ? { projectId } : {}) };
  }

  // Encoded separators must not change the filesystem hierarchy on decoding.
  if (/%2f|%5c/iu.test(source.pathname)) return {};
  let htmlPath;
  try {
    htmlPath = decodeURIComponent(source.pathname);
  } catch {
    return {};
  }
  // File URLs retain a leading slash before a Windows drive, unlike local
  // filesystem paths passed to the native task's working-directory parameter.
  if (/^\/[A-Za-z]:\//u.test(htmlPath)) htmlPath = htmlPath.slice(1);
  if (!isSafeLocalDataAppPath(htmlPath)) return {};
  const directory = htmlPath.replace(/\/[^/]*$/u, "");
  const projectDirectory = directory.endsWith("/dist") ? directory.slice(0, -5) : directory;
  const root = /^[A-Za-z]:$/u.test(projectDirectory) ? `${projectDirectory}/` : projectDirectory || "/";
  return { htmlPath, root, sourceUrl: source.toString() };
}

// Compatibility exports for copied source consumers share the same policy.
export function chatGPTPromptUrl(
  prompt,
  location = globalThis.window?.location,
  userAgent = globalThis.navigator?.userAgent,
  destination,
) {
  return codexDataAppPromptUrl(prompt, undefined, location, userAgent, destination);
}

export const codexDataAppActionUrl = chatGPTPromptUrl;
export const codexDataAppNewTaskUrl = codexDataAppPromptUrl;
export const codexDataAppAskUrl = codexDataAppPromptUrl;
