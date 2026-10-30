import React, { useEffect, useId, useRef, useState } from "react";
import { flushSync } from "react-dom";
import dataComposerIcon from "../../../../../assets/datascience-small.svg?url";

import { sourcePreviewPosition } from "../source-preview.js";
import { Icon } from "./Icon.jsx";
import { ReceiptSourceIcon, SourceInspector } from "./SourceInspector.jsx";
import { SourcePreviewCardContent } from "./SourcePreviewCardContent.jsx";

function useReceiptInputModality(rootRef) {
  useEffect(() => {
    const root = rootRef.current;
    const controller = new AbortController();
    const options = { capture: true, signal: controller.signal };
    // Listen before tab handlers and Escape focus restoration, including when
    // focus enters the Shadow DOM from elsewhere in the answer.
    const keyboardInput = (event) => {
      if (event.metaKey || event.altKey || event.ctrlKey || ["Shift", "Control", "Alt", "Meta"].includes(event.key)) return;
      root.dataset.inputModality = "keyboard";
    };
    root.ownerDocument.addEventListener("keydown", keyboardInput, options);
    // Tab can start in the host document and finish inside this iframe. Its
    // keyup reaches the newly focused receipt even when its keydown did not.
    root.ownerDocument.addEventListener("keyup", (event) => {
      if (event.key === "Tab") keyboardInput(event);
    }, options);
    root.ownerDocument.addEventListener("pointerdown", () => {
      root.dataset.inputModality = "pointer";
    }, options);
    return () => controller.abort();
  }, [rootRef]);
}

