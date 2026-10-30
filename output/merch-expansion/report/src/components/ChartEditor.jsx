import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";

import {
  changeChartEditorState,
  chartEditorShortcut,
  copyChartEditorPresentation,
  createChartEditorState,
  resetChartEditorState,
  saveChartEditorPresentation,
  stepChartEditorHistory,
} from "../charting/chart-editor-state.js";
import { ChartExplorer } from "./ChartExplorer.jsx";
import { Icon } from "./Icon.jsx";

/** Shared presentation editor. Its caller owns reviewed data and persistence. */
export function ChartEditor({
  DialogComponent,
  SelectComponent,
  TooltipComponent,
  component,
  getRows,
  resolveColor,
  visibleSeries,
  zoomRange,
  canEdit = true,
  onClose,
  onSave,
  variant = "dialog",
  portalContainer,
  themeRoot,
  style,
  previewHeight = 500,
  saveLabel = "Save",
  notice,
  editMetadata = false,
  resetPresentation,
  resetLabel = "Reset to original",
  validatePresentation,
  getCapabilities,
}) {
  if (!DialogComponent || !SelectComponent) {
    throw new Error("ChartEditor requires host DialogComponent and SelectComponent.");
  }
  const [editor, setEditor] = useState(() =>
    createChartEditorState({
      chart: component.chart,
      title: component.title,
      description: component.description,
    }),
  );
  const [dialogElement, setDialogElement] = useState(null);
  const [closing, setClosing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [contentReady, setContentReady] = useState(false);
  const closeTimer = useRef(null);
  const closingRef = useRef(false);
  const savingRef = useRef(false);
  const mounted = useRef(true);
  const ownerWindow =
    dialogElement?.ownerDocument.defaultView ??
    themeRoot?.ownerDocument?.defaultView ??
    (typeof window === "undefined" ? undefined : window);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      ownerWindow?.clearTimeout(closeTimer.current);
    };
  }, [ownerWindow]);
  useEffect(() => {
    if (!ownerWindow) return undefined;
    let secondFrame;
    const frame = ownerWindow.requestAnimationFrame(() => {
      secondFrame = ownerWindow.requestAnimationFrame(() => setContentReady(true));
    });
    return () => {
      ownerWindow.cancelAnimationFrame(frame);
      ownerWindow.cancelAnimationFrame(secondFrame);
    };
  }, [ownerWindow]);
  useEffect(() => {
    if (variant === "contained" || !editor.dirty || !ownerWindow) return undefined;
    const protectDraft = (event) => { event.preventDefault(); event.returnValue = ""; };
    ownerWindow.addEventListener("beforeunload", protectDraft);
    return () => ownerWindow.removeEventListener("beforeunload", protectDraft);
  }, [editor.dirty, ownerWindow, variant]);
  const rows = useMemo(() => (contentReady ? getRows() : []), [contentReady, getRows]);
  const resetTarget = useMemo(
    () => (resetPresentation ? copyChartEditorPresentation({ ...editor.initial, ...resetPresentation }) : null),
    [editor.initial, resetPresentation],
  );

  const dismiss = useCallback(() => {
    if (closingRef.current) return;
    if (!ownerWindow || ownerWindow.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
      onClose();
      return;
    }
    closingRef.current = true;
    setClosing(true);
    closeTimer.current = ownerWindow.setTimeout(onClose, 110);
  }, [onClose, ownerWindow]);
  const requestClose = useCallback(() => {
    if (!savingRef.current) dismiss();
  }, [dismiss]);

  function stepHistory(direction) {
    if (savingRef.current || closingRef.current) return;
    setError("");
    setEditor((current) => stepChartEditorHistory(current, direction));
  }

  async function save() {
    if (!canEdit || !editor.dirty || savingRef.current || closingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    setError("");
    try {
      await saveChartEditorPresentation(editor.draft, { rows, editMetadata, validatePresentation, onSave });
      savingRef.current = false;
      if (mounted.current) {
        setSaving(false);
        dismiss();
      }
    } catch (cause) {
      savingRef.current = false;
      if (mounted.current) {
        setSaving(false);
        setError(cause instanceof Error ? cause.message : "Unable to apply chart changes.");
      }
    }
  }

  function handleKeyDown(event) {
    if (!canEdit || savingRef.current || closingRef.current) return;
    const shortcut = chartEditorShortcut(event);
    if (!shortcut) return;
    event.preventDefault();
    if (variant === "contained") event.stopPropagation();
    if (shortcut === "save") void save();
    else stepHistory(shortcut === "redo" ? 1 : -1);
  }

  const contained = variant === "contained";
  const editorPortalContainer = contained ? dialogElement ?? portalContainer : portalContainer;
  return (
    <DialogComponent
      title={component.title}
      expanded
      style={style}
      initialFocusSelector=".dialog-header"
      variant={variant}
      portalContainer={portalContainer}
      contentRef={setDialogElement}
      layerClassName={contained ? "chart-editor-layer--contained" : ""}
      backdropClassName="chart-editor-backdrop"
      className={`chart-editor-dialog${contained ? " chart-editor-dialog--contained" : ""}${closing ? " is-closing" : ""}`}
      showClose={!canEdit}
      onKeyDown={handleKeyDown}
      headerActions={
        canEdit && (
          <>
            <div className="chart-editor-history" role="group" aria-label="Chart edit history">
              <span className="history-tooltip-trigger">
              <button
                type="button"
                className="chart-editor-icon"
                aria-label="Undo chart change"
                disabled={saving || editor.historyIndex === 0}
                onClick={() => stepHistory(-1)}
              >
                <Icon name="undo" size={18} />
              </button>
              {TooltipComponent && <TooltipComponent className="topbar-mode-tooltip">Undo</TooltipComponent>}
              </span>
              <span className="history-tooltip-trigger">
              <button
                type="button"
                className="chart-editor-icon"
                aria-label="Redo chart change"
                disabled={saving || editor.historyIndex >= editor.history.length - 1}
                onClick={() => stepHistory(1)}
              >
                <Icon name="undo" size={18} className="chart-editor-redo-icon" />
              </button>
              {TooltipComponent && <TooltipComponent className="topbar-mode-tooltip">Redo</TooltipComponent>}
              </span>
            </div>
            {resetTarget && (
              <button
                type="button"
                className="chart-editor-reset"
                disabled={saving || JSON.stringify(editor.draft) === JSON.stringify(resetTarget)}
                onClick={() => {
                  setError("");
                  setEditor((current) => resetChartEditorState(current, resetTarget));
                }}
              >
                {resetLabel}
              </button>
            )}
            <button type="button" className="button ghost chart-editor-cancel" disabled={saving} onClick={requestClose}>
              Cancel
            </button>
            <button
              type="button"
              className="button primary chart-editor-save"
              disabled={saving || !editor.dirty}
              aria-busy={saving || undefined}
              onClick={() => void save()}
            >
              {saveLabel}
            </button>
          </>
        )
      }
      onClose={requestClose}
    >
      {contentReady ? (
        <ChartExplorer
          SelectComponent={SelectComponent}
          component={component}
          rows={rows}
          chartId={component.id}
          resolveColor={resolveColor}
          visibleSeries={visibleSeries}
          zoomRange={zoomRange}
          draft={editor.draft.chart}
          canEdit={canEdit}
          disabled={saving}
          getCapabilities={getCapabilities}
          portalContainer={editorPortalContainer}
          themeRoot={themeRoot}
          previewHeight={previewHeight}
          contained={contained}
          notice={notice}
          error={error}
          metadata={editMetadata ? { title: editor.draft.title, description: editor.draft.description } : undefined}
          onMetadataChange={
            editMetadata
              ? (field, value) => {
                  if (savingRef.current || !["title", "description"].includes(field)) return;
                  setError("");
                  setEditor((current) => changeChartEditorState(current, { ...current.draft, [field]: value }, field));
                }
              : undefined
          }
          onChange={
            canEdit
              ? (chart, _dirty, field) => {
                  if (savingRef.current) return;
                  setError("");
                  setEditor((current) => changeChartEditorState(current, { ...current.draft, chart }, field));
                }
              : undefined
          }
        />
      ) : (
        <div className="chart-explorer editor-loading-layout" aria-label="Loading chart editor">
          <div className="explorer-preview">
            <div className="explorer-preview-skeleton">
              <i />
              <i />
              <i />
              <i />
            </div>
          </div>
          <div className="explorer-controls editor-controls-skeleton">
            <i />
            <i />
            <i />
            <i />
          </div>
        </div>
      )}
    </DialogComponent>
  );
}
