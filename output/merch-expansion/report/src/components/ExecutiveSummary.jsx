import React, { useId, useState } from "react";


export function ExecutiveSummary({
  title = "Executive summary",
  preview,
  open,
  defaultOpen = false,
  onOpenChange,
  headingLevel = 2,
  inset = true,
  className = "",
  children,
}) {
  const [localOpen, setLocalOpen] = useState(defaultOpen);
  const controlled = typeof open === "boolean";
  const resolvedOpen = controlled ? open : localOpen;
  const generatedId = useId().replaceAll(":", "");
  const panelId = `data-executive-summary-panel-${generatedId}`;
  const triggerId = `data-executive-summary-trigger-${generatedId}`;
  const Heading = `h${Math.min(6, Math.max(1, Number(headingLevel) || 2))}`;

  const setOpen = (nextOpen) => {
    if (!controlled) setLocalOpen(nextOpen);
    onOpenChange?.(nextOpen);
  };

  return <section className={[
    "data-executive-summary",
    inset && "data-executive-summary--inset",
    className,
  ].filter(Boolean).join(" ")} data-open={resolvedOpen || undefined}>
    <Heading className="data-executive-summary-heading">
      <button id={triggerId} type="button" className="data-executive-summary-trigger"
        aria-expanded={resolvedOpen} aria-controls={panelId}
        onClick={() => setOpen(!resolvedOpen)}>
        <span className="data-executive-summary-title-group">
          <span className="data-executive-summary-title">{title}</span>
          {!resolvedOpen && preview
            ? <span className="data-executive-summary-preview">{preview}</span>
            : null}
        </span>
        <span className="data-executive-summary-toggle-icon" aria-hidden="true" />
      </button>
    </Heading>
    <div id={panelId} className="data-executive-summary-panel" role="region"
      aria-labelledby={triggerId} hidden={!resolvedOpen}>
      <div className="data-executive-summary-content">{children}</div>
    </div>
  </section>;
}