// Reuse report source-preview timing and placement. Once a tooltip is open,
// moving to an adjacent source changes its content without another hover delay.
function useReceiptTooltips(rootRef, tooltipRef, setTooltipContent) {
  useEffect(() => {
    const root = rootRef.current;
    const tooltip = tooltipRef.current;
    const controller = new AbortController();
    const listen = (target, type, handler, options = {}) =>
      target.addEventListener(type, handler, { ...options, signal: controller.signal });
    const selector = "[data-source-title], [data-tooltip-text]";
    let active, hovered, focused, dismissed, openTimer, closeTimer;
    const cancelOpen = () => { clearTimeout(openTimer); openTimer = null; };
    const cancelClose = () => { clearTimeout(closeTimer); closeTimer = null; };
    const hide = () => {
      cancelOpen(); cancelClose();
      active?.removeAttribute("aria-describedby");
      active = null;
      tooltip.hidden = true;
      delete tooltip.dataset.visible;
    };
    const needsTooltip = (chip) => chip?.getClientRects().length &&
      (!chip.matches(".receipt-filter") || [...chip.children].some((part) => part.scrollWidth > part.clientWidth));
    const place = () => {
      if (!active || tooltip.hidden) return;
      const anchor = active.getBoundingClientRect();
      if (anchor.bottom <= 12 || anchor.top >= window.innerHeight - 12) { hide(); return; }
      tooltip.style.left = "12px";
      tooltip.style.top = "12px";
      tooltip.style.maxHeight = "";
      const bounds = tooltip.getBoundingClientRect();
      if (active.dataset.sourceTitle) {
        const height = tooltip.scrollHeight + tooltip.offsetHeight - tooltip.clientHeight;
        const position = sourcePreviewPosition(anchor, { width: bounds.width, height },
          { width: window.innerWidth, height: window.innerHeight });
        tooltip.style.left = `${position.left}px`;
        tooltip.style.top = `${position.top}px`;
        tooltip.style.maxHeight = `${position.maxHeight}px`;
      } else {
        const width = document.documentElement.clientWidth;
        const height = window.innerHeight;
        tooltip.style.left = `${Math.max(8, Math.min(anchor.left + (anchor.width - bounds.width) / 2, width - bounds.width - 8))}px`;
        const above = anchor.top - bounds.height - 8;
        tooltip.style.top = `${Math.max(8, above >= 8 ? above : Math.min(anchor.bottom + 8, height - bounds.height - 8))}px`;
      }
    };
    const show = (chip) => {
      if (!needsTooltip(chip) || dismissed === chip) return;
      cancelOpen(); cancelClose();
      active?.removeAttribute("aria-describedby");
      active = chip;
      if (chip.dataset.sourceTitle) {
        const sourceType = { table: "Table", file: "File", dashboard: "Dashboard", link: "Document or link" }[chip.dataset.sourceKind];
        flushSync(() => setTooltipContent({ kind: "source", preview: {
          href: chip.href, source: sourceType ?? "Source", sourceKind: chip.dataset.sourceKind, title: chip.dataset.sourceTitle,
          summary: chip.dataset.sourceReason,
        } }));
      } else {
        flushSync(() => setTooltipContent({ kind: "text", text: chip.dataset.tooltipText }));
      }
      tooltip.hidden = false;
      chip.setAttribute("aria-describedby", tooltip.id);
      place();
      tooltip.dataset.visible = "true";
    };
    const schedule = (chip, delay = 250) => {
      cancelOpen(); cancelClose();
      if (chip === active || chip === dismissed) return;
      if (!needsTooltip(chip)) { hide(); return; }
      if (active && !tooltip.hidden) show(chip);
      else openTimer = setTimeout(() => show(chip), delay);
    };
    const scheduleClose = (chip) => {
      cancelOpen(); cancelClose();
      closeTimer = setTimeout(() => {
        if (!tooltip.matches(":hover") && !hovered && focused !== chip) hide();
      }, 180);
    };
    const dismissOnEscape = (event) => {
      if (event.key !== "Escape") return;
      const target = active || hovered || focused;
      if (target) { event.preventDefault(); event.stopPropagation(); dismissed = target; hide(); }
    };
    listen(root, "pointerover", (event) => {
      const chip = event.target.closest(selector);
      if (event.pointerType === "touch" || !chip || chip.contains(event.relatedTarget)) return;
      hovered = chip; dismissed = null; schedule(chip);
    });
    listen(root, "pointerout", (event) => {
      const chip = event.target.closest(selector);
      if (!chip || chip.contains(event.relatedTarget)) return;
      hovered = null;
      scheduleClose(chip);
    });
    listen(root, "focusin", (event) => {
      focused = event.target.closest(selector);
      if (focused) { dismissed = null; schedule(focused, 0); }
    });
    listen(root, "focusout", (event) => {
      const chip = event.target.closest(selector);
      focused = null;
      if (hovered !== chip) hide();
    });
    listen(root, "pointerdown", (event) => {
      const chip = event.target.closest(selector);
      if (event.pointerType === "touch" && needsTooltip(chip)) chip.dataset.touchInspect = active === chip ? "open" : "preview";
    });
    listen(root, "click", (event) => {
      const chip = event.target.closest(selector);
      if (!chip) { hide(); return; }
      if (chip.dataset.touchInspect === "preview") { event.preventDefault(); dismissed = null; show(chip); }
      else if (!chip.matches("a[href]")) { dismissed = null; show(chip); }
      delete chip.dataset.touchInspect;
    });
    listen(root, "keydown", (event) => {
      if (event.key === "Escape") {
        dismissOnEscape(event);
        return;
      }
      const chip = event.target.closest(selector);
      if (chip && ["Enter", " "].includes(event.key) && !chip.matches("a[href]")) {
        event.preventDefault(); dismissed = null; show(chip);
      }
    }, { capture: true });
    // Hover can start while keyboard focus is outside the Shadow-DOM receipt.
    listen(root.ownerDocument, "keydown", dismissOnEscape);
    listen(tooltip, "pointerenter", cancelClose);
    listen(tooltip, "pointerleave", () => { if (!hovered && !focused) scheduleClose(active); });
    listen(root, "scroll", (event) => { if (event.target !== tooltip) active?.dataset.sourceTitle ? place() : hide(); }, { capture: true });
    listen(window, "scroll", (event) => { if (event.target !== tooltip) active?.dataset.sourceTitle ? place() : hide(); }, { capture: true });
    listen(window, "resize", () => active?.dataset.sourceTitle ? place() : hide());
    return () => { hide(); controller.abort(); };
  }, [rootRef, tooltipRef, setTooltipContent]);
}

