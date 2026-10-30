import React, { useEffect, useId, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";

import { sourcePreviewLineIndex, sourcePreviewPosition, sourcePreviewProvider } from "../source-preview.js";
import { SourceProviderIcon } from "./SourceProviderIcon.jsx";
import { SourcePreviewCardContent } from "./SourcePreviewCardContent.jsx";

const linkRects = (element) => [...element.getClientRects()].filter((rect) => rect.width > 0 && rect.height > 0);
const hoverDelay = 250;

// Supplemental source context. The original anchor remains the only navigation
// control; the tooltip has no buttons or links of its own.
export function SourcePreviewLink({ preview, children, ...attributes }) {
  const provider = sourcePreviewProvider(preview.href);
  const id = useId();
  const anchor = useRef(null);
  const panel = useRef(null);
  const openTimer = useRef(null);
  const closeTimer = useRef(null);
  const pinned = useRef(false);
  const pointerType = useRef("mouse");
  const [open, setOpen] = useState(false);
  const [opening, setOpening] = useState(false);
  const [position, setPosition] = useState(null);
  const [anchorLine, setAnchorLine] = useState(0);
  const cancelClose = () => clearTimeout(closeTimer.current);
  function cancelOpen() { clearTimeout(openTimer.current); setOpening(false); }
  function show() { cancelOpen(); cancelClose(); setOpen(true); }
  function scheduleOpen() {
    cancelOpen(); cancelClose();
    if (open) return;
    setOpening(true);
    openTimer.current = setTimeout(show, hoverDelay);
  }
  function close() { cancelOpen(); cancelClose(); pinned.current = false; setOpen(false); setPosition(null); setAnchorLine(0); }
  function pointAt(event) {
    setAnchorLine(sourcePreviewLineIndex(linkRects(event.currentTarget), { x: event.clientX, y: event.clientY }));
  }
  function scheduleClose() {
    cancelOpen(); cancelClose();
    closeTimer.current = setTimeout(() => {
      if (!pinned.current && !anchor.current?.contains(document.activeElement)
        && !panel.current?.contains(document.activeElement)) close();
    }, 180);
  }
  function focusLeft(event) {
    if (anchor.current?.contains(event.relatedTarget) || panel.current?.contains(event.relatedTarget)) return;
    pinned.current = false;
    if (event.relatedTarget) close();
    else scheduleClose();
  }
  useEffect(() => () => { clearTimeout(openTimer.current); clearTimeout(closeTimer.current); }, []);
  useLayoutEffect(() => {
    if (!open) return;
    const place = () => {
      if (!anchor.current || !panel.current) return;
      const rects = linkRects(anchor.current);
      const bounds = rects[Math.min(anchorLine, rects.length - 1)] ?? anchor.current.getBoundingClientRect();
      if (bounds.bottom <= 12 || bounds.top >= window.innerHeight - 12) { close(); return; }
      const card = panel.current;
      const height = card.scrollHeight + card.offsetHeight - card.clientHeight;
      setPosition(sourcePreviewPosition(bounds, { width: card.getBoundingClientRect().width, height },
        { width: window.innerWidth, height: window.innerHeight }));
    };
    place();
    window.addEventListener("resize", place);
    window.addEventListener("scroll", place, true);
    return () => { window.removeEventListener("resize", place); window.removeEventListener("scroll", place, true); };
  }, [open, anchorLine, preview.title, preview.summary]);
  useEffect(() => {
    if (!open && !opening) return;
    function outside(event) {
      if (!anchor.current?.contains(event.target) && !panel.current?.contains(event.target)) close();
    }
    function escape(event) {
      if (event.key !== "Escape") return;
      close();
    }
    document.addEventListener("pointerdown", outside);
    document.addEventListener("keydown", escape);
    return () => { document.removeEventListener("pointerdown", outside); document.removeEventListener("keydown", escape); };
  }, [open, opening]);
  return <>
    <a {...attributes} ref={anchor} href={preview.href} className="source-preview-link"
      aria-describedby={open ? id : undefined}
      onPointerEnter={(event) => { if (event.pointerType !== "touch") { pointAt(event); scheduleOpen(); } }}
      onPointerMove={(event) => { if (event.pointerType !== "touch") pointAt(event); }}
      onPointerLeave={scheduleClose}
      onFocus={(event) => { if (event.currentTarget.matches(":focus-visible")) setAnchorLine(0); show(); }} onBlur={focusLeft}
      onPointerDown={(event) => { cancelOpen(); pointerType.current = event.pointerType; pointAt(event); }}
      onDoubleClick={(event) => event.stopPropagation()}
      onKeyDown={() => { pointerType.current = "keyboard"; }}
      onClick={(event) => {
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return;
        if (pointerType.current === "touch" && !pinned.current) {
          event.preventDefault(); pinned.current = true; show();
        } else close();
      }}>{children}</a>
    {open && createPortal(<div ref={panel} id={id} role="tooltip" className="popover source-preview-card"
      style={position ?? { left: 12, top: 12, visibility: "hidden" }}
      onPointerEnter={cancelClose} onPointerLeave={scheduleClose}>
      <SourcePreviewCardContent preview={preview} icon={<SourceProviderIcon provider={provider} />}
        sourceLabel={preview.source || provider.label} />
    </div>, document.body)}
  </>;
}
