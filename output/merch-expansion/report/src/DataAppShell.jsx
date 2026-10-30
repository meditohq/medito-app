import { dataAppBuildState, buildBlocksAction } from "./build-state.js";
import React, { forwardRef, useCallback, useEffect, useImperativeHandle, useMemo, useRef, useState } from "react";
import { flushSync } from "react-dom";

import { semanticColorResolver } from "./charting/chart-theme.js";
import { resolveChartSpec } from "./charting/chart-overrides.js";
import { copyChartImage } from "./chart-image.js";
import {
  canonicalDashboardPath,
  chartPermalink,
  componentPermalink,
  componentPermalinkId,
  componentPermalinkShortId,
  isComponentPermalinkTargetVisible,
  readComponentPermalink,
  validComponentId,
} from "./chart-permalink.js";
import { ChartEditor } from "./components/ChartEditor.jsx";
import { Dropdown } from "./components/Controls.jsx";
import { ChartExportDialog } from "./components/ChartExportDialog.jsx";
import { chartExportMetadata } from "./chart-export.js";
import { chartColorContext } from "./components/chart-color-utils.js";
import { DashboardAskProvider } from "./components/DashboardAsk.jsx";
import { DataAppHandoffDialog } from "./components/DataAppHandoffDialog.jsx";
import { DataAppThemeDrawer, DataAppTopbar } from "./components/DataAppChrome.jsx";
import { DataAppToast } from "./components/DataAppToast.jsx";
import { Icon } from "./components/Icon.jsx";
import { SourceSidebar } from "./components/SourceInspector.jsx";
import { Dialog, MenuItem, Tooltip, useInputModality } from "./components/ui.jsx";
import { dataAppActionHref, submitDataAppAction } from "./data-app-actions.js";
import { dataAppPromptLinkProps, openDataAppHandoff } from "./data-app-handoff.js";
import { DataAppBlockLayoutContext, DataAppContext } from "./DataAppContext.jsx";
import { canUseDashboardAsk } from "./dashboard-ask.js";
import { dashboardTabId, dashboardTabSnapshot, dashboardView, drillDashboardView } from "./dashboard-view-state.js";
import { dashboardUrlWithState, readDashboardUrlState, resolveDashboardUrlFilters } from "./dashboard-url-state.js";
import {
  normalizeAppearance,
  normalizePresentation,
  editHistoryValue,
  presentationBeforeEdits,
  readLocalPresentation,
  readViewerAppearance,
  writeViewerAppearance,
} from "./presentation-state.js";
import { codexDataAppPromptUrl, currentDataAppReference, currentDataAppViewUrl } from "./runtime-environment.js";
import { reviewedComponentClipboard } from "./source-provenance.js";
import { applyDataAppTheme, dataAppThemeTokens } from "./theme-presets.js";
import { setDataAppAppearance } from "./theme-runtime.js";
import { useDataApp } from "./use-data-app.js";
import { useDataAppImageTools } from "./use-data-app-image-tools.js";
import { useDataAppContextTools } from "./use-data-app-context-tools.js";
import { editableTextTarget, useInlineEditing } from "./use-inline-editing.js";
import { usePresentationHistory, usePresentationPersistence } from "./use-presentation.js";

const defaultDashboardTabs = [{ id: "dashboard", label: "Dashboard" }];

// Use the same capture capability as quick copy/download, including resolved chart types.
function chartExportAction(component, onSelect) {
  return <MenuItem icon="download" data-requires-chart-image onSelect={onSelect}>Export chart</MenuItem>;
}

function reconcileDashboardTabs(current, authored) {
  const remainingById = new Map(authored.map((tab) => [tab.id, tab]));
  const next = current.flatMap(({ id, label }) => {
    const definition = remainingById.get(id);
    if (!definition) return [];
    remainingById.delete(id);
    return [{ id: definition.id, label: definition.previousLabels?.includes(label) || defaultDashboardTabs.some(tab => tab.id === id && tab.label === label) ? definition.label : label }];
  });
  for (const tab of authored) {
    if (!remainingById.has(tab.id)) continue;
    next.push({ id: tab.id, label: tab.label });
    remainingById.delete(tab.id);
  }
  return next;
}

// Keep opening the editor independent of the dashboard render. Its real header
// mounts synchronously; only data resolution and the expensive body are deferred.
const ChartEditorHost = forwardRef(function ChartEditorHost(
  { reviewedRows, resolveColor, chartStates, canEdit, onClose, onSave },
  ref,
) {
  const [request, setRequest] = useState(null);
  useImperativeHandle(
    ref,
    () => ({
      open(next, immediate = true) {
        if (immediate) flushSync(() => setRequest(next));
        else setRequest(next);
      },
      close() {
        setRequest(null);
      },
      followPermalink(next, matches) {
        setRequest((current) =>
          current?.permalink && (!next?.detail || !matches(current.component.id, next.id)) ? null : current,
        );
      },
    }),
    [],
  );
  if (!request) return null;
  const { component } = request;
  return (
    <ChartEditorDialog
      key={component.id}
      component={component}
      getRows={() =>
        component.displayRows ??
        reviewedRows(component.queryId, [component.chart.x, component.chart.series].filter(Boolean))
      }
      resolveColor={resolveColor}
      visibleSeries={chartStates[component.id]?.visibleSeries}
      zoomRange={chartStates[component.id]?.zoomRange}
      canEdit={canEdit}
      onClose={() => onClose(request)}
      onSave={(spec) => onSave(spec, request)}
    />
  );
});

// Source data is resolved after the drawer has painted, without rerendering the dashboard.
const SourceSidebarHost = forwardRef(function SourceSidebarHost(
  { queries, reviewedRows, activeFilters, chartStates, snapshot },
  ref,
) {
  const [component, setComponent] = useState(null);
  useImperativeHandle(
    ref,
    () => ({
      open(next) {
        flushSync(() => setComponent(next));
      },
      close() {
        setComponent(null);
      },
      update(next) {
        setComponent((current) => current?.id === next.id ? next : current);
      },
    }),
    [],
  );
  const getSource = useCallback((queryId = component?.queryId) => {
    if (!component) return null;
    const selectedInlineFilters = Object.entries(chartStates[component.id]?.inlineFilters ?? {})
      .filter(
        ([field, value]) =>
          value !== "all" && reviewedRows(queryId, [field]).some((row) => row[field] === value),
      )
      .map(([field, value]) => ({
        field,
        value,
        label:
          field === "segment" ? "Product" : snapshot.filters?.find((filter) => filter.field === field)?.label ?? field,
      }));
    return {
      query: queries[queryId],
      rows:
        component.sourceRowsByQuery?.[queryId] ??
        (queryId === component.queryId ? component.sourceRows : undefined) ??
        reviewedRows(queryId, [component.chart?.x, component.chart?.series].filter(Boolean)),
      filters: [...activeFilters.filter((filter) => !Array.isArray(filter.queryIds) || filter.queryIds.includes(queryId)), ...(component.scopeFilters ?? []), ...selectedInlineFilters],
    };
  }, [component, queries, reviewedRows, activeFilters, chartStates, snapshot]);
  return (
    component && (
      <SourceSidebar
        key={component.id}
        component={component}
        queries={queries}
        getSource={getSource}
        onClose={() => setComponent(null)}
      />
    )
  );
});

