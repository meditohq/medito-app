import React, { useEffect, useLayoutEffect, useId, useRef, useState } from "react";

/** In-page links. The compact rail expands in place, not into an adjacent menu. */
export function SectionNavigator({ sections = [], label = "Sections", placement = "auto" }) {
  const nav = useRef(null), motion = useRef(null), dismissed = useRef(false);
  const jumpPointer = useRef(null);
  const [activeId, setActiveId] = useState(sections[0]?.id), [open, setOpen] = useState(false);
  const [fitsGutter, setFitsGutter] = useState(false);
  const menuId = useId();
  const root = () => nav.current?.parentElement;
  const target = id => root()?.querySelector(`#${CSS.escape(id)}`);
  useLayoutEffect(() => {
    if (placement === "inline" || !nav.current) return undefined;
    const element = nav.current, content = root(), menu = element.querySelector(".section-navigator-menu");
    let frame;
    const measure = () => {
      frame = null;
      const contentStart = content.getBoundingClientRect().left + (parseFloat(getComputedStyle(content).paddingLeft) || 0);
      // The persistent rail must fit outside content. The transient hover menu
      // is a popover, not permanently reserved sidebar width.
      const fits = contentStart >= 12 + element.offsetWidth + 16;
      setFitsGutter(fits);
      if (!fits) setOpen(false);
    };
    const schedule = () => { if (frame == null) frame = requestAnimationFrame(measure); };
    const observer = new ResizeObserver(schedule);
    observer.observe(content); observer.observe(menu);
    window.addEventListener("resize", schedule);
    measure();
    return () => { cancelAnimationFrame(frame); observer.disconnect(); window.removeEventListener("resize", schedule); };
  }, [placement, sections]);
  useEffect(() => {
    let frame;
    const update = () => {
      frame = null;
      if (motion.current != null) return;
      const available = sections.map(section => ({ id: section.id, element: target(section.id) })).filter(section => section.element);
      const bounds = root()?.getBoundingClientRect();
      const top = Math.max(0, bounds?.top ?? 0), bottom = Math.min(window.innerHeight, bounds?.bottom ?? window.innerHeight);
      const marker = top + Math.max(0, bottom - top) * .32;
      let current = available[0]?.id;
      for (const section of available) if (section.element.getBoundingClientRect().top <= marker) current = section.id;
      setActiveId(current);
    };
    const schedule = () => { if (frame == null) frame = requestAnimationFrame(update); };
    const cancelMotion = () => { cancelAnimationFrame(motion.current); motion.current = null; };
    const closeOutside = event => { if (!nav.current?.contains(event.target)) { dismissed.current = false; jumpPointer.current = null; setOpen(false); } };
    update();
    document.addEventListener("pointerdown", closeOutside);
    document.addEventListener("scroll", schedule, { passive: true, capture: true });
    document.addEventListener("wheel", cancelMotion, { passive: true });
    document.addEventListener("touchstart", cancelMotion, { passive: true });
    document.addEventListener("keydown", cancelMotion);
    window.addEventListener("resize", schedule);
    return () => { cancelAnimationFrame(frame); cancelMotion();
      document.removeEventListener("pointerdown", closeOutside); document.removeEventListener("scroll", schedule, true); document.removeEventListener("wheel", cancelMotion);
      document.removeEventListener("touchstart", cancelMotion); document.removeEventListener("keydown", cancelMotion);
      window.removeEventListener("resize", schedule); };
  }, [sections]);
  if (!sections.length) return null;
  function navigate(event, id) {
    event.preventDefault();
    const element = target(id);
    if (!element) return;
    dismissed.current = true; setOpen(false);
    jumpPointer.current = event.detail > 0 ? { x: event.clientX, y: event.clientY } : null;
    const shell = nav.current.closest(".dashboard-root");
    const header = shell?.querySelector(".dashboard-topbar")?.getBoundingClientRect().bottom ?? 52;
    const filters = root()?.querySelector(".filter-bar")?.getBoundingClientRect().height ?? 0;
    let scroller = element.parentElement;
    while (scroller && (!/(auto|scroll)/.test(getComputedStyle(scroller).overflowY) || scroller.scrollHeight <= scroller.clientHeight)) scroller = scroller.parentElement;
    scroller ??= document.scrollingElement;
    const top = scroller === document.scrollingElement ? 0 : scroller.getBoundingClientRect().top;
    const from = scroller.scrollTop;
    const to = Math.max(0, Math.min(scroller.scrollHeight - scroller.clientHeight,
      from + element.getBoundingClientRect().top - Math.max(top, header) - filters - 16));
    cancelAnimationFrame(motion.current);
    const start = performance.now();
    const duration = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 180;
    const animate = now => {
      const progress = duration ? Math.min(1, (now - start) / duration) : 1;
      scroller.scrollTo({ top: from + (to - from) * (1 - (1 - progress) ** 3), behavior: "instant" });
      motion.current = progress < 1 ? requestAnimationFrame(animate) : null;
    };
    motion.current = requestAnimationFrame(animate);
    window.history.replaceState(window.history.state, "", `#${encodeURIComponent(id)}`);
    setActiveId(id);
    const hadTabIndex = element.hasAttribute("tabindex");
    if (!hadTabIndex) element.tabIndex = -1;
    element.focus({ preventScroll: true });
    if (!hadTabIndex) element.addEventListener("blur", () => element.removeAttribute("tabindex"), { once: true });
  }
  return <nav ref={nav} className="section-navigator" data-placement={placement} data-fits-gutter={fitsGutter} inert={placement !== "inline" && !fitsGutter ? true : undefined} data-open={open || undefined} aria-label={label}
    onPointerMove={event => {
      const pointer = jumpPointer.current;
      // A stationary pointer must not reopen the menu during the jump. A fresh
      // mouse movement can reopen it without requiring a leave/enter cycle.
      if (event.pointerType !== "mouse" || !pointer || motion.current != null
        || Math.hypot(event.clientX - pointer.x, event.clientY - pointer.y) < 4) return;
      jumpPointer.current = null; dismissed.current = false; setOpen(true);
    }}
    onPointerEnter={event => { if (event.pointerType === "mouse" && !dismissed.current) setOpen(true); }}
    onPointerLeave={() => { jumpPointer.current = null; dismissed.current = false; if (!nav.current.contains(document.activeElement)) setOpen(false); }}
    onFocusCapture={() => { if (!dismissed.current) setOpen(true); }}
    onBlurCapture={event => { if (!event.currentTarget.contains(event.relatedTarget)) setOpen(false); }}
    onKeyDown={event => { if (event.key === "Escape") { jumpPointer.current = null; dismissed.current = true; setOpen(false); nav.current.querySelector("button").focus(); } }}>
    <button type="button" className="section-navigator-trigger" aria-label={label} aria-expanded={open} aria-controls={menuId}
      onClick={() => { dismissed.current = false; setOpen(true); }}>
      <span className="section-navigator-rail" aria-hidden="true">{sections.map(section =>
        <span key={section.id}><i data-active={activeId === section.id || undefined} /></span>)}</span>
      <span className="section-navigator-label">{label}</span>
    </button>
    <div id={menuId} className="section-navigator-menu popover" inert={!open ? true : undefined}>
      {sections.map(section => <a key={section.id} href={`#${encodeURIComponent(section.id)}`} className="menu-item"
        onClick={event => navigate(event, section.id)} aria-current={activeId === section.id ? "location" : undefined}>
        <span className="menu-item-label">{section.label}</span></a>)}
    </div>
  </nav>;
}
