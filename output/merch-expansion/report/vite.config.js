import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

const localThreadId = [process.env.CODEX_SESSION_ID, process.env.CODEX_THREAD_ID].find((value) =>
  /^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/iu.test(value ?? ""),
);

const snapshotIntegrityPlugin = {
  name: "data-app-snapshot-integrity",
  async transformIndexHtml(_html, context) {
    const root = fileURLToPath(new URL(".", import.meta.url));
    let snapshotBytes = readFileSync(new URL("./src/data.json", import.meta.url));
    if (context?.filename && /^examples\/[\w-]+\/index\.html$/u.test(relative(root, context.filename).replaceAll("\\", "/"))) {
      const entry = join(dirname(context.filename), "data.js");
      if (!existsSync(entry)) throw new Error(`Gallery example needs an explicit snapshot entry: ${entry}`);
      const { snapshot } = context.server ? await context.server.ssrLoadModule(entry) : await import(pathToFileURL(entry).href);
      snapshotBytes = JSON.stringify(snapshot, null, 2) + "\n";
    }
    return [
      {
        tag: "meta",
        attrs: {
          name: "data-app-snapshot-sha256",
          content: createHash("sha256")
            .update(snapshotBytes)
            .digest("hex"),
        },
        injectTo: "head",
      },
      ...(context?.server && context.filename ? [{
        tag: "meta",
        attrs: { name: "data-app-local-reference", content: JSON.stringify({ root, htmlPath: context.filename }) },
        injectTo: "head",
      }] : []),
    ];
  },
};

export default defineConfig(({ command, isSsrBuild }) => ({
  // Gallery launchers and prepared apps consume the same authored reference modules.
  resolve: {
    alias: { "../../data-app-public.jsx": fileURLToPath(new URL("./src/data-app-public.jsx", import.meta.url)) },
    // Canonical examples live outside this package; use this app's installed UI runtime.
    dedupe: ["react", "react-dom", "recharts"],
  },
  plugins: isSsrBuild
    ? []
    : [
        viteSingleFile(),
        snapshotIntegrityPlugin,
        {
          name: "data-app-local-task",
          // Development gallery only. Prepared apps retain their own root entry.
          configureServer(server) {
            if (!existsSync(join(server.config.root, "examples/product-tracker/main.jsx"))) return;
            server.middlewares.use((request, response, next) => {
              if (request.method !== "GET" || request.url?.split("?")[0] !== "/") return next();
              response.writeHead(302, { Location: `/examples/product-tracker/${request.url.slice(1)}` });
              response.end();
            });
          },
          transformIndexHtml: () =>
            localThreadId
              ? [
                  {
                    tag: "meta",
                    attrs: {
                      name: "data-app-local-thread",
                      content: localThreadId,
                    },
                    injectTo: "head",
                  },
                ]
              : [],
        },
      ],
  server: {
    allowedHosts: ["terminal.local"],
    ...(process.env.CODEX_SANDBOX === "seatbelt" ? { watch: { useFsEvents: false, usePolling: true } } : {}),
  },
  define: {
    __DATA_APP_PROJECT_ROOT__: JSON.stringify(command === "serve" ? process.cwd() : ""),
  },
  build: isSsrBuild ? { rollupOptions: { output: { entryFileNames: "index.js" } } } : {},
}));
