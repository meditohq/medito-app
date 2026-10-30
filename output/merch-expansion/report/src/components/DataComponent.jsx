import React, { useEffect, useLayoutEffect, useRef, useState } from "react";

import { canDownloadChartImage } from "../chart-image.js";
import { validComponentId } from "../chart-permalink.js";
import { resolveChartSpec } from "../charting/chart-overrides.js";
import { useOptionalDataAppShell } from "../DataAppContext.jsx";
import { reviewedNarrativeQueries } from "../source-provenance.js";
import { Icon } from "./Icon.jsx";
import { Filters } from "./Controls.jsx";
import { RichNarrative } from "./RichMarkdown.jsx";
import { useSectionFilterPlacement } from "./Section.jsx";
import { SmoothCardSurface } from "./SmoothCardSurface.jsx";
import { ComponentSkeleton, ComponentState } from "../charting/ChartState.jsx";
import { InfoTooltip, Menu, MenuItem, MenuSeparator, TruncatedText } from "./ui.jsx";

function requireStableComponentId(id) {
  if (typeof id !== "string" || !id.trim()) {
    throw new Error("DataComponent requires a non-empty stable id.");
  }
  return id;
}

function Info({ description }) {
  return <InfoTooltip>{description}</InfoTooltip>;
}

function menuItems(children) {
  return React.Children.toArray(children).flatMap(child => {
    if (!React.isValidElement(child)) return [];
    if (child.type === React.Fragment) return menuItems(child.props.children);
    return child.type === MenuItem ? [child] : [];
  });
}