function SourceCard({ item, collapsible }) {
  const [open, setOpen] = useState(!collapsible);
  const contentId = `receipt-card-${useId()}`;
  const toggle = useRef(null);
  function collapse() {
    setOpen(false);
    window.requestAnimationFrame(() => toggle.current?.focus());
  }
  return <article className="receipt-card" data-open={open} aria-label={item.title}
    onKeyDown={(event) => {
      if (collapsible && open && event.key === "Escape" && !event.defaultPrevented) {
        event.preventDefault(); event.stopPropagation(); collapse();
      }
    }}>
    {collapsible && <div className="receipt-card-label" hidden={open} aria-hidden="true">
      <span>{item.title}</span>
    </div>}
    {collapsible && <button ref={toggle} type="button" className="receipt-card-toggle"
      aria-label={open ? `Collapse ${item.title}` : item.title}
      aria-expanded={open} aria-controls={contentId} onClick={open ? collapse : () => setOpen(true)}>
      <Icon name="chevronDown" size={16} />
    </button>}
    <div id={contentId} hidden={!open} className="receipt-card-content">
      <SourceInspector component={{ id: item.id, title: item.title, description: item.description, kind: "narrative" }}
        receiptQueries={item.queries} filters={[]} allowCopy={false}
        receiptAssumptions={item.assumptions}
        onReceiptCollapse={collapsible ? collapse : undefined} receiptContentId={contentId}
        externalReceiptToggle={collapsible} />
    </div>
  </article>;
}

/** One answer-level disclosure; native answer prose is intentionally not part of this payload. */
export function SourcesReceipt({ items }) {
  const root = useRef(null);
  const tooltip = useRef(null);
  const tooltipId = `receipt-tooltip-${useId()}`;
  const [tooltipContent, setTooltipContent] = useState(null);
  useReceiptInputModality(root);
  useReceiptTooltips(root, tooltip, setTooltipContent);
  const [open, setOpen] = useState(false);
  const contentId = `receipt-${useId()}`;
  const toggle = useRef(null);
  return <div ref={root} className="sources-receipt" data-input-modality="pointer" onKeyDown={(event) => {
    if (open && event.key === "Escape" && !event.defaultPrevented) {
      event.preventDefault(); event.stopPropagation(); setOpen(false); toggle.current?.focus();
    }
  }}>
    <div className="receipt-toolbar"><button ref={toggle} type="button" className="receipt-disclosure" aria-expanded={open}
      aria-controls={contentId} onClick={() => setOpen(!open)}>
      <img src={dataComposerIcon} width={16} height={16} alt="" aria-hidden="true" />
      <span>{items.length === 1 ? "Sources" : `Sources • ${items.length}`}</span>
      <Icon name="chevronDown" size={14} />
    </button></div>
    <div id={contentId} className="receipt-expander" data-open={open} inert={!open} aria-hidden={!open}>
      <div className="receipt-expander-inner"><div className="receipt-cards">
        {items.map((item) => <SourceCard key={item.id} item={item} collapsible={items.length > 1} />)}
      </div></div>
    </div>
    <div ref={tooltip} id={tooltipId} role="tooltip" hidden
      className={tooltipContent?.kind === "source" ? "receipt-tooltip popover source-preview-card" : "receipt-tooltip"}
      data-kind={tooltipContent?.kind === "source" ? "source" : undefined}>
      {tooltipContent?.kind === "source" ? <SourcePreviewCardContent preview={tooltipContent.preview}
        icon={<span className="source-preview-provider-icon" aria-hidden="true">
          <ReceiptSourceIcon kind={tooltipContent.preview.sourceKind} label={tooltipContent.preview.title} />
        </span>} sourceLabel={tooltipContent.preview.source} /> : tooltipContent?.text}
    </div>
  </div>;
}