function ChartEditorDialog({ component, ...props }) {
  const [colorContext] = useState(() => {
    const source = document.querySelector(`[data-component-id="${CSS.escape(component.id)}"]`);
    return chartColorContext(component.chart, source ? getComputedStyle(source) : null);
  });
  return <ChartEditor DialogComponent={Dialog} SelectComponent={Dropdown} TooltipComponent={Tooltip}
    component={component} style={colorContext} {...props} />;
}

export function DataAppShell({
  snapshot,
  hosted,
  canEdit: ownerCanEdit = true,
  persistLocally = true,
  onSnapshotChange,
  initialPresentation = {},
  initialRevision = 0,
  queryDataStore,
  children,
}) {
  const build = dataAppBuildState(snapshot);
  const canEdit = ownerCanEdit && !build.active;
  const reportSurface = snapshot.surface === "report";
  useInputModality();
  const surfaceNoun = reportSurface ? "report" : "dashboard";
  const [savedPresentation] = useState(() => {
    const personal = persistLocally ? readLocalPresentation(snapshot) : {};
    const normalized = normalizePresentation(
      hosted
        ? {
            ...initialPresentation,
            ...(personal.filters ? { filters: personal.filters } : {}),
            ...(personal.assumptions ? { assumptions: personal.assumptions } : {}),
            ...(personal.tabViews ? { tabViews: personal.tabViews } : {}),
          }
        : personal,
    );
    if (reportSurface) {
      delete normalized.tabs;
      delete normalized.refreshSchedule;
    }
    return normalized;
  });
  const [initialDashboardHref] = useState(() => globalThis.location?.href);
  const [initialUrlState] = useState(() =>
    readDashboardUrlState(snapshot, savedPresentation.tabs ?? defaultDashboardTabs),
  );
  const sourceSidebarRef = useRef(null);
  const chartEditorRef = useRef(null);
  const [mode, setMode] = useState("view");
  const [chartExport, setChartExport] = useState(null);
  const [editSession, setEditSession] = useState(null);
  const editSessionRef = useRef(editSession);
  editSessionRef.current = editSession;
  const [chartOverrides, setChartOverrides] = useState(savedPresentation.chartOverrides ?? {});
  const [blockLayouts, setBlockLayouts] = useState(savedPresentation.blockLayouts ?? {});
  const [hidden, setHidden] = useState(() => new Set(savedPresentation.hiddenBlocks ?? []));
  const [actionStatus, setActionStatus] = useState("");
  const [viewerTheme, setViewerTheme] = useState(null);
  const [activeTheme, setActiveTheme] = useState(savedPresentation.theme ?? "original");
  const [appearance, setAppearance] = useState(normalizeAppearance(savedPresentation.appearance));
  const [viewerAppearance, setViewerAppearance] = useState(() => persistLocally ? readViewerAppearance(snapshot) : "");
  const [chartStates, setChartStates] = useState(initialUrlState.charts);
  const [sectionViews, setSectionViews] = useState(initialUrlState.sections);
  const setSectionView = useCallback((id, values) => {
    setSectionViews(current => ({ ...current, [id]: values }));
  }, []);
  const [themesOpen, setThemesOpen] = useState(false);
  const [originalThemeTokens] = useState(() => {
    if (typeof document === "undefined" || typeof getComputedStyle !== "function") {
      return dataAppThemeTokens.map(() => "");
    }
    const computed = getComputedStyle(document.documentElement);
    return dataAppThemeTokens.map((token) => computed.getPropertyValue(`--${token}`).trim());
  });
  const [appTitle, setAppTitle] = useState(savedPresentation.title ?? snapshot.title);
  const [verification, setVerification] = useState(savedPresentation.verification);
  const [pendingVerification, setPendingVerification] = useState(null);
  const [narrativeEdits, setNarrativeEdits] = useState(savedPresentation.textEdits ?? {});
  const [componentTitles, setComponentTitles] = useState(savedPresentation.componentTitles ?? {});
  const [tabs, setTabs] = useState(savedPresentation.tabs ?? defaultDashboardTabs);
  const [activeTabId, setActiveTabId] = useState(
    () => initialUrlState.tab ?? (savedPresentation.tabs ?? defaultDashboardTabs)[0].id,
  );
  const [tabDefinitions, setTabDefinitions] = useState([]);
  const tabDefinitionsRef = useRef(tabDefinitions);
  tabDefinitionsRef.current = tabDefinitions;
  const scopedTabs = tabDefinitions.some(tab => Array.isArray(tab.filterIds));
  const scopedSnapshot = useMemo(() => dashboardTabSnapshot(snapshot, tabDefinitions, activeTabId),
    [snapshot, tabDefinitions, activeTabId]);
  const [tabViews, setTabViews] = useState(
    initialUrlState.complete ? initialUrlState.tabViews : savedPresentation.tabViews ?? {},
  );
  const tabViewsRef = useRef(tabViews);
  tabViewsRef.current = tabViews;
  const [viewFocus, setViewFocus] = useState(initialUrlState.focus);
  const [drillReturn, setDrillReturn] = useState(null);
  const viewRef = useRef({});
  const { queries, filters, setFilter, replaceFilters, reviewedRows, reviewedPeriodRows, reviewedAggregatePeriodRows, activeFilters } = useDataApp(snapshot, {
    queryDataStore,
    filterDefinitions: scopedSnapshot.filters,
    visibleFilterIds: snapshot.report?.visibleFilterIds ?? snapshot.visibleReportFilters,
    hosted,
    canEdit,
    onSnapshotChange,
    initialFilters: resolveDashboardUrlFilters(snapshot, savedPresentation.filters, initialUrlState),
    authoritativeInitialFilters: initialUrlState.filters,
  });
  viewRef.current = { tabId: activeTabId, filters, focus: viewFocus, returnTo: drillReturn };
  const activeTabRef = useRef(activeTabId);
  const tabsRef = useRef(tabs);
  const filtersRef = useRef(filters);
  activeTabRef.current = activeTabId;
  tabsRef.current = tabs;
  filtersRef.current = filters;
  const [tabRegistrationReady, setTabRegistrationReady] = useState(false);
  const dashboardBusyRef = useRef(false);
  const [dashboardBusy, updateDashboardBusy] = useState(false);
  const queriesBusy = queryDataStore?.pending(Object.keys(queries)) ?? false;
  const setDashboardBusy = useCallback(value => {
    dashboardBusyRef.current = Boolean(value);
    updateDashboardBusy(Boolean(value));
  }, []);
  const initialAuthoredTabsRegistered = useRef(false);
  const registerDashboardTabs = useCallback(
    (definitions) => {
      if (reportSurface || !Array.isArray(definitions)) return;
      const uniqueIds = new Set();
      const normalized = definitions.slice(0, 20).flatMap((entry) => {
        const id = typeof entry?.id === "string" ? entry.id.trim() : "";
        const label = typeof entry?.label === "string" ? entry.label.trim() : "";
        if (!id || id.length > 80 || !/^[a-zA-Z0-9_-]+$/u.test(id) || !label || label.length > 100 || uniqueIds.has(id))
          return [];
        uniqueIds.add(id);
        return [{ id, label, ...(Array.isArray(entry.previousLabels) ? { previousLabels: entry.previousLabels } : {}) }];
      });
      const authored = normalized.length ? normalized : defaultDashboardTabs;
      const bindings = authored.map(tab => ({ ...definitions.find(entry => entry.id === tab.id), ...tab }));
      tabDefinitionsRef.current = bindings;
      setTabDefinitions(current => JSON.stringify(current) === JSON.stringify(bindings) ? current : bindings);
      if (!normalized.length) {
        uniqueIds.clear();
        uniqueIds.add("dashboard");
      }
      const nextTabs = reconcileDashboardTabs(tabsRef.current, authored);
      if (!initialAuthoredTabsRegistered.current) {
        initialAuthoredTabsRegistered.current = true;
        const requested = initialDashboardHref ? new URL(initialDashboardHref).searchParams.get("tab") : null;
        const tabId = dashboardTabId(bindings, requested ?? activeTabRef.current);
        const scoped = dashboardTabSnapshot(snapshot, bindings, tabId);
        const state = readDashboardUrlState(scoped, authored, initialDashboardHref);
        const historyView = globalThis.history?.state?.dataAppView;
        const restored = historyView && historyView.artifactId === snapshot.id && historyView.tabId === tabId ? historyView : null;
        const saved = state.complete ? state.tabViews[tabId] ?? {}
          : restored ?? savedPresentation.tabViews?.[tabId] ?? { filters: savedPresentation.filters };
        const view = dashboardView(snapshot, bindings, tabId, saved, state);
        setActiveTabId(tabId);
        replaceFilters(view.filters);
        setViewFocus(view.focus);
        setDrillReturn(restored?.returnTo ?? null);
      } else if (!uniqueIds.has(activeTabRef.current)) {
        setActiveTabId(nextTabs[0].id);
      }
      setTabs((current) => {
        const next = reconcileDashboardTabs(current, authored);
        return next.length === current.length &&
          next.every((tab, index) => tab.id === current[index].id && tab.label === current[index].label)
          ? current
          : next;
      });
      setTabRegistrationReady(true);
    },
    [initialDashboardHref, replaceFilters, reportSurface, savedPresentation, snapshot],
  );
  const queryLoadingViewInitialized = useRef(false);
  useEffect(() => {
    if (reportSurface || initialAuthoredTabsRegistered.current) {
      setTabRegistrationReady(true);
      return;
    }
    if (queryDataStore && queryLoadingViewInitialized.current) return;
    const state = readDashboardUrlState(snapshot, defaultDashboardTabs, initialDashboardHref);
    setTabs(defaultDashboardTabs);
    setActiveTabId(state.tab ?? "dashboard");
    replaceFilters(resolveDashboardUrlFilters(snapshot, savedPresentation.filters, state));
    setTabRegistrationReady(true);
    queryLoadingViewInitialized.current = true;
  }, [initialDashboardHref, replaceFilters, reportSurface, savedPresentation, snapshot, queryDataStore]);
  const [linkedComponent, setLinkedComponent] = useState(() =>
    hosted ? readComponentPermalink(globalThis.location) : null,
  );
  const componentTargets = useRef(new Map());
  const handledComponentPermalink = useRef(null);
  const unavailableComponentPermalink = useRef(null);
  const componentTabProbe = useRef(null);
  const componentHighlight = useRef(null);
  const registerComponent = useCallback((component, element) => {
    if (element) {
      componentTargets.current.set(component.id, { component, element });
      sourceSidebarRef.current?.update(component);
    }
    else componentTargets.current.delete(component.id);
  }, []);
  const componentMatchesPermalink = useCallback(
    (authoredId, permalinkId) =>
      authoredId === permalinkId ||
      (validComponentId(authoredId) &&
        (componentPermalinkId(globalThis.location, authoredId) === permalinkId ||
          componentPermalinkShortId(globalThis.location, authoredId) === permalinkId)),
    [],
  );
  const clearComponentHighlight = useCallback(() => {
    if (!componentHighlight.current) return;
    clearTimeout(componentHighlight.current.timeout);
    componentHighlight.current.element.removeAttribute("data-permalink-target");
    componentHighlight.current = null;
  }, []);
  const followComponentPermalink = useCallback(() => {
    const nextComponent = readComponentPermalink(window.location);
    clearComponentHighlight();
    handledComponentPermalink.current = null;
    unavailableComponentPermalink.current = null;
    componentTabProbe.current = null;
    chartEditorRef.current?.followPermalink(nextComponent, componentMatchesPermalink);
    setLinkedComponent(nextComponent);
  }, [clearComponentHighlight, componentMatchesPermalink]);
  const [assumptions, setAssumptions] = useState(() => initialUrlState.complete
    ? { activationLift: 0, retentionLift: 0, ...initialUrlState.assumptions }
    : savedPresentation.assumptions ?? { activationLift: 0, retentionLift: 0 });
  // Personal view choices travel with the link, never the shared presentation.
  const currentView = {
    tab: activeTabId, filters, assumptions, sections: sectionViews, charts: chartStates,
    focus: viewFocus,
    tabViews: scopedTabs ? { ...tabViews, [activeTabId]: { filters, focus: viewFocus } } : {},
  };
  const currentViewRef = useRef(currentView);
  currentViewRef.current = currentView;
  const editingRoot = useInlineEditing(
    canEdit && mode === "edit" && !editSession?.saving,
    (id, value) => setNarrativeEdits((current) => ({ ...current, [id]: value })),
    narrativeEdits,
  );
  useDataAppImageTools(editingRoot, componentTargets, {
    surface: snapshot.surface, tabId: reportSurface ? null : activeTabId, filters,
  });
  const presentation = {
    theme: activeTheme,
    appearance,
    title: appTitle,
    hiddenBlocks: [...hidden],
    componentTitles,
    textEdits: narrativeEdits,
    chartOverrides,
    ...(verification ? { verification } : {}),
    ...(Object.keys(blockLayouts).length ? { blockLayouts } : {}),
    ...(savedPresentation.description !== undefined ? { description: savedPresentation.description } : {}),
    ...(!reportSurface
      ? {
          tabs,
          ...(savedPresentation.refreshSchedule ? { refreshSchedule: savedPresentation.refreshSchedule } : {}),
        }
      : {}),
    ...(!hosted ? { filters, assumptions } : {}),
  };
  const contextViewUrl = linkedViewUrl();
  const contextReference = currentDataAppReference();
  useDataAppContextTools({
    snapshot: { ...snapshot, queries },
    queryDataStore,
    presentation: { ...presentation, filters, assumptions, filterDefinitions: scopedSnapshot.filters ?? [] },
    view: currentView,
    dataAppReference: contextReference.sourceUrl && contextViewUrl
      ? { ...contextReference, sourceUrl: contextViewUrl } : contextReference,
    viewUrl: contextViewUrl,
    canEdit,
    getText: (id) => {
      const matches = [...(editingRoot.current?.querySelectorAll("[data-editable-id], [data-component-id]") ?? [])]
        .filter(element => (element.getAttribute("data-editable-id") === id || element.getAttribute("data-component-id") === id)
          && isComponentPermalinkTargetVisible(element));
      if (matches.length > 1) throw new Error("The text ID is ambiguous in this view.");
      return matches[0]?.innerText ?? null;
    },
  });
  const acknowledgePresentation = useCallback((authoritative, action) => {
    const nextVerification = authoritative.verification;
    setVerification((current) =>
      JSON.stringify(current) === JSON.stringify(nextVerification) ? current : nextVerification,
    );
    if (action) setPendingVerification((current) => (current === action ? null : current));
    if (editSessionRef.current?.saving) {
      setEditSession(null);
      setMode("view");
    }
  }, []);
  function restorePresentation(value) {
    setActiveTheme(value.theme ?? "original");
    setAppearance(normalizeAppearance(value.appearance));
    setAppTitle(value.title ?? snapshot.title);
    setHidden(new Set(value.hiddenBlocks ?? []));
    setComponentTitles(value.componentTitles ?? {});
    setNarrativeEdits(value.textEdits ?? {});
    setChartOverrides(value.chartOverrides ?? {});
    setBlockLayouts(value.blockLayouts ?? {});
    setTabs(value.tabs ?? defaultDashboardTabs);
  }
  const editHistory = usePresentationHistory(presentation, canEdit && mode === "edit", restorePresentation);
  const handlePresentationError = useCallback((message) => {
    setActionStatus(message);
    setEditSession((current) => current ? { ...current, saving: false } : current);
  }, []);
  const saveStatus = usePresentationPersistence({
    snapshot,
    hosted,
    canEdit,
    persistLocally,
    presentation: editSession && !editSession.saving
      ? presentationBeforeEdits(presentation, editSession.baseline) : presentation,
    personalPresentation: { ...(hosted ? { filters, assumptions } : {}), ...(scopedTabs ? { tabViews } : {}) },
    initialPresentation: savedPresentation,
    initialRevision,
    verificationAction: editSession?.saving ? pendingVerification : null,
    onAcknowledged: acknowledgePresentation,
    onError: handlePresentationError,
  });
  function beginEditing() {
    if (!canEdit || editSession || saveStatus === "saving") return;
    setEditSession({ baseline: JSON.parse(editHistoryValue(presentation)), saving: false });
    setMode("edit");
  }
  function cancelEditing() {
    if (!editSession || editSession.saving) return;
    restorePresentation(editSession.baseline);
    setPendingVerification(null);
    setEditSession(null);
    setMode("view");
  }
  function saveEditing() {
    if (!canEdit || !editSession || editSession.saving) return;
    // Text editors commit on blur. Flush that event before taking the value
    // used by persistence, including keyboard activation of the Save control.
    flushSync(() => document.activeElement?.blur?.());
    setEditSession((current) => current ? { ...current, saving: true } : current);
  }
  const editingChanged = editSession && (pendingVerification !== null
    || editHistoryValue(presentation) !== JSON.stringify(editSession.baseline));
  useEffect(() => {
    if (editSession?.saving && !editingChanged) {
      setEditSession(null);
      setMode("view");
    }
  }, [editSession?.saving, editingChanged]);
  useEffect(() => {
    if (!editingChanged) return undefined;
    const warn = (event) => { event.preventDefault(); event.returnValue = ""; };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [editingChanged]);
  const colorMetadata = snapshot._dataAppQueryLoading?.colors;
  // Hydration does not change the complete reviewed palette. Owner edits clear
  // this metadata and resume allocation from the current complete queries.
  const colorQueries = colorMetadata ? undefined : snapshot.queries;
  const resolveColor = useMemo(() => semanticColorResolver(colorQueries, colorMetadata),
    [colorQueries, colorMetadata]);
  const displayedTheme = viewerTheme ?? activeTheme;
  const previousTheme = useRef(displayedTheme);

  useEffect(() => {
    if (displayedTheme !== "original" || previousTheme.current !== displayedTheme) applyDataAppTheme(displayedTheme);
    previousTheme.current = displayedTheme;
  }, [displayedTheme]);

  useEffect(() => {
    setDataAppAppearance(viewerAppearance || appearance);
  }, [viewerAppearance, appearance, activeTheme]);

  useEffect(() => {
    if (!tabs.some(({ id }) => id === activeTabId)) setActiveTabId(tabs[0].id);
  }, [activeTabId, tabs]);

  useEffect(() => {
    if (!tabRegistrationReady || typeof window === "undefined") return;
    try {
      const next = dashboardUrlWithState(window.location, scopedSnapshot, reportSurface ? [] : tabs, currentViewRef.current);
      if (next && next.href !== window.location.href) {
        window.history.replaceState(window.history.state, "", next);
      }
    } catch {
      setActionStatus("This view has too many selections to fit in a shareable link. Reduce the selections before sharing.");
    }
  }, [activeTabId, filters, assumptions, sectionViews, chartStates, viewFocus, tabViews,
    reportSurface, scopedSnapshot, tabs, tabRegistrationReady]);

  useEffect(() => {
    if (!scopedTabs || !tabRegistrationReady) return;
    const view = { filters, focus: viewFocus };
    if (!drillReturn) setTabViews(current => JSON.stringify(current[activeTabId]) === JSON.stringify(view)
      ? current : { ...current, [activeTabId]: view });
    if (typeof window !== "undefined") window.history.replaceState({ ...window.history.state,
      dataAppView: { artifactId: snapshot.id, ...viewRef.current } }, "");
  }, [activeTabId, filters, viewFocus, drillReturn, scopedTabs, tabRegistrationReady, snapshot.id]);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    function restoreDashboardUrlState(event) {
      const definitions = tabDefinitionsRef.current;
      const requested = new URL(window.location.href).searchParams.get("tab");
      const tabId = dashboardTabId(definitions.length ? definitions : tabs, requested);
      const scoped = dashboardTabSnapshot(snapshot, definitions, tabId);
      const state = readDashboardUrlState(scoped, tabs, window.location);
      const stored = event.state?.dataAppView;
      const view = stored && stored.artifactId === snapshot.id && stored.tabId === tabId ? stored : null;
      const next = dashboardView(snapshot, definitions, tabId,
        state.complete ? state.tabViews[tabId] ?? {}
          : view ?? tabViewsRef.current[tabId] ?? { filters: filtersRef.current }, state);
      if (state.complete) {
        setAssumptions({ activationLift: 0, retentionLift: 0, ...state.assumptions });
        setSectionViews(state.sections);
        setChartStates(state.charts);
        setTabViews(state.tabViews);
      }
      setActiveTabId(tabId);
      replaceFilters(next.filters);
      setViewFocus(next.focus);
      setDrillReturn(view?.returnTo ?? null);
      if (view?.scrollY != null) requestAnimationFrame(() => window.scrollTo(0, view.scrollY));
    }
    window.addEventListener("popstate", restoreDashboardUrlState);
    return () => window.removeEventListener("popstate", restoreDashboardUrlState);
  }, [replaceFilters, reportSurface, snapshot, tabs]);

  const navigateDashboardTab = useCallback((tabId, nextTabs = tabs, payload = null) => {
    if (!nextTabs.some(tab => tab.id === tabId) || (tabId === activeTabRef.current && !payload)) return;
    const definitions = tabDefinitionsRef.current;
    const scoped = definitions.some(tab => Array.isArray(tab.filterIds));
    const saved = tabViewsRef.current[tabId] ?? {};
    const target = payload ? drillDashboardView(snapshot, definitions, tabId, saved, payload)
      : scoped ? dashboardView(snapshot, definitions, tabId, saved) : { filters: filtersRef.current, focus: {} };
    const origin = { ...viewRef.current, scrollY: globalThis.scrollY ?? 0 };
    const returnTo = payload ? origin : null;
    if (!reportSurface && typeof window !== "undefined") {
      let next;
      try {
        next = dashboardUrlWithState(window.location, dashboardTabSnapshot(snapshot, definitions, tabId), nextTabs,
          { ...currentViewRef.current, tab: tabId, filters: target.filters, focus: target.focus,
            tabViews: scoped ? { ...tabViewsRef.current, [activeTabRef.current]: { filters: origin.filters, focus: origin.focus }, [tabId]: target } : {} });
      } catch (error) {
        setActionStatus(error.message);
        return;
      }
      window.history.replaceState({ ...window.history.state,
        dataAppView: { artifactId: snapshot.id, ...origin } }, "");
      if (next) {
        next.pathname = canonicalDashboardPath(next.pathname);
        window.history.pushState({ ...window.history.state,
          dataAppView: { artifactId: snapshot.id, tabId, ...target, returnTo } }, "", next);
        if (hosted) followComponentPermalink();
      }
      requestAnimationFrame(() => window.scrollTo(0, 0));
    }
    replaceFilters(target.filters);
    setViewFocus(target.focus);
    setDrillReturn(returnTo);
    setActiveTabId(tabId);
  }, [followComponentPermalink, hosted, replaceFilters, reportSurface, snapshot, tabs]);
  const exploreDashboard = useCallback((tabId, payload) => navigateDashboardTab(tabId, tabs, payload), [navigateDashboardTab, tabs]);
  const returnFromExploration = useCallback(() => {
    if (drillReturn && typeof window !== "undefined") window.history.back();
  }, [drillReturn]);
  const setDashboardFocus = useCallback((focus) => {
    setViewFocus(dashboardView(snapshot, tabDefinitionsRef.current, activeTabRef.current, { focus }).focus);
  }, [snapshot]);

  useEffect(() => {
    if (!hosted || typeof window === "undefined") return undefined;

    window.addEventListener("popstate", followComponentPermalink);
    return () => {
      window.removeEventListener("popstate", followComponentPermalink);
      clearComponentHighlight();
      handledComponentPermalink.current = null;
      unavailableComponentPermalink.current = null;
      componentTabProbe.current = null;
    };
  }, [clearComponentHighlight, followComponentPermalink, hosted]);

  useEffect(() => {
    if (!tabRegistrationReady || !hosted || !linkedComponent || dashboardBusyRef.current
      || queryDataStore?.pending(Object.keys(queries))) return;

    const routeKey = `${linkedComponent.kind}\u0000${linkedComponent.id}\u0000${linkedComponent.detail}`;
    if (handledComponentPermalink.current === routeKey) return;
    const unavailableMessage =
      linkedComponent.kind === "chart" ? "The linked chart is unavailable." : "The linked component is unavailable.";

    function showUnavailable() {
      if (unavailableComponentPermalink.current !== routeKey) {
        unavailableComponentPermalink.current = routeKey;
        setActionStatus(unavailableMessage);
      }
    }

    const hiddenTarget =
      hidden.has(linkedComponent.id) ||
      [...hidden].slice(0, 500).some((id) => componentMatchesPermalink(id, linkedComponent.id));
    if (hiddenTarget) {
      componentTabProbe.current = null;
      showUnavailable();
      return;
    }

    const existingTabIds = new Set(tabs.slice(0, 50).map(({ id }) => id));
    let probe = componentTabProbe.current;
    if (!probe || probe.routeKey !== routeKey) {
      probe = {
        routeKey,
        attemptedTabIds: new Set(),
        originalTabId: activeTabId,
        pendingTabId: null,
      };
      componentTabProbe.current = probe;
    }
    if (probe.pendingTabId && probe.pendingTabId !== activeTabId && existingTabIds.has(probe.pendingTabId)) {
      return;
    }
    probe.pendingTabId = null;

    const candidate =
      componentTargets.current.get(linkedComponent.id) ??
      [...componentTargets.current.values()]
        .slice(0, 500)
        .find(({ component }) => componentMatchesPermalink(component.id, linkedComponent.id));
    // Authored tabs may retain their DOM while hiding inactive panels. A
    // registered but invisible component still needs its owning tab selected.
    const target = isComponentPermalinkTargetVisible(candidate?.element) ? candidate : null;
    if (!target) {
      probe.attemptedTabIds.add(activeTabId);
      const dashboardTab = tabs.find(({ id }) => id === "dashboard" && !probe.attemptedTabIds.has(id));
      const nextTab = dashboardTab ?? tabs.slice(0, 50).find(({ id }) => !probe.attemptedTabIds.has(id));
      if (nextTab) {
        probe.pendingTabId = nextTab.id;
        setActiveTabId(nextTab.id);
        return;
      }
    }

    if (!target || (linkedComponent.kind === "chart" && !target.component.chart)) {
      handledComponentPermalink.current = routeKey;
      componentTabProbe.current = null;
      showUnavailable();
      if (probe.originalTabId !== activeTabId && existingTabIds.has(probe.originalTabId)) {
        setActiveTabId(probe.originalTabId);
      }
      return;
    }

    handledComponentPermalink.current = routeKey;
    componentTabProbe.current = null;
    if (unavailableComponentPermalink.current === routeKey) {
      unavailableComponentPermalink.current = null;
      setActionStatus((current) => (current === unavailableMessage ? "" : current));
    }
    const { component, element } = target;
    element.setAttribute("data-permalink-target", "true");
    element.scrollIntoView({
      block: "center",
      behavior: window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ? "auto" : "smooth",
    });
    element.focus({ preventScroll: true });
    if (linkedComponent.kind === "chart" && linkedComponent.detail && component.chart) {
      chartEditorRef.current?.open(
        {
          type: "explore",
          component,
          permalink: true,
          originalOverride: chartOverrides[component.id],
          dirty: false,
          resetVersion: 0,
          draft: component.chart,
          history: [component.chart],
          historyIndex: 0,
        },
        false,
      );
    }

    const timeout = setTimeout(() => {
      element.removeAttribute("data-permalink-target");
      if (componentHighlight.current?.element === element) componentHighlight.current = null;
    }, 2400);
    componentHighlight.current = { element, timeout };
  }, [
    activeTabId,
    chartOverrides,
    componentMatchesPermalink,
    hidden,
    hosted,
    linkedComponent,
    tabs,
    tabRegistrationReady,
    dashboardBusy,
    queriesBusy,
  ]);

  const visible = (id) => !hidden.has(id);
  function updateChartState(id, changes) {
    setChartStates((current) => ({
      ...current,
      [id]: { ...(current[id] ?? {}), ...changes },
    }));
  }
  function chartProps(id) {
    return {
      chartId: id,
      resolveColor,
      visibleSeries: chartStates[id]?.visibleSeries,
      onVisibleSeriesChange: (visibleSeries) => updateChartState(id, { visibleSeries }),
      zoomRange: chartStates[id]?.zoomRange,
      onZoomChange: (zoomRange) => updateChartState(id, { zoomRange }),
    };
  }
  function requestTextEdit(target) {
    if (!canEdit || !target) return;
    if (mode !== "edit") beginEditing();
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        if (!target.isConnected) return;
        const editable = target.isContentEditable ? target : target.querySelector('[contenteditable="true"]');
        editable?.focus();
      }),
    );
  }
  async function copyComponent(format, component) {
    if (format === "link" || format === "detail-link" || format === "component-link") {
      try {
        const chartLink = format !== "component-link";
        if (!hosted || (chartLink && !component.chart)) {
          throw new Error("Only published components have shareable links.");
        }
        if (!navigator.clipboard?.writeText) throw new Error("Clipboard is unavailable in this browser.");
        const componentId = componentPermalinkShortId(globalThis.location, component.id);
        const permalink = chartLink
          ? chartPermalink(globalThis.location, componentId, {
              detail: format === "detail-link",
            })
          : componentPermalink(globalThis.location, componentId);
        const url = dashboardUrlWithState(permalink, scopedSnapshot, reportSurface ? [] : tabs,
          currentViewRef.current, { preserveExisting: false }).toString();
        await navigator.clipboard.writeText(url);
        setActionStatus(`${component.title} link copied.`);
      } catch (error) {
        setActionStatus(error instanceof Error ? error.message : "Unable to copy the component link.");
      }
      return;
    }
    if (format === "image") {
      try {
        await copyChartImage(component.id, { description: component.description });
        setActionStatus(`Chart image for “${component.title}” copied.`);
      } catch (error) {
        setActionStatus(error instanceof Error ? error.message : "Unable to copy the chart image.");
      }
      return;
    }
    const text = reviewedComponentClipboard(component, queries, (queryId) =>
      component.sourceRowsByQuery?.[queryId]
        ?? (queryId === component.queryId ? component.sourceRows ?? component.displayRows : undefined)
        ?? reviewedRows(queryId));
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard is unavailable in this browser.");
      await navigator.clipboard.writeText(text);
      setActionStatus(`${format} for “${component.title}” copied.`);
    } catch (error) {
      setActionStatus(error instanceof Error ? error.message : "Unable to copy reviewed data.");
    }
  }
  function viewDataAppReference(viewUrl) {
    const reference = currentDataAppReference();
    if (!reference.sourceUrl) return reference;
    const url = viewUrl ?? dashboardUrlWithState(reference.sourceUrl, scopedSnapshot, reportSurface ? [] : tabs,
      currentViewRef.current, { preserveExisting: false });
    return { ...reference, sourceUrl: url?.toString() ?? reference.sourceUrl };
  }
  function linkedViewUrl(strict = false) {
    const source = currentDataAppViewUrl();
    if (!source) return null;
    try {
      return dashboardUrlWithState(source, scopedSnapshot, reportSurface ? [] : tabs,
        currentViewRef.current, { preserveExisting: false })?.toString() ?? null;
    } catch (error) {
      if (strict) throw error;
      return null; // An oversized view cannot be represented by a partial link.
    }
  }
  function actionContext(options = {}) {
    const viewUrl = linkedViewUrl(true);
    return {
      ...options,
      surface: snapshot.surface,
      canEdit,
      snapshot,
      title: appTitle,
      dataAppReference: viewDataAppReference(viewUrl),
      viewUrl,
      presentation: {
        ...presentation,
        filters,
        assumptions,
        filterDefinitions: scopedSnapshot.filters ?? [],
      },
    };
  }
  function actionHref(action, options, destination) {
    if (buildBlocksAction(snapshot, action)) return null;
    try { return dataAppActionHref(action, actionContext(options), undefined, destination); }
    catch { return null; } // Click handling reports an unrepresentable view; never offer a partial link.
  }
  async function runAction(action, options = {}) {
    if (action === "handoff-preference-error") {
      setActionStatus("Your ChatGPT opening preference couldn't be saved in this browser.");
      return false;
    }
    if (buildBlocksAction(snapshot, action)) {
      setActionStatus("This action is available when ChatGPT finishes the update.");
      return false;
    }
    try {
      if (action === "copy-link") {
        await navigator.clipboard.writeText(viewDataAppReference().sourceUrl
          ?? dashboardUrlWithState(globalThis.location, scopedSnapshot, reportSurface ? [] : tabs,
            currentViewRef.current, { preserveExisting: false })?.toString() ?? "");
        setActionStatus("Link copied.");
        return true;
      }
      const accepted = await submitDataAppAction(action, actionContext(options));
      if (!accepted) setActionStatus(`This host cannot complete that ${surfaceNoun} action.`);
      return accepted;
    } catch (error) {
      setActionStatus(
        error instanceof Error ? error.message : `${surfaceNoun === "report" ? "Report" : "Dashboard"} action failed.`,
      );
      return false;
    }
  }
  async function requestReportFollowUp(action, followUp) {
    if (snapshot.surface !== "report"
      || !["report-investigate", "report-investigate-update", "report-correct"].includes(action)
      || (!canEdit && (action !== "report-investigate" || followUp?.editorOnly))) {
      setActionStatus("You cannot change this report.");
      return false;
    }
    const current = { ...followUp,
      text: narrativeEdits[followUp?.narrativeId] ?? followUp?.text };
    return runAction(action, { followUp: current });
  }
  function reportFollowUpHref(followUp) {
    const current = { ...followUp,
      text: narrativeEdits[followUp?.narrativeId] ?? followUp?.text };
    return dataAppPromptLinkProps(destination => actionHref("report-investigate", { followUp: current }, destination));
  }
  function openAuthoredReportFollowUp(event) {
    if (event.defaultPrevented) return;
    // Older authored ReportTaskLink copies forward only href and target. Route
    // those existing reader links through the same chooser without rewriting them.
    const link = event.target.closest?.("a.report-task-link");
    if (!link || !event.currentTarget.contains(link)) return;
    const url = new URL(link.href);
    const nativePrompt = url.protocol === "codex:" && (
      (url.hostname === "new" && /^\/?$/u.test(url.pathname))
      || (url.hostname === "threads" && /^\/(?:new|[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12})$/iu.test(url.pathname))
    );
    const prompt = nativePrompt
      ? url.searchParams.get("prompt")
      : url.origin === "https://chatgpt.com" ? url.searchParams.get("q") : null;
    if (!prompt) return;
    event.preventDefault();
    openDataAppHandoff(destination =>
      codexDataAppPromptUrl(prompt, currentDataAppReference(), undefined, undefined, destination).toString());
  }
  function closeChartDialog(dialog) {
    if (dialog?.permalink) {
      const currentRoute = readComponentPermalink(globalThis.location);
      if (
        currentRoute?.kind === "chart" &&
        currentRoute.detail &&
        componentMatchesPermalink(dialog.component.id, currentRoute.id)
      ) {
        const url = new URL(window.location.href);
        url.pathname = new URL(chartPermalink(window.location, currentRoute.id)).pathname;
        window.history.replaceState(window.history.state, "", url);
        handledComponentPermalink.current = null;
        componentTabProbe.current = null;
        if (componentHighlight.current) {
          clearTimeout(componentHighlight.current.timeout);
          componentHighlight.current.element.removeAttribute("data-permalink-target");
          componentHighlight.current = null;
        }
        setLinkedComponent(readComponentPermalink(url));
      }
    }
    chartEditorRef.current?.close();
  }
  function saveChartDialog(spec, dialog) {
    if (!canEdit || dialog?.type !== "explore") return;
    const previous = chartOverrides[dialog.component.id] ?? dialog.component.chart;
    if (
      previous.y !== spec.y ||
      previous.series !== spec.series ||
      JSON.stringify(previous.fields ?? []) !== JSON.stringify(spec.fields ?? [])
    ) {
      updateChartState(dialog.component.id, { visibleSeries: undefined });
    }
    setChartOverrides((current) => ({ ...current, [dialog.component.id]: spec }));
  }
  const actions = {
    editMode: canEdit && mode === "edit",
    canEdit,
    published: hosted,
    onOpen: (type, component) => {
      const next = {
        type,
        component,
        ...(type === "explore"
          ? {
              originalOverride: chartOverrides[component.id],
              dirty: false,
              resetVersion: 0,
              draft: component.chart,
              history: [component.chart],
              historyIndex: 0,
            }
          : {}),
      };
      if (type !== "explore") {
        chartEditorRef.current?.close();
        sourceSidebarRef.current?.open(component);
        return;
      }
      sourceSidebarRef.current?.close();
      chartEditorRef.current?.open(next);
    },
    onHide: (id) => setHidden((current) => new Set([...current, id])),
    onCopy: copyComponent,
    additionalActions: (component) => component.chart && chartExportAction(component, () => {
      const bounds = componentTargets.current.get(component.id)?.element.getBoundingClientRect();
      const chart = resolveChartSpec(component.chart, chartOverrides[component.id]);
      setChartExport({
        component: { ...component, chart },
        rows: component.displayRows ?? reviewedRows(component.queryId, [chart.x, chart.series].filter(Boolean)),
        originalSize: { width: bounds?.width ?? 1000, height: bounds?.height ?? 600 },
        provenance: chartExportMetadata(queries[component.queryId], [
          ...activeFilters.filter(filter => !filter.queryIds || filter.queryIds.includes(component.queryId)),
          ...(component.scopeFilters ?? []),
        ]),
        visibleSeries: chartStates[component.id]?.visibleSeries,
        zoomRange: chartStates[component.id]?.zoomRange,
      });
    }),
    onRegisterComponent: registerComponent,
    titleOverrides: componentTitles,
    onTitleChange: (value, id) => setComponentTitles((current) => ({ ...current, [id]: value })),
  };
  const setBlockLayout = useCallback(
    (regionId, layout) => {
      if (!canEdit) return;
      setBlockLayouts((current) => ({ ...current, [regionId]: layout }));
    },
    [canEdit],
  );
  const blockLayoutContext = useMemo(() => ({ blockLayouts, setBlockLayout }), [blockLayouts, setBlockLayout]);
  const shellContext = useMemo(
    () => ({
      snapshot: scopedSnapshot,
      hosted,
      canEdit,
      queries,
      queryDataStore,
      filters,
      setFilter,
      reviewedRows,
      reviewedPeriodRows,
      reviewedAggregatePeriodRows,
      activeFilters,
      mode,
      appTitle,
      setAppTitle,
      assumptions,
      setAssumptions,
      sectionViews,
      setSectionView,
      chartOverrides,
      chartStates,
      visible,
      updateChartState,
      chartProps,
      resolveColor,
      surfaceNoun,
      componentActions: actions,
      chartExportActive: Boolean(chartExport),
      activeTabId,
      registerDashboardTabs,
      setDashboardBusy, exploreDashboard, returnFromExploration, setDashboardFocus, viewFocus, canReturnFromExploration: Boolean(drillReturn),
      hiddenBlockIds: hidden,
      narrativeEdits,
      reportFollowUpHref,
      requestReportFollowUp,
      requestTextEdit,
      setNarrativeEdit: (id, value) => setNarrativeEdits((current) => ({ ...current, [id]: value })),
    }),
    [
      scopedSnapshot,
      hosted,
      canEdit,
      queries,
      queryDataStore,
      filters,
      setFilter,
      reviewedRows,
      reviewedPeriodRows,
      reviewedAggregatePeriodRows,
      activeFilters,
      mode,
      appTitle,
      assumptions,
      sectionViews,
      setSectionView,
      chartOverrides,
      chartStates,
      chartExport,
      resolveColor,
      hidden,
      activeTabId,
      registerDashboardTabs,
      setDashboardBusy, exploreDashboard, returnFromExploration, setDashboardFocus, viewFocus, drillReturn,
      componentTitles,
      activeTheme,
      appearance,
      viewerAppearance,
      narrativeEdits,
    ],
  );

  return (
    <DataAppContext.Provider value={shellContext}>
      <DataAppBlockLayoutContext.Provider value={blockLayoutContext}>
        <DashboardAskProvider
          canEdit={ownerCanEdit}
          enabled={canUseDashboardAsk({ canEdit: ownerCanEdit, mode })}
          explorationEnabled={mode === "view"}
          dashboardTitle={appTitle}
          onStatus={setActionStatus}
        >
          <div className="dashboard-root">
            <DataAppTopbar
              title={appTitle}
              buildStatus={snapshot.buildStatus}
              generatedAt={snapshot.generatedAt}
              reportAsOf={snapshot.report?.asOf}
              status={snapshot.status}
              surface={snapshot.surface}
              mode={mode}
              onModeChange={(next) => { if (next === "edit") beginEditing(); }}
              onSave={saveEditing}
              onCancel={cancelEditing}
              saving={Boolean(editSession?.saving)}
              editHistory={editHistory}
              onTitleChange={setAppTitle}
              onAction={runAction}
              getActionHref={actionHref}
              onOpenThemes={() => setThemesOpen(true)}
              published={hosted}
              canEdit={ownerCanEdit}
              verification={verification}
              pendingVerification={pendingVerification}
              onVerificationReminderError={setActionStatus}
              onVerificationChange={
                hosted && canEdit && !reportSurface
                  ? (verified) => {
                      if (mode !== "edit" || !editSession || editSession.saving) return;
                      setPendingVerification(verified === Boolean(verification) ? null : verified ? "verify" : "remove");
                    }
                  : undefined
              }
              saveStatus={saveStatus}
              hiddenCount={hidden.size}
              onRestoreHidden={() => setHidden(new Set())}
              tabs={snapshot.surface === "report" || !tabRegistrationReady ? [] : tabs}
              activeTabId={activeTabId}
              onTabChange={navigateDashboardTab}
              onReorderTabs={setTabs}
            />
            <DataAppThemeDrawer
              open={themesOpen}
              activeTheme={displayedTheme}
              originalTokens={originalThemeTokens}
              appearance={viewerAppearance || appearance}
              onAppearanceChange={(value) => {
                if (canEdit) {
                  setAppearance(value);
                  setViewerAppearance("");
                  if (persistLocally) writeViewerAppearance(snapshot, "");
                } else {
                  setViewerAppearance(value);
                  if (persistLocally) writeViewerAppearance(snapshot, value);
                }
              }}
              onClose={() => setThemesOpen(false)}
              onApply={(themeId) => {
                applyDataAppTheme(themeId);
                if (build.active) setViewerTheme(themeId);
                else if (canEdit) { setViewerTheme(null); setActiveTheme(themeId); }
                setThemesOpen(false);
              }}
              onPreview={applyDataAppTheme}
              onPreviewEnd={() => applyDataAppTheme(displayedTheme)}
            />
            <DataAppToast message={actionStatus} onDismiss={() => setActionStatus("")} />
            {hosted && <DataAppHandoffDialog onStatus={setActionStatus} />}
            {chartExport && <ChartExportDialog {...chartExport} resolveColor={resolveColor} onClose={() => setChartExport(null)} />}

            <main
              inert={editSession?.saving || undefined}
              ref={editingRoot}
              className={`page${snapshot.surface === "report" ? " report-page" : ""}`}
              data-data-app-content={snapshot.surface}
              data-dashboard-page={activeTabId}
              onClick={hosted ? openAuthoredReportFollowUp : undefined}
              onDoubleClick={
                canEdit
                  ? (event) => {
                      const target = editableTextTarget(event.currentTarget, event.target);
                      if (target) requestTextEdit(target);
                    }
                  : undefined
              }
            >
              {children}

              <ChartEditorHost
                ref={chartEditorRef}
                reviewedRows={reviewedRows}
                resolveColor={resolveColor}
                chartStates={chartStates}
                canEdit={canEdit}
                onClose={closeChartDialog}
                onSave={saveChartDialog}
              />
              <SourceSidebarHost
                ref={sourceSidebarRef}
                queries={queries}
                reviewedRows={reviewedRows}
                activeFilters={activeFilters}
                chartStates={chartStates}
                snapshot={snapshot}
              />
            </main>
          </div>
        </DashboardAskProvider>
      </DataAppBlockLayoutContext.Provider>
    </DataAppContext.Provider>
  );
}