export function ComponentActions({
  component,
  editMode,
  canEdit = true,
  published = false,
  onOpen,
  onHide,
  onEdit,
  onCopy,
  additionalActions,
  required = false,
}) {
  const label = `${component.title} actions`;
  const nativeSelect = useRef(null);
  useLayoutEffect(() => { if (nativeSelect.current) nativeSelect.current.selectedIndex = -1; });
  const [imageReady, setImageReady] = useState(false);
  useEffect(() => {
    if (!component.chart) { setImageReady(false); return; }
    const target = document.querySelector(`[data-component-id="${CSS.escape(component.id)}"]`);
    if (!target) return;
    const update = () => setImageReady(canDownloadChartImage(component.id));
    update();
    const observer = new MutationObserver(update);
    observer.observe(target, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [component.id, Boolean(component.chart)]);
  const inspectActions = [
    canEdit && component.chart && <MenuItem key="edit-chart" icon="edit" onSelect={() => onOpen("explore", component)}>Edit chart</MenuItem>,
    <MenuItem key="source" icon="database" onSelect={() => onOpen("source", component)}>View data source</MenuItem>,
  ].filter(Boolean);
  const copyActions = [
    onCopy && component.chart && imageReady
      && <MenuItem key="copy-image" icon="copy" onSelect={() => onCopy("image", component)}>Copy as image</MenuItem>,
    onCopy && <MenuItem key="copy-data" icon="copy" onSelect={() => onCopy("data", component)}>Copy data</MenuItem>,
    published && onCopy && validComponentId(component.id) && <MenuItem key="copy-link" icon="link"
      onSelect={() => onCopy(component.chart ? "link" : "component-link", component)}>Copy link</MenuItem>,
    ...menuItems(additionalActions).filter(action => !action.props["data-requires-chart-image"] || imageReady),
  ].filter(Boolean);
  const editActions = [
    canEdit && onEdit && <MenuItem key="edit-text" icon="edit" onSelect={onEdit}>Edit text</MenuItem>,
    canEdit && editMode && !required
      && <MenuItem key="hide" icon="trash" danger onSelect={() => onHide(component.id)}>Hide</MenuItem>,
  ].filter(Boolean);
  const actionGroups = [inspectActions, copyActions, editActions].filter(group => group.length);
  const actions = actionGroups.flat();
  function chooseNativeAction(event) {
    const index = Number(event.currentTarget.value);
    event.currentTarget.selectedIndex = -1; // A command is not a persistent selection.
    const action = actions[index];
    if (action?.props.href) {
      window.open(action.props.href, action.props.target ?? "_self");
    } else if (action?.props.onSelect) {
      // Release the OS picker before mounting an editor, inspector, or dialog.
      requestAnimationFrame(() => action.props.onSelect());
    }
  }
  return (
    <>
      <span className="component-custom-actions"><Menu label={label} trigger={
        <button type="button" className="menu-trigger" aria-label={label}><Icon name="more" /></button>
      }>{actionGroups.map((group, index) => <React.Fragment key={index}>
        {index > 0 && <MenuSeparator />}{group}
      </React.Fragment>)}</Menu></span>
      <span className="menu-trigger component-native-actions">
        <Icon name="more" />
        <select ref={nativeSelect} aria-label={label} onChange={chooseNativeAction}>
          {actionGroups.map((group, groupIndex) => <React.Fragment key={groupIndex}>
            {groupIndex > 0 && <hr />}
            {group.map(action => <option key={action.key ?? actions.indexOf(action)} value={actions.indexOf(action)}
              disabled={action.props.disabled}>{action.props.children}</option>)}
          </React.Fragment>)}
        </select>
      </span>
    </>
  );
}

export function DataComponent({
  id, title, queryId, queryIds, kind, chart, dataInputs, displayRows, sourceRows, sourceRowsByQuery,
  description, editMode, canEdit, className = "",
  published, onOpen, onHide, onEdit, onCopy, onRegisterComponent, onTitleChange, titleOverrides, additionalActions,
  hideDescriptionTooltip = false, variant = "plain", padding = "standard", smoothCorners,
  scopeFilters = [], showHeading = true, showActions = true, headingLevel = 2, sectionFilters, headerControls, children, loading, loadingError, loadingKind = kind, loadingHeight, onRetry,
}) {
  const elementRef = useRef(null);
  const settledHeight = useRef(null);
  const settledBodyHeight = useRef(null);
  useLayoutEffect(() => {
    if ((loading === undefined && loadingError === undefined) || loading || loadingError || !elementRef.current) return;
    const measure = () => {
      const element = elementRef.current;
      if (!element) return;
      settledHeight.current = element.getBoundingClientRect().height;
      const body = [...element.children].filter(child => !child.matches(".smooth-card-surface, .component-header, .component-section-filters"))
        .map(child => child.getBoundingClientRect()).filter(rect => rect.height > 0);
      if (body.length) settledBodyHeight.current = Math.max(...body.map(rect => rect.bottom)) - Math.min(...body.map(rect => rect.top));
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(elementRef.current);
    return () => observer.disconnect();
  }, [loading, loadingError]);
  const shell = useOptionalDataAppShell();
  const sharedActions = shell?.componentActions ?? {};
  editMode ??= sharedActions.editMode ?? false;
  canEdit ??= sharedActions.canEdit ?? true;
  published ??= sharedActions.published ?? false;
  onOpen ??= sharedActions.onOpen;
  onHide ??= sharedActions.onHide;
  onCopy ??= sharedActions.onCopy;
  onRegisterComponent ??= sharedActions.onRegisterComponent;
  onTitleChange ??= sharedActions.onTitleChange;
  titleOverrides ??= sharedActions.titleOverrides;
  const componentId = requireStableComponentId(id);
  const effectiveChart = chart ? resolveChartSpec(chart, shell?.chartOverrides?.[componentId], dataInputs) : chart;
  if (typeof queryId !== "string" || !queryId.trim()) {
    throw new Error(`DataComponent "${componentId}" requires a stable reviewed query id.`);
  }
  const reviewedQueryIds = reviewedNarrativeQueries({
    id: componentId, queryId, queryIds, kind, chart: effectiveChart, sourceRowsByQuery, displayRows,
  }, shell?.queries);
  const [editedTitle, setEditedTitle] = useState(title);
  const displayedTitle = titleOverrides?.[id] ?? (onTitleChange ? title : editedTitle);
  const editableTitle = editMode && canEdit;
  // Keep existing custom report blocks compatible. New narrative sections own
  // their Markdown and opt into a separate heading explicitly.
  const reportNarrative = shell?.snapshot.surface === "report" && kind === "custom";
  const pending = loading || Boolean(loadingError);
  const stateHeight = settledBodyHeight.current ?? loadingHeight ?? (React.isValidElement(children) ? children.props.height : undefined)
    ?? (loadingKind === "metric" ? 48 : loadingKind === "table" ? 320 : 240);
  const component = { id: componentId, title: displayedTitle, queryId, kind, chart: pending ? undefined : effectiveChart, displayRows: pending ? [] : displayRows, sourceRows: pending ? [] : sourceRows, description, scopeFilters,
    ...(reviewedQueryIds.length > 1 ? { queryIds: reviewedQueryIds } : {}),
    ...(sourceRowsByQuery ? { sourceRowsByQuery: pending ? Object.fromEntries(reviewedQueryIds.map(id => [id, []])) : sourceRowsByQuery } : {}),
  };
  const Heading = `h${Math.max(2, Math.min(6, Number(headingLevel) || 2))}`;
  const card = variant === "card";
  const filterPlacement = useSectionFilterPlacement(sectionFilters?.sectionScope, componentId);
  let mergedNarrative = false;
  const content = reportNarrative && showHeading ? React.Children.map(children, (child) => {
    if (mergedNarrative || !React.isValidElement(child) || child.type !== RichNarrative
      || typeof child.props.id !== "string" || typeof child.props.value !== "string") return child;
    mergedNarrative = true;
    const authored = typeof child.props.value === "string" ? child.props.value.replace(/\\r\\n|\\n/g, "\n") : "";
    const markdown = /^\s*#{1,4}\s+/u.test(authored)
      ? authored
      : `## ${displayedTitle}\n\n${authored.trim()}`;
    return React.cloneElement(child, { value: markdown });
  }) : children;
  const renderHeading = showHeading && !mergedNarrative;
  const narrativeActions = !renderHeading && (reportNarrative || kind === "narrative");
  const showDescription = !hideDescriptionTooltip && description
    && description.trim().toLowerCase() !== displayedTitle.trim().toLowerCase();
  const titleTailParts = showDescription && kind !== "metric" && !editableTitle
    ? /^(.*\s)(\S+)$/us.exec(displayedTitle) ?? ["", "", displayedTitle] : null;
  function commitTitle(event) {
    const next = event.currentTarget.textContent.trim();
    if (!next) {
      event.currentTarget.textContent = displayedTitle;
      return;
    }
    if (onTitleChange) onTitleChange(next, id);
    else setEditedTitle(next);
  }
  return (
    <section className={["dashboard-component", className, editMode && "is-editing"].filter(Boolean).join(" ")}
      ref={(element) => { elementRef.current = element; onRegisterComponent?.(component, element); }}
      aria-busy={loading || undefined} data-loading-kind={pending ? loadingKind : undefined}
      style={pending && settledHeight.current ? { height: settledHeight.current, minHeight: settledHeight.current } : undefined}
      tabIndex={-1}
      data-component-variant={variant} data-card-padding={card ? padding : undefined}
      data-component-id={componentId} data-component-kind={kind} data-query-id={queryId}
      data-query-ids={reviewedQueryIds.length > 1 ? reviewedQueryIds.join(" ") : undefined}>
      {(smoothCorners ?? card) && <SmoothCardSurface />}
      {(showActions || renderHeading || headerControls) && <header className={["component-header", headerControls && "has-controls", narrativeActions && "report-narrative-actions"].filter(Boolean).join(" ")}>
        {renderHeading && <Heading className="component-title">
          <TruncatedText className="component-title-text" contentEditable={editableTitle}
            suppressContentEditableWarning aria-label={editableTitle ? `Edit ${displayedTitle} title` : undefined}
            onBlur={editableTitle ? commitTitle : undefined}
            onKeyDown={editableTitle ? (event) => {
              if (event.key === "Enter") { event.preventDefault(); event.currentTarget.blur(); }
              if (event.key === "Escape") {
                event.currentTarget.textContent = displayedTitle;
                event.currentTarget.blur();
              }
            } : undefined}>
            {titleTailParts ? <>{titleTailParts[1]}<span className="component-title-tail">
              {titleTailParts[2]}<Info description={description} />
            </span></> : displayedTitle}
          </TruncatedText>
          {showDescription && !titleTailParts && <Info description={description} />}
        </Heading>}
        {headerControls && <div className="component-header-controls" data-block-no-drag>{headerControls}</div>}
        {showActions && !pending && <ComponentActions component={component} editMode={editMode} canEdit={canEdit} published={published}
          onOpen={onOpen} onHide={onHide} onEdit={onEdit} onCopy={onCopy} additionalActions={<>{sharedActions.additionalActions?.(component)}{additionalActions}</>} />}
      </header>}
      {sectionFilters && filterPlacement.component && <div className="component-section-filters" data-block-no-drag>
        <span className="component-section-filter-label">{sectionFilters.ariaLabel}</span>
        <Filters {...sectionFilters} sectionScope={undefined} ariaLabel={`${displayedTitle} filters`} />
      </div>}
      {pending ? <div className="component-skeleton" style={{ "--component-state-height": typeof stateHeight === "number" ? `${stateHeight}px` : stateHeight }}>
        {loadingError ? <ComponentState error kind={loadingKind} height={settledHeight.current ? 0 : stateHeight} onRetry={onRetry} />
          : <div className="component-loading-body" role="status" aria-label={`Updating ${displayedTitle}`}>
            <ComponentSkeleton kind={loadingKind} chart={chart} rows={displayRows ?? (React.isValidElement(children) ? children.props.rows : undefined)} />
          </div>}
      </div> : content}
    </section>
  );
}

// Optional source-aware wrapper; authored children determine the document structure.
export function ReportSection({ className = "", ...props }) {
  return <DataComponent {...props} kind="narrative" hideDescriptionTooltip
    className={["report-narrative-section", className].filter(Boolean).join(" ")} />;
}
