import React from "react";
import { createRoot } from "react-dom/client";

// Load starter CSS before App traverses authored component stylesheet imports.
import "./theme.css";
import "./styles.css";
import "./theme-picker.css";
import "./source-preview.css";
import "./content/dashboard/dashboard.css";
import "./content/report/report.css";
import "./print.css";
import "./theme-runtime.js";
import { App } from "./App.jsx";
import reviewedSnapshot from "./data.json";

const hosted = globalThis.location?.hostname.endsWith(".chatgpt.site") ?? false;

export function DataAppRuntime() {
  return <App hosted={hosted} />;
}

if (typeof document !== "undefined") {
  document.title = reviewedSnapshot.title || "Data app";
  const root = document.getElementById("root");
  if (root) {
    createRoot(root).render(
      <React.StrictMode>
        <DataAppRuntime />
      </React.StrictMode>,
    );
  }
}
