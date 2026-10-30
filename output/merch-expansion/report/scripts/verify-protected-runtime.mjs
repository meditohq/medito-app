import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { digestProtectedFile } from "./protected-file-digest.mjs";

const authoredOnly = process.argv.includes("--authored-only");
const root = authoredOnly
  ? resolve(process.argv[process.argv.indexOf("--authored-only") + 1] ?? ".")
  : dirname(dirname(fileURLToPath(import.meta.url)));
const manifestPath = join(root, "protected-runtime.json");
const editablePaths = ["src/content/", "src/theme.css", "src/data.json"];
const protectedRootPaths = [
  "AGENTS.md",
  ".openai/hosting.json",
  "index.html",
  "package-lock.json",
  "package.json",
  "scripts/authorize-protected-change.mjs",
  "scripts/protected-file-digest.mjs",
  "scripts/verify-protected-runtime.mjs",
  "vite.config.js",
];

function listFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? listFiles(path) : [path];
  });
}

function portablePath(path) {
  return relative(root, path).split("\\").join("/");
}

function isEditablePath(path) {
  return editablePaths.some((approved) => (approved.endsWith("/") ? path.startsWith(approved) : path === approved));
}

function currentProtectedPaths() {
  const sourcePaths = listFiles(join(root, "src"))
    .map(portablePath)
    .filter((path) => !isEditablePath(path));
  const documentationPaths = listFiles(join(root, "docs/components")).map(portablePath);
  return [...protectedRootPaths, ...sourcePaths, ...documentationPaths].sort();
}

function digest(path) {
  return digestProtectedFile(path, readFileSync(join(root, path)));
}

const protectedChromeSelector =
  /(?:\.dashboard-topbar(?:-[\w-]+)?|\.topbar-[\w-]+|\.dashboard-refresh-[\w-]+|\.freshness(?:-[\w-]+)?|\.theme-drawer(?:-[\w-]+)?|\.source-sidebar(?:-[\w-]+)?|\.dashboard-publish(?:-[\w-]+)?|\.dashboard-overflow|\[data-data-app-chrome(?:[\]=]|\s))/iu;
