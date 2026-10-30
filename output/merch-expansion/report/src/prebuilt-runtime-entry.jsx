import React, * as ReactModule from "react";
import * as ReactJsxRuntime from "react/jsx-runtime";
import * as ReactJsxDevRuntime from "react/jsx-dev-runtime";
import * as ReactDOMModule from "react-dom";
import * as ReactDOMClientModule from "react-dom/client";
import * as RechartsModule from "recharts";
import ReactMarkdown, * as ReactMarkdownModule from "react-markdown";

import * as DataAppPublic from "./data-app-public.jsx";
import { DataAppRuntime } from "./DataAppRuntime.jsx";
import { setDataAppAppearance } from "./theme-runtime.js";

export * from "./data-app-public.jsx";
export { createStreamingJsonParser, parseJsonResponse } from "./streaming-json.js";

export const apiVersion = 1;

// Authored modules may be transformed from either ESM or CommonJS. Keep named
// exports and default-import interop together without manufacturing another copy
// of React, its hook dispatcher, or the protected Data app contexts.
function commonJsModule(namespace, defaultExport = namespace.default ?? namespace) {
  const exports = { ...namespace, default: defaultExport };
  Object.defineProperty(exports, "__esModule", { value: true });
  return Object.freeze(exports);
}

// React's production jsx-dev-runtime intentionally omits jsxDEV. Its production
// jsx function accepts the same first three arguments and ignores dev metadata.
const jsxDevRuntime = {
  ...ReactJsxDevRuntime,
  jsxDEV: ReactJsxDevRuntime.jsxDEV ?? ReactJsxRuntime.jsx,
};

export const publicApi = commonJsModule(DataAppPublic);

export const modules = Object.freeze({
  "@openai/data-app": publicApi,
  react: commonJsModule(ReactModule, React),
  "react/jsx-runtime": commonJsModule(ReactJsxRuntime),
  "react/jsx-dev-runtime": commonJsModule(jsxDevRuntime, jsxDevRuntime),
  "react-dom": commonJsModule(ReactDOMModule),
  "react-dom/client": commonJsModule(ReactDOMClientModule),
  recharts: commonJsModule(RechartsModule),
  "react-markdown": commonJsModule(ReactMarkdownModule, ReactMarkdown),
});

export const staticDemoVersion = 1;

export function mount({
  element = globalThis.document?.getElementById("root"),
  reviewedSnapshot,
  createContent,
  DashboardContent,
  ReportContent,
  staticDemo = false,
  hosted = globalThis.location?.hostname.endsWith(".chatgpt.site") ?? false,
} = {}) {
  if (!element) throw new Error("Data app mount target was not found.");
  const document = element.ownerDocument ?? globalThis.document;
  if (document) document.title = reviewedSnapshot?.title || "Data app";

  // The assembler supplies the authored theme and protected styles before mount.
  // Reapply the initial scheme in case this shared bundle was evaluated earlier.
  setDataAppAppearance(document?.documentElement?.dataset.appAppearance || "system");

  const root = ReactDOMClientModule.createRoot(element);
  root.render(
    <React.StrictMode>
      <DataAppRuntime
        reviewedSnapshot={reviewedSnapshot}
        createContent={createContent}
        DashboardContent={DashboardContent}
        ReportContent={ReportContent}
        hosted={hosted}
        staticDemo={staticDemo}
      />
    </React.StrictMode>,
  );
  return root;
}
