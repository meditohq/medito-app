import { createContext, useContext, useLayoutEffect } from "react";

export const DataAppContext = createContext(null);
export const DataAppBlockLayoutContext = createContext(null);

export function useDataAppShell() {
  const shell = useContext(DataAppContext);
  if (!shell) {
    throw new Error("Data app content must render inside the protected DataAppShell.");
  }
  return shell;
}

export function useOptionalDataAppShell() {
  return useContext(DataAppContext);
}

export function useDashboardTabs(definitions = []) {
  const { activeTabId, registerDashboardTabs } = useDataAppShell();
  const serializedDefinitions = JSON.stringify(definitions);

  useLayoutEffect(() => {
    registerDashboardTabs?.(JSON.parse(serializedDefinitions));
  }, [registerDashboardTabs, serializedDefinitions]);

  return { activeTabId };
}

export function useDataAppBlockLayouts() {
  const layouts = useContext(DataAppBlockLayoutContext);
  if (!layouts) throw new Error("Sortable blocks must render inside the protected DataAppShell.");
  return layouts;
}
