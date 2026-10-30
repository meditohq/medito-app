import React from "react";

import { useOptionalDataAppShell } from "../DataAppContext.jsx";
import { EditableText } from "./EditableText.jsx";
import { Icon } from "./Icon.jsx";
import { useOptionalSortableBlock } from "./SortableRegion.jsx";
import { Menu, MenuItem } from "./ui.jsx";

/** A surface-neutral heading; filters stay controlled by their section's caller. */
export function SectionHeader({ id, title, filters, as = "h2", className = "" }) {
  const shell = useOptionalDataAppShell();
  if (typeof id !== "string" || !id.trim()) throw new Error("SectionHeader requires a stable id.");
  const hidden = shell?.hiddenBlockIds.has(id) ?? false;
  const editable = shell?.componentActions.editMode && !hidden;
  const actionsLabel = "Section heading actions";
  return <div className={["data-section-header", className].filter(Boolean).join(" ")}
    hidden={hidden && !filters} data-heading-hidden={hidden || undefined}>
    <EditableText as={as} id={id} className="data-section-title" hidden={hidden}
      data-editable-id={id}>{title}</EditableText>
    {(filters || editable) && <div className="data-section-controls">
      {filters && <div className="data-section-filters" role="group"
        aria-label={typeof title === "string" ? `${title} filters` : "Section filters"}>{filters}</div>}
      {editable && <Menu label={actionsLabel} trigger={
        <button type="button" className="menu-trigger" aria-label={actionsLabel} aria-describedby={id}>
          <Icon name="more" />
        </button>
      }>
        <MenuItem icon="eye" onSelect={() => shell.componentActions.onHide(id)}>Hide heading</MenuItem>
      </Menu>}
    </div>}
  </div>;
}

/** Optional fixed composition, using the same presentation as canvas rows. */
export function Section({ id, title, filters, children, columns = 1, kind = "content",
  spacing = "section", className = "" }) {
  if (filters && !title) throw new Error("Section filters require a section title.");
  return <section className={["data-section", className].filter(Boolean).join(" ")}
    data-section-kind={kind} data-section-spacing={spacing}
    aria-labelledby={title ? id : undefined}
    style={{ "--section-columns": Math.min(12, Math.max(1, Math.floor(columns) || 1)) }}>
    {title && <SectionHeader id={id} title={title} filters={filters} />}
    {children}
  </section>;
}

// Shared controls can live in a canvas header only while that row contains
// exclusively their consumers. Moved consumers keep controls on the card itself.
export function useSectionFilterPlacement(scope, componentId) {
  const sortable = useOptionalSortableBlock();
  if (!scope || sortable?.variant !== "canvas") return { header: true, component: false };
  const row = sortable.rows?.find(({ id }) => id === scope.rowId);
  const visible = row?.items.filter((id) => sortable.visibleItemIds.has(id)) ?? [];
  const header = visible.length > 0 && visible.every((id) => scope.componentIds.includes(id));
  return { header, component: !header || !visible.includes(componentId) };
}
