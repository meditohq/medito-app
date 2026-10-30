import { useEffect, useRef } from "react";

import { registerDataAppContextTools } from "./data-app-context-tools.js";

export function useDataAppContextTools(context) {
  const contextRef = useRef(context);
  contextRef.current = context;
  useEffect(() => registerDataAppContextTools(
    globalThis.document?.modelContext ?? globalThis.navigator?.modelContext,
    () => contextRef.current,
  ), []);
}
