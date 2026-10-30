import React, { useCallback, useId, useLayoutEffect, useRef } from "react";

import { Icon } from "./Icon.jsx";

function deepActiveElement(root) {
  let active = root?.activeElement;
  while (active?.shadowRoot?.activeElement) active = active.shadowRoot.activeElement;
  return active;
}

function dialogFocusableElements(element) {
  return [
    ...element.querySelectorAll(
      'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
    ),
  ].filter(
    (candidate) =>
      candidate.tabIndex >= 0 &&
      !candidate.closest('[inert], [hidden], [aria-hidden="true"]') &&
      candidate.getClientRects().length > 0,
  );
}

/**
 * An intrinsic, host-contained dialog. It never portals the layer, locks the
 * document body, or listens for keys outside its own content.
 */
export function ContainedDialog({
  title,
  initialFocusSelector,
  expanded = false,
  className = "",
  headerActions,
  onClose,
  children,
  showClose = true,
  layerClassName = "",
  contentRef,
  onKeyDown,
}) {
  const ownContentRef = useRef(null);
  const titleId = useId();
  const setContentRef = useCallback(
    (element) => {
      ownContentRef.current = element;
      if (typeof contentRef === "function") contentRef(element);
      else if (contentRef) contentRef.current = element;
    },
    [contentRef],
  );

  useLayoutEffect(() => {
    const element = ownContentRef.current;
    if (!element) return undefined;
    const ownerDocument = element.ownerDocument;
    const focusRoot = element.getRootNode();
    const previousFocus = deepActiveElement(focusRoot) ?? deepActiveElement(ownerDocument);
    const initial = initialFocusSelector ? element.querySelector(initialFocusSelector) : element;
    (initial ?? element).focus({ preventScroll: true });
    return () =>
      queueMicrotask(() => {
        const active = deepActiveElement(focusRoot) ?? deepActiveElement(ownerDocument);
        if (
          active?.isConnected &&
          active !== ownerDocument.body &&
          active !== focusRoot.host &&
          active !== previousFocus &&
          !element.contains(active)
        )
          return;
        if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
      });
  }, [initialFocusSelector]);

  return (
    <div className={["dialog-layer", "dialog-layer--contained", layerClassName].filter(Boolean).join(" ")}>
      <section
        ref={setContentRef}
        role="dialog"
        aria-labelledby={titleId}
        aria-modal={false}
        tabIndex={-1}
        className={["dialog", expanded ? "expanded" : "source-dialog", className].filter(Boolean).join(" ")}
        onKeyDown={(event) => {
          onKeyDown?.(event);
          if (event.defaultPrevented) return;
          if (event.key === "Escape") {
            event.preventDefault();
            event.stopPropagation();
            onClose();
            return;
          }
          if (event.key !== "Tab") return;
          const element = ownContentRef.current;
          const focusable = dialogFocusableElements(element);
          const active = deepActiveElement(element.getRootNode()) ?? deepActiveElement(element.ownerDocument);
          const first = focusable[0];
          const last = focusable.at(-1);
          if (
            !first ||
            (event.shiftKey && (active === first || !focusable.includes(active))) ||
            (!event.shiftKey && (active === last || !focusable.includes(active)))
          ) {
            event.preventDefault();
            (event.shiftKey ? last : first)?.focus({ preventScroll: true });
            if (!first) element.focus({ preventScroll: true });
          }
        }}
      >
        <header className="dialog-header" tabIndex={initialFocusSelector === ".dialog-header" ? -1 : undefined}>
          <div className="dialog-title-group">
            <h2 id={titleId}>{title}</h2>
          </div>
          <div className="dialog-header-actions">
            {headerActions}
            {showClose && (
              <button type="button" className="icon-button" aria-label="Close" onClick={onClose}>
                <Icon name="cross" size={20} />
              </button>
            )}
          </div>
        </header>
        <div className="dialog-content">{children}</div>
      </section>
    </div>
  );
}

/** The shared Select value/choice contract without a portaled menu runtime. */
export function NativeSelect({
  label,
  value,
  choices = [],
  onChange,
  showLabel = false,
  allLabel = "All",
  formatChoice,
  triggerClassName = "",
  disabled = false,
  groups,
}) {
  const display = (choice) => (choice === "all" ? allLabel : choice ? formatChoice?.(choice) ?? choice : "No series");
  const select = (
    <select
      className={["select-trigger", "native-select", triggerClassName].filter(Boolean).join(" ")}
      aria-label={label}
      value={value ?? ""}
      disabled={disabled}
      onChange={(event) => onChange?.(event.currentTarget.value)}
      onKeyDown={(event) => {
        // Let the browser dismiss its own picker without closing the editor.
        if (event.key === "Escape") event.stopPropagation();
      }}
    >
      {(groups ?? [{ choices }]).map((group, index) => {
        const options = group.choices.map((choice) => (
          <option key={choice} value={choice}>
            {display(choice)}
          </option>
        ));
        return group.label ? (
          <optgroup key={group.label} label={group.label}>
            {options}
          </optgroup>
        ) : (
          <React.Fragment key={index}>{options}</React.Fragment>
        );
      })}
    </select>
  );
  return showLabel ? (
    <label className="native-select-field">
      <span className="filter-label">{label}</span>
      {select}
    </label>
  ) : (
    select
  );
}
