import { useEffect, useRef } from "react";

import { renderDataAppCardImage } from "./card-image.js";
import { createDataAppImageTools } from "./data-app-image-tools.js";

export function useDataAppImageTools(root, componentTargets, view) {
  const viewRef = useRef(view);
  viewRef.current = view;
  useEffect(() => {
    const context = document.modelContext ?? navigator.modelContext;
    if (typeof context?.registerTool !== "function") return;
    const controller = new AbortController();
    const { tools, dispose } = createDataAppImageTools({
      getViewState: () => viewRef.current,
      getTargets: () => [...(root.current?.querySelectorAll("[data-component-id]") ?? [])]
        .flatMap((element) => {
          const target = componentTargets.current.get(element.getAttribute("data-component-id"));
          return target ? [{ component: target.component, element }] : [];
        }),
      renderImage: renderDataAppCardImage,
    });
    // Read-only images are available wherever the reader can see the cards,
    // including local previews and hosted viewers. Query writes keep their gate.
    for (const tool of tools) {
      const report = (error) => {
        if (!controller.signal.aborted) console.error(`Unable to register Data app tool ${tool.name}.`, error);
      };
      try { Promise.resolve(context.registerTool(tool, { signal: controller.signal })).catch(report); }
      catch (error) { report(error); }
    }
    return () => {
      dispose();
      controller.abort();
      for (const tool of tools) context.unregisterTool?.(tool.name);
    };
  }, [root, componentTargets]);
}
