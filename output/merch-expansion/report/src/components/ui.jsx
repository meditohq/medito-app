import * as DialogPrimitive from "@radix-ui/react-dialog";
import * as Dropdown from "@radix-ui/react-dropdown-menu";
import React, { useEffect, useId, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";

import { Icon } from "./Icon.jsx";
export { Select } from "./Select.jsx";
import { useTouchReleaseTrigger } from "./touch-release-trigger.js";

export function Button({ variant = "secondary", className = "", ...props }) {
  return <button type="button" {...props} className={`button ${variant} ${className}`.trim()} />;
}

export function useInputModality(target) {
  useEffect(() => {
    // Focus restoration after a pointer-operated menu must not paint a keyboard ring.
    // Keep this on the document so portalled menus/dialogs share the same modality.
    const root = target ?? document.documentElement;
    const doc = root.ownerDocument;
    const previous = root.getAttribute("data-input-modality");
    const pointer = () => { root.dataset.inputModality = "pointer"; };
    const keyboard = event => {
      if (!event.metaKey && !event.ctrlKey && !event.altKey
        && !["Shift", "Control", "Alt", "Meta"].includes(event.key)) root.dataset.inputModality = "keyboard";
    };
    doc.addEventListener("pointerdown", pointer, true);
    doc.addEventListener("keydown", keyboard, true);
    return () => {
      doc.removeEventListener("pointerdown", pointer, true);
      doc.removeEventListener("keydown", keyboard, true);
      if (previous === null) delete root.dataset.inputModality;
      else root.dataset.inputModality = previous;
    };
  }, [target]);
}

export function Checkbox({ children, checked, onChange, disabled = false, className = "" }) {
  return <label className={`form-checkbox ${className}`.trim()}>
    <span className="form-checkbox-control">
      <input type="checkbox" checked={checked} disabled={disabled} onChange={onChange} />
      <Icon name="checkboxUnchecked" size={20} />
      <Icon name="checkboxChecked" size={20} />
    </span>
    <span>{children}</span>
  </label>;
}

const tooltipWarmUntil = new WeakMap();

export function Tooltip({ children, className = "", portal = false, visible, ...props }) {
  const elementRef = useRef(null);
  useEffect(() => {
    const element = elementRef.current;
    const trigger = element?.closest("[data-delayed-tooltip]");
    if (!trigger) return undefined;
    const doc = trigger.ownerDocument;
    let timer, opened = false;
    const enter = () => {
      clearTimeout(timer);
      const warm = (tooltipWarmUntil.get(doc) ?? 0) > Date.now();
      trigger.toggleAttribute("data-tooltip-warm", warm);
      const value = doc.defaultView.getComputedStyle(trigger).getPropertyValue("--tooltip-delay").trim();
      const delay = warm ? 0 : (parseFloat(value) || 0) * (value.endsWith("ms") ? 1 : 1000);
      timer = setTimeout(() => { opened = true; tooltipWarmUntil.set(doc, Infinity); }, delay);
    };
    const leave = () => {
      clearTimeout(timer);
      if (opened) tooltipWarmUntil.set(doc, Date.now() + 300);
      opened = false;
      trigger.removeAttribute("data-tooltip-warm");
    };
    trigger.addEventListener("pointerenter", enter);
    trigger.addEventListener("pointerleave", leave);
    trigger.addEventListener("focusin", enter);
    trigger.addEventListener("focusout", leave);
    return () => {
      leave();
      trigger.removeEventListener("pointerenter", enter);
      trigger.removeEventListener("pointerleave", leave);
      trigger.removeEventListener("focusin", enter);
      trigger.removeEventListener("focusout", leave);
    };
  }, []);
  const tooltip = (
    <span
      {...props}
      ref={elementRef}
      className={["dashboard-tooltip", className].filter(Boolean).join(" ")}
      data-visible={visible == null ? undefined : String(visible)}
      role="tooltip"
    >
      {children}
    </span>
  );
  return portal && typeof document !== "undefined" ? createPortal(tooltip, document.body) : tooltip;
}

/** Reveal clipped text without adding tooltips to labels that already fit. */
export function TruncatedText({ as: Tag = "span", children, focusOnParent = false, anchorRef, ...props }) {
  const anchor = useRef(null), tip = useRef(null), timer = useRef(null);
  const [text, setText] = useState(null);
  const id = useId();
  const hide = () => { clearTimeout(timer.current); setText(null); };
  const show = () => {
    clearTimeout(timer.current);
    const element = anchor.current;
    if (!element || element.isContentEditable || element.scrollWidth <= element.clientWidth) return;
    timer.current = setTimeout(() => setText(element.textContent), 350);
  };
  useEffect(() => () => clearTimeout(timer.current), []);
  useEffect(() => {
    if (!focusOnParent) return undefined;
    const parent = anchor.current?.parentElement;
    if (!parent) return undefined;
    const dismiss = event => { if (event.key === "Escape") hide(); };
    parent.addEventListener("focus", show);
    parent.addEventListener("blur", hide);
    parent.addEventListener("keydown", dismiss);
    return () => { parent.removeEventListener("focus", show); parent.removeEventListener("blur", hide); parent.removeEventListener("keydown", dismiss); };
  });
  useLayoutEffect(() => {
    if (!text || !tip.current) return;
    const position = () => {
      const bounds = anchor.current.getBoundingClientRect(), tooltip = tip.current;
      const view = anchor.current.ownerDocument.defaultView;
      tooltip.style.maxWidth = `${Math.min(360, view.innerWidth - 24)}px`;
      const size = tooltip.getBoundingClientRect();
      tooltip.style.left = `${Math.max(12, Math.min(view.innerWidth - size.width - 12, bounds.left))}px`;
      tooltip.style.top = `${Math.max(12, bounds.bottom + size.height + 8 < view.innerHeight - 12
        ? bounds.bottom + 8 : bounds.top - size.height - 8)}px`;
    };
    position();
    const view = anchor.current.ownerDocument.defaultView;
    view.addEventListener("resize", hide);
    view.addEventListener("scroll", hide, true);
    return () => { view.removeEventListener("resize", hide); view.removeEventListener("scroll", hide, true); };
  }, [text]);
  return <><Tag {...props} ref={element => { anchor.current = element; anchorRef?.(element); }}
    aria-describedby={!focusOnParent && text ? id : props["aria-describedby"]}
    onPointerEnter={event => { props.onPointerEnter?.(event); show(); }}
    onPointerLeave={event => { props.onPointerLeave?.(event); hide(); }}
    onPointerDown={event => { props.onPointerDown?.(event); hide(); }}
    onFocus={event => { props.onFocus?.(event); show(); }} onBlur={event => { props.onBlur?.(event); hide(); }}
    onKeyDown={event => { props.onKeyDown?.(event); if (event.key === "Escape") hide(); }}>{children}</Tag>
    {text && createPortal(<span ref={tip} id={id} role="tooltip" aria-hidden={focusOnParent || undefined}
      data-tooltip-portal="true" className="info-tooltip truncated-text-tooltip">{text}</span>,
      anchor.current.getRootNode().host ? anchor.current.getRootNode() : anchor.current.ownerDocument.body)}
  </>;
}

export function Menu({ label, trigger, children, align = "end", side = "bottom", contentClassName = "", open, onOpenChange, contentProps = {}, portalContainer }) {
  const [localOpen, setLocalOpen] = useState(false);
  const isOpen = open ?? localOpen;
  const changeOpen = next => { if (open === undefined) setLocalOpen(next); onOpenChange?.(next); };
  const release = useTouchReleaseTrigger(update => changeOpen(typeof update === "function" ? update(isOpen) : update));
  const touchTrigger = React.cloneElement(trigger, {
    onPointerDownCapture: event => { trigger.props.onPointerDownCapture?.(event); release.onPointerDownCapture(event); },
    onPointerMove: event => { trigger.props.onPointerMove?.(event); release.onPointerMove(event); },
    onPointerCancel: event => { trigger.props.onPointerCancel?.(event); release.onPointerCancel(event); },
    onPointerUp: event => { trigger.props.onPointerUp?.(event); release.onPointerUp(event); },
  });
  return (
    <Dropdown.Root modal={false} open={isOpen} onOpenChange={changeOpen}>
      <Dropdown.Trigger asChild>{touchTrigger}</Dropdown.Trigger>
      <Dropdown.Portal container={portalContainer}>
        <Dropdown.Content
          {...contentProps}
          aria-label={label}
          align={align}
          side={side}
          className={["popover", contentClassName].filter(Boolean).join(" ")}
          collisionPadding={12}
          sideOffset={7}
          onCloseAutoFocus={(event) => {
            contentProps.onCloseAutoFocus?.(event);
            if (document.activeElement?.closest?.('[data-permalink-target="true"]')) event.preventDefault();
          }}
        >
          {children}
        </Dropdown.Content>
      </Dropdown.Portal>
    </Dropdown.Root>
  );
}

export function MenuItem({
  icon,
  leading,
  danger = false,
  children,
  subtext,
  onSelect,
  className = "",
  href,
  target,
  rel,
  ...props
}) {
  const itemProps = {
    ...props,
    className: `menu-item${subtext ? " has-subtext" : ""}${danger ? " danger" : ""}${className ? ` ${className}` : ""}`,
  };
  const content = (
    <>
      {leading ?? (icon && <Icon name={icon} />)}
      {subtext ? (
        <span className="menu-item-copy">
          <span className="menu-item-label">{children}</span>
          <span className="menu-item-subtext">{subtext}</span>
        </span>
      ) : (
        <span className="menu-item-label">{children}</span>
      )}
    </>
  );

  if (href)
    return (
      <Dropdown.Item
        asChild
        onSelect={(event) => {
          onSelect?.(event);
          event.preventDefault();
        }}
      >
        <a
          {...itemProps}
          href={href}
          target={target}
          rel={rel ?? "noopener noreferrer"}
          onKeyDownCapture={(event) => {
            if (event.key === "Enter") event.stopPropagation();
          }}
        >
          {content}
        </a>
      </Dropdown.Item>
    );

  return (
    <Dropdown.Item {...itemProps} onSelect={onSelect}>
      {content}
    </Dropdown.Item>
  );
}

export function MenuSub({ icon, leading, label, children, contentClassName = "", triggerClassName = "", portalContainer }) {
  return (
    <Dropdown.Sub>
      <Dropdown.SubTrigger
        className={["menu-item", triggerClassName].filter(Boolean).join(" ")}
        onPointerLeave={(event) => {
          // A clamped submenu can appear under the pointer; entering it must preserve focus.
          const submenuId = event.currentTarget.getAttribute("aria-controls");
          const submenu = submenuId && event.currentTarget.ownerDocument.getElementById(submenuId);
          if (event.pointerType === "mouse" && event.relatedTarget instanceof Node && submenu?.contains(event.relatedTarget)) {
            event.preventDefault();
          }
        }}
      >
        {leading ?? (icon && <Icon name={icon} />)}
        <span className="menu-item-label">{label}</span>
        <Icon name="chevronRight" className="menu-chevron" />
      </Dropdown.SubTrigger>
      <Dropdown.Portal container={portalContainer}>
        <Dropdown.SubContent
          aria-label={label}
          className={["popover", "menu-sub-content", contentClassName].filter(Boolean).join(" ")}
          collisionPadding={12}
          sideOffset={6}
        >
          {children}
        </Dropdown.SubContent>
      </Dropdown.Portal>
    </Dropdown.Sub>
  );
}

export function MenuSeparator() {
  return <Dropdown.Separator className="menu-separator" />;
}

export function MenuGroup({ label, children }) {
  return (
    <Dropdown.Group>
      <Dropdown.Label className="menu-group-label">{label}</Dropdown.Label>
      {children}
    </Dropdown.Group>
  );
}

export function InfoTooltip({ label = "More information", children, portalContainer }) {
  const id = useId();
  const triggerRef = useRef(null);
  const tooltipRef = useRef(null);
  const [visible, setVisible] = useState(false);
  const touchRef = useRef(false);
  useEffect(() => {
    if (!visible) return undefined;
    const dismiss = event => {
      if (!triggerRef.current?.contains(event.target)) setVisible(false);
    };
    document.addEventListener("pointerdown", dismiss, true);
    return () => document.removeEventListener("pointerdown", dismiss, true);
  }, [visible]);

  useLayoutEffect(() => {
    if (!visible || typeof window === "undefined") return undefined;
    const trigger = triggerRef.current;
    const wrapper = trigger?.closest(".info-wrap");
    const tooltip = tooltipRef.current;
    if (!trigger || !wrapper || !tooltip) return undefined;

    function positionTooltip() {
      const viewport = { left: 12, right: window.innerWidth - 12 };
      const componentBounds = wrapper.closest("[data-component-id]")?.getBoundingClientRect();
      const componentRange = componentBounds && {
        left: Math.max(viewport.left, componentBounds.left + 12),
        right: Math.min(viewport.right, componentBounds.right - 12),
      };
      const range = componentRange && componentRange.right - componentRange.left >= 180 ? componentRange : viewport;
      tooltip.style.setProperty("--info-tooltip-max-width", `${Math.floor(range.right - range.left)}px`);
      const anchor = trigger.getBoundingClientRect();
      const bounds = tooltip.getBoundingClientRect();
      const above = anchor.top - bounds.height - 8 >= 12;
      const side = above ? "top" : "bottom";
      const center = anchor.left + anchor.width / 2;
      const left = Math.max(range.left, Math.min(range.right - bounds.width, center - bounds.width / 2));
      const preferredTop = above ? anchor.top - bounds.height - 8 : anchor.bottom + 8;
      const top = Math.max(12, Math.min(window.innerHeight - bounds.height - 12, preferredTop));
      wrapper.dataset.tooltipSide = side;
      tooltip.dataset.tooltipSide = side;
      tooltip.style.left = `${left}px`;
      tooltip.style.top = `${top}px`;
      tooltip.style.opacity = "1";
      tooltip.style.visibility = "visible";
    }

    positionTooltip();
    window.addEventListener("resize", positionTooltip);
    window.addEventListener("scroll", positionTooltip, true);
    return () => {
      window.removeEventListener("resize", positionTooltip);
      window.removeEventListener("scroll", positionTooltip, true);
    };
  }, [visible, children]);

  function hideTooltip() {
    if (touchRef.current) return;
    if (triggerRef.current?.matches(":focus")) return;
    setVisible(false);
  }

  return (
    <span className="info-wrap" onPointerEnter={event => {
      if (event.pointerType !== "touch") { touchRef.current = false; setVisible(true); }
    }} onPointerLeave={hideTooltip}>
      <button
        ref={triggerRef}
        type="button"
        className="info"
        aria-label={label}
        aria-describedby={visible ? id : undefined}
        onPointerDown={event => { touchRef.current = event.pointerType === "touch"; }}
        onClick={() => { if (touchRef.current) setVisible(current => !current); }}
        onFocus={() => { if (!touchRef.current) setVisible(true); }}
        onBlur={() => { touchRef.current = false; setVisible(false); }}
        onKeyDown={(event) => {
          touchRef.current = false;
          if (event.key === "Escape") event.currentTarget.blur();
        }}
      >
        <Icon name="info" size={16} />
      </button>
      {visible && typeof document !== "undefined" && createPortal(
        <span ref={tooltipRef} id={id} className="info-tooltip" data-tooltip-portal="true" role="tooltip">
          {children}
        </span>,
        portalContainer ?? document.body,
      )}
    </span>
  );
}

function tabElementId(tabsId, tabId, kind) {
  return `${tabsId}-${kind}-${tabId}`;
}

// One measured underline moves between tabs; layout changes never rely on guessed widths.
export function TabIndicator({ navRef, value, inset = 0, motion }) {
  const indicatorRef = useRef(null);
  const previous = useRef(null);
  useLayoutEffect(() => {
    const indicator = indicatorRef.current;
    const nav = navRef.current ?? indicator?.parentElement;
    if (!nav || !indicator) return;
    const update = () => {
      const selected = nav.querySelector('[role="tab"][aria-selected="true"]');
      if (!selected) {
        indicator.hidden = true;
        return;
      }
      indicator.hidden = false;
      const bounds = selected.getBoundingClientRect();
      const parent = nav.getBoundingClientRect();
      const leftInset = selected.closest(".dashboard-tab-item") === nav.firstElementChild ? 0 : inset;
      const next = {
        x: bounds.left - parent.left + nav.scrollLeft + leftInset,
        width: Math.max(0, bounds.width - leftInset - inset),
      };
      if (motion) indicator.style.transition = window.matchMedia("(prefers-reduced-motion: reduce)").matches
        ? "none" : `transform ${motion.duration}ms ${motion.easing}, width ${motion.duration}ms ${motion.easing}`;
      indicator.style.width = `${next.width}px`;
      indicator.style.transform = `translateX(${next.x}px)`;
      const old = previous.current;
      if (
        !motion && old &&
        (old.x !== next.x || old.width !== next.width) &&
        !window.matchMedia("(prefers-reduced-motion: reduce)").matches
      ) {
        indicator.getAnimations?.().forEach((animation) => animation.cancel());
        indicator.animate(
          [
            { transform: `translateX(${old.x}px)`, width: `${old.width}px` },
            { transform: `translateX(${next.x}px)`, width: `${next.width}px` },
          ],
          { duration: 180, easing: "cubic-bezier(.22,1,.36,1)" },
        );
      }
      previous.current = next;
    };
    update();
    const observer = new ResizeObserver(update);
    observer.observe(nav);
    for (const tab of nav.querySelectorAll('[role="tab"]')) observer.observe(tab);
    return () => observer.disconnect();
  }, [navRef, value, inset, motion]);
  return <span ref={indicatorRef} className="tab-active-indicator" aria-hidden="true" />;
}

/** Keep tab overflow in its own strip and reveal only edges with hidden tabs. */
export function useTabOverflow(ref, selectionKey, enabled = true) {
  useLayoutEffect(() => {
    const strip = ref.current;
    if (!strip) return undefined;
    if (!enabled) {
      delete strip.dataset.scrollLeft;
      delete strip.dataset.scrollRight;
      return undefined;
    }

    const update = () => {
      const overflow = strip.scrollWidth > strip.clientWidth + 1;
      strip.dataset.scrollLeft = String(overflow && strip.scrollLeft > 1);
      strip.dataset.scrollRight = String(overflow && strip.scrollLeft + strip.clientWidth < strip.scrollWidth - 1);
    };
    const selected = strip.querySelector('[role="tab"][aria-selected="true"]');
    if (selected) {
      const tab = selected.getBoundingClientRect();
      const viewport = strip.getBoundingClientRect();
      if (tab.left < viewport.left) strip.scrollLeft += tab.left - viewport.left - 12;
      else if (tab.right > viewport.right) strip.scrollLeft += tab.right - viewport.right + 12;
    }
    update();
    const observer = new ResizeObserver(update);
    observer.observe(strip);
    for (const tab of strip.querySelectorAll('[role="tab"]')) observer.observe(tab);
    const wheel = event => {
      if (event.ctrlKey || event.metaKey || event.shiftKey || Math.abs(event.deltaX) >= Math.abs(event.deltaY)) return;
      const before = strip.scrollLeft;
      strip.scrollLeft += event.deltaY;
      if (Math.abs(strip.scrollLeft - before) > .5) {
        event.preventDefault();
        update();
      }
    };
    strip.addEventListener("scroll", update, { passive: true });
    strip.addEventListener("wheel", wheel, { passive: false });
    return () => {
      observer.disconnect();
      strip.removeEventListener("scroll", update);
      strip.removeEventListener("wheel", wheel);
    };
  }, [ref, selectionKey, enabled]);
}

export function Tabs({ id, label, items, value, onChange, className = "", variant = "underline", indicatorMotion }) {
  const generatedId = useId();
  const navRef = useRef(null);
  const tabsId = id ?? `tabs-${generatedId}`;
  useTabOverflow(navRef, `${value}:${items.map(({ id, label }) => `${id}:${label}`).join("|")}`);
  return (
    <nav
      ref={navRef}
      className={`tabs ${variant === "underline" ? "source-tabs" : ""} ${className}`.trim()}
      role="tablist"
      aria-label={label}
      aria-orientation="horizontal"
      onKeyDown={(event) => {
        if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key) || !items.length) return;
        event.preventDefault();
        const current = Math.max(
          0,
          items.findIndex((item) => item.id === value),
        );
        const next =
          event.key === "Home"
            ? 0
            : event.key === "End"
              ? items.length - 1
              : (current + (event.key === "ArrowRight" ? 1 : -1) + items.length) % items.length;
        onChange(items[next].id);
        event.currentTarget.querySelectorAll("[role='tab']")[next]?.focus();
      }}
    >
      {items.map((item) => (
        <button
          key={item.id}
          type="button"
          role="tab"
          aria-selected={value === item.id}
          id={tabElementId(tabsId, item.id, "tab")}
          aria-controls={tabElementId(tabsId, item.id, "panel")}
          tabIndex={value === item.id ? 0 : -1}
          onClick={() => onChange(item.id)}
        >
          {item.label}
        </button>
      ))}
      {(variant === "underline" || className.split(" ").includes("source-tabs")) && <TabIndicator navRef={navRef} value={value} motion={indicatorMotion} />}
    </nav>
  );
}