const protectedAncestorSelector = /(?:\.dashboard-root\b|#root\b|(?:^|,)\s*header(?=$|[\s.#[:,>+~]))/iu;
const globalDocumentSelector = /(?:^|[\s,>+~])(html|body)(?=$|[\s.#[:,>+~])/iu;
const appSurfaceSelector = /^(?:\.page|\.report-page|main|\[data-data-app-content(?:=[^\]]+)?\])$/iu;
const sharedThemeToken =
  /^--(?:background|surface(?:-raised)?|muted|control(?:-hover|-radius)?|text|secondary|border(?:-strong)?|accent|positive|negative|chart-\d+|font-sans|card-radius)$/iu;

function authoredCssRules(css) {
  const cleaned = css.replace(/\/\*[\s\S]*?\*\//gu, "");
  return [...cleaned.matchAll(/(?:^|(?<=[{}]))\s*([^{}]+?)\s*\{([^{}]*)\}/gu)].map(([, selector, declarations]) => ({
    selector: selector.trim(),
    declarations,
  }));
}

function normalizeCssSelector(selector) {
  return selector
    .replace(/\\(?:\r\n|[\n\r\f])/gu, "")
    .replace(/\\([0-9a-f]{1,6})(?:\r\n|[ \t\r\n\f])?/giu, (_, value) => {
      const point = Number.parseInt(value, 16);
      return !point || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff)
        ? "\uFFFD"
        : String.fromCodePoint(point);
    })
    .replace(/\\([^0-9a-f\r\n\f])/giu, "$1");
}

function verifyAuthoredStyles(path) {
  const css = readFileSync(join(root, path), "utf8");
  const rules = authoredCssRules(css);
  const intent = [...css.matchAll(/--data-app-layout-intent\s*:\s*([\w-]+)/gu)].map(([, value]) => value).at(-1);
  if (intent && !["standard", "wide", "full-bleed", "user-requested", "authored-report"].includes(intent)) {
    throw new Error(`Authored stylesheet "${path}" uses an unrecognized layout intent: ${intent}.`);
  }
  for (const { selector, declarations } of rules) {
    const normalizedSelector = normalizeCssSelector(selector);
    if (normalizedSelector.startsWith("@")) continue;
    if (protectedChromeSelector.test(normalizedSelector) || protectedAncestorSelector.test(normalizedSelector)) {
      throw new Error(
        `Authored stylesheet "${path}" targets protected application chrome: ${selector}. Use approved theme tokens instead.`,
      );
    }
    if (
      globalDocumentSelector.test(normalizedSelector) ||
      normalizedSelector.split(",").some((part) => /^\s*\*(?=$|[\s.#[:,>+~])/u.test(part))
    ) {
      throw new Error(`Authored stylesheet "${path}" targets the global document: ${selector}.`);
    }
    if (
      path.startsWith("src/content/") &&
      normalizedSelector.split(",").some((part) => appSurfaceSelector.test(part.trim()))
    ) {
      const overlayProperties = [...declarations.matchAll(/(?:^|;)\s*([\w-]+)\s*:\s*([^;]+)/gu)]
        .filter(([, property, value]) => {
          const normalizedValue = value.trim().replace(/\s*!important$/iu, "");
          if (property === "position") return /^(?:absolute|fixed|sticky)$/iu.test(normalizedValue);
          if (property === "z-index") return normalizedValue !== "auto";
          if (property === "pointer-events") return normalizedValue !== "auto";
          return /^(?:inset(?:-[\w-]+)?|top|right|bottom|left|transform|translate)$/iu.test(property);
        })
        .map(([, property]) => property);
      if (overlayProperties.length) {
        throw new Error(
          `Authored app surface in "${path}" can cover or disable protected application chrome: ${overlayProperties.join(
            ", ",
          )}. Apply positioning and stacking only to scoped content inside the app surface.`,
        );
      }
      const tokens = [...declarations.matchAll(/(?:^|;)\s*([\w-]+)\s*:/gu)]
        .map(([, name]) => name)
        .filter((name) => sharedThemeToken.test(name));
      if (tokens.length) {
        throw new Error(
          `App-wide theme tokens in "${path}" must be defined on :root in src/theme.css so the page, chrome, controls, and authored content stay consistent: ${tokens.join(
            ", ",
          )}.`,
        );
      }
      const width = declarations.match(/(?:^|;)\s*max-width\s*:\s*([^;]+)/u)?.[1].trim();
      const customContentWidth = declarations.match(/(?:^|;)\s*--data-app-content-width\s*:\s*([^;]+)/u)?.[1].trim();
      const customGutter = declarations.match(/(?:^|;)\s*--data-app-layout-gutter\s*:\s*([^;]+)/u)?.[1].trim();
      const approvedFrame =
        width && /var\(--data-app-content-width\)/u.test(width) && /var\(--data-app-layout-gutter\)/u.test(width);
      const authoredReport = intent === "authored-report" && path.startsWith("src/content/report/")
        && normalizedSelector.split(",").every((part) => part.trim() === ".report-page");
      const customLayout = intent === "user-requested" || authoredReport;
      if (width && !approvedFrame && !(width === "none" && intent === "full-bleed") && !customLayout) {
        throw new Error(
          `Authored layout in "${path}" overrides the standard content frame. Use the approved width tokens, the full-bleed preset, or mark an explicitly user-requested custom width with --data-app-layout-intent: user-requested.`,
        );
      }
      if (
        customContentWidth &&
        !/^var\(--data-app-(?:dashboard-content|dashboard-wide-content|report-evidence)-width\)$/u.test(
          customContentWidth,
        ) &&
        !customLayout
      ) {
        throw new Error(
          `Authored layout in "${path}" uses an arbitrary content width. Use an approved preset or mark an explicitly user-requested width with --data-app-layout-intent: user-requested.`,
        );
      }
      if (
        customContentWidth?.includes("--data-app-dashboard-wide-content-width") &&
        !["wide", "full-bleed", "user-requested"].includes(intent) && !authoredReport
      ) {
        throw new Error(
          `Authored layout in "${path}" must explicitly mark the dashboard wide token with --data-app-layout-intent: wide.`,
        );
      }
      if (
        customGutter &&
        !/^var\(--data-app-(?:dashboard|report)(?:-mobile)?-gutter\)$/u.test(customGutter) &&
        !customLayout
      ) {
        throw new Error(
          `Authored layout in "${path}" uses a nonstandard gutter without an explicitly user-requested layout intent.`,
        );
      }
    }
    if (/^:root(?:\s*,\s*:root)*$/u.test(normalizedSelector)) {
      const properties = [...declarations.matchAll(/(?:^|;)\s*([\w-]+)\s*:/gu)].map(([, name]) => name);
      const disallowed = properties.filter((name) => !name.startsWith("--") && name !== "color-scheme");
      if (disallowed.length) {
        throw new Error(`Theme root in "${path}" may contain only approved styling tokens: ${disallowed.join(", ")}.`);
      }
    }
  }
}

function verifyAuthoredCode(path) {
  const source = readFileSync(join(root, path), "utf8");
  if (/<main(?:\s|>)/u.test(source)) {
    throw new Error(
      `Authored content "${path}" creates a nested main landmark. The protected shell owns the only application main; use an article, section, or div for authored content.`,
    );
  }
  if (
    /(?:\bfrom\s*|\bimport\s*(?:\(\s*)?|\brequire\s*\(\s*)["'`][^"'`]*(?:\/components\/|\/charting\/|DataAppShell|DataAppContext|data-app-actions)/u.test(
      source,
    )
  ) {
    throw new Error(`Authored content "${path}" must import protected behavior through data-app-public.jsx.`);
  }
  if (
    /document\s*\.\s*(?:body|documentElement)\s*\.\s*(?:remove|replaceChildren|replaceWith|innerHTML)/u.test(source) ||
    /document\s*\.\s*querySelector\s*\([^)]*(?:dashboard-topbar|data-data-app-chrome|theme-drawer|freshness)[^)]*\)\s*\??\.\s*(?:remove|replaceWith|setAttribute)/u.test(
      source,
    ) ||
    /createPortal\s*\([^)]*document\s*\.\s*body/u.test(source)
  ) {
    throw new Error(`Authored content "${path}" directly modifies or overlays protected application chrome.`);
  }
}

function verifyAuthoredBoundaries() {
  const contentRoot = join(root, "src/content");
  if (!existsSync(contentRoot)) throw new Error("The approved authored-content directory is missing: src/content/");
  for (const file of listFiles(contentRoot)) {
    const path = portablePath(file);
    if (/\.(?:css|scss)$/u.test(path)) verifyAuthoredStyles(path);
    if (/\.(?:jsx?|tsx?|mjs)$/u.test(path)) verifyAuthoredCode(path);
  }
  verifyAuthoredStyles("src/theme.css");
}

function updateManifest() {
  if (!process.argv.includes("--maintainer") || process.env.DATA_APP_MAINTAINER !== "1") {
    throw new Error(
      "Protected runtime updates are maintainer-only. Run DATA_APP_MAINTAINER=1 npm run integrity:update after reviewing infrastructure changes.",
    );
  }
  const files = Object.fromEntries(currentProtectedPaths().map((path) => [path, digest(path)]));
  writeFileSync(manifestPath, `${JSON.stringify({ version: 1, editablePaths, files }, null, 2)}\n`);
  console.log(`Updated protected Data app runtime manifest (${Object.keys(files).length} files).`);
}

function verifyManifest() {
  if (!existsSync(manifestPath)) {
    throw new Error("Missing protected Data app runtime manifest: protected-runtime.json");
  }
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  if (JSON.stringify(manifest.editablePaths) !== JSON.stringify(editablePaths)) {
    throw new Error("The approved model-authored file allowlist was modified.");
  }
  const expectedPaths = Object.keys(manifest.files).sort();
  for (const path of expectedPaths) {
    if (!existsSync(join(root, path))) {
      throw new Error(`Protected Data app runtime file is missing: ${path}`);
    }
    if (digest(path) !== manifest.files[path]) {
      throw new Error(
        `Protected Data app runtime file was modified: ${path}. Models may edit only ${editablePaths.join(", ")}.`,
      );
    }
  }
  const unexpected = currentProtectedPaths().filter((path) => !expectedPaths.includes(path));
  if (unexpected.length) {
    throw new Error(`Unapproved protected Data app runtime files were added: ${unexpected.join(", ")}`);
  }
  const packageMetadata = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
  if (
    packageMetadata.scripts?.prebuild !== "node scripts/verify-protected-runtime.mjs" ||
    !packageMetadata.scripts?.build?.startsWith("node scripts/verify-protected-runtime.mjs &&")
  ) {
    throw new Error("The Data app build must verify its protected runtime before invoking Vite.");
  }
  verifyAuthoredBoundaries();
  console.log(`Protected Data app runtime verified (${expectedPaths.length} files).`);
}

try {
  if (authoredOnly) {
    if (
      process.argv.length !== 4 ||
      process.argv[2] !== "--authored-only" ||
      !process.argv[3]?.trim() ||
      process.argv[3].startsWith("--")
    ) {
      throw new Error("Use --authored-only <project-directory> without update or authorization options.");
    }
    verifyAuthoredBoundaries();
    console.log("Data app authored content verified.");
  } else if (process.argv.includes("--update")) updateManifest();
  else verifyManifest();
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}