export function TabPanel({ tabsId, tabId, active, className = "", children, keepMounted = false }) {
  if (!active && !keepMounted) return null;
  return (
    <section
      className={`tab-panel ${className}`.trim()}
      role="tabpanel"
      id={tabElementId(tabsId, tabId, "panel")}
      aria-labelledby={tabElementId(tabsId, tabId, "tab")}
      hidden={!active || undefined}
      tabIndex={0}
    >
      {children}
    </section>
  );
}

export function Dialog({
  open = true,
  title,
  titleInfo,
  initialFocusSelector,
  expanded = false,
  className = "",
  style,
  headerActions,
  onClose,
  children,
  showClose = true,
  backdropClassName = "",
  portalContainer,
  contentRef,
  onKeyDown,
}) {
  const returnFocus = useRef(null);
  return (
    <DialogPrimitive.Root
      open={open}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
    >
      <DialogPrimitive.Portal container={portalContainer}>
        <DialogPrimitive.Overlay className={["dialog-backdrop", backdropClassName].filter(Boolean).join(" ")} />
        <DialogPrimitive.Content
          ref={contentRef}
          onKeyDown={onKeyDown}
          style={style}
          data-shared-dialog
          aria-describedby={undefined}
          onOpenAutoFocus={(event) => {
            returnFocus.current = event.currentTarget.ownerDocument.activeElement;
            if (!initialFocusSelector) return;
            const initial = event.currentTarget.querySelector(initialFocusSelector);
            if (!initial) return;
            event.preventDefault();
            initial.focus({ preventScroll: true });
          }}
          onCloseAutoFocus={(event) => {
            const routeTarget = event.currentTarget.ownerDocument.querySelector('[data-permalink-target="true"]');
            // Navigation owns focus when it moves away from this dialog's opener.
            if (routeTarget && !routeTarget.contains(returnFocus.current)) {
              event.preventDefault();
              routeTarget.focus({ preventScroll: true });
              return;
            }
            if (!returnFocus.current?.isConnected) return;
            event.preventDefault();
            returnFocus.current.focus({ preventScroll: true });
          }}
          className={["dialog", expanded ? "expanded" : "source-dialog", className].filter(Boolean).join(" ")}
        >
          <header className="dialog-header" tabIndex={initialFocusSelector === ".dialog-header" ? -1 : undefined}>
            <div className="dialog-title-group">
              <DialogPrimitive.Title>{title}</DialogPrimitive.Title>
              {titleInfo && <InfoTooltip label="How scheduling works">{titleInfo}</InfoTooltip>}
            </div>
            <div className="dialog-header-actions">
              {headerActions}
              {showClose && (
                <DialogPrimitive.Close className="icon-button" aria-label="Close">
                  <Icon name="cross" size={20} />
                </DialogPrimitive.Close>
              )}
            </div>
          </header>
          <div className="dialog-content">{children}</div>
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}
