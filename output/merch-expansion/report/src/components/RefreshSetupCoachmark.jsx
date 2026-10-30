import React, { useEffect, useId, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";

import { claimRefreshCoachmark, refreshCoachmarkDomain } from "../refresh-coachmark.js";
import { Icon } from "./Icon.jsx";

export function RefreshSetupCoachmarkCard({ anchor, onDismiss }) {
  const card = useRef(null);
  const titleId = useId();
  const [position, setPosition] = useState(null);
  function dismiss() {
    if (card.current?.contains(card.current.ownerDocument.activeElement)) anchor.current?.focus({ preventScroll: true });
    onDismiss();
  }

  useLayoutEffect(() => {
    const trigger = anchor.current;
    const element = card.current;
    if (!trigger || !element) return undefined;
    const view = trigger.ownerDocument.defaultView;
    const place = () => {
      const box = trigger.getBoundingClientRect();
      const width = Math.min(320, view.innerWidth - 32);
      const left = Math.max(16, Math.min(view.innerWidth - width - 16, box.left));
      setPosition({ width, left, top: Math.min(box.bottom + 12, view.innerHeight - element.offsetHeight - 16),
        "--coachmark-arrow-left": `${Math.max(24, Math.min(width - 24, box.left + box.width / 2 - left))}px` });
    };
    place();
    view.addEventListener("resize", place);
    return () => view.removeEventListener("resize", place);
  }, [anchor]);

  useEffect(() => {
    const document = anchor.current?.ownerDocument;
    if (!document) return undefined;
    function pointer(event) {
      if (!card.current?.contains(event.target)) dismiss();
    }
    function key(event) {
      if (event.key === "Escape") dismiss();
    }
    document.addEventListener("pointerdown", pointer, true);
    document.addEventListener("keydown", key);
    document.addEventListener("scroll", onDismiss, true);
    return () => {
      document.removeEventListener("pointerdown", pointer, true);
      document.removeEventListener("keydown", key);
      document.removeEventListener("scroll", onDismiss, true);
    };
  }, [anchor, onDismiss]);

  return createPortal(<aside ref={card} className="dashboard-refresh-coachmark" aria-labelledby={titleId}
    style={{ ...position, visibility: position ? "visible" : "hidden" }}>
    <div className="dashboard-refresh-coachmark-heading">
      <h3 id={titleId}>Keep this dashboard up to date</h3>
      <button type="button" className="icon-button" aria-label="Dismiss refresh setup tip" onClick={dismiss}><Icon name="cross" /></button>
    </div>
    <p role="status">Set up automatic refreshes from this menu.</p>
  </aside>, anchor.current?.ownerDocument.body ?? document.body);
}

export function RefreshSetupCoachmark({ published, blocked, anchor }) {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (published !== true || blocked || !refreshCoachmarkDomain() || window.top !== window) {
      setVisible(false);
      return undefined;
    }
    let cancelled = false;
    let timer;
    function isBusy() {
      const trigger = anchor.current;
      const box = trigger?.getBoundingClientRect();
      return document.visibilityState !== "visible" || !trigger?.isConnected || !box?.width
        || box.top < 0 || box.bottom > innerHeight
        || document.activeElement?.matches?.('input, textarea, [contenteditable="true"]')
        || document.querySelector('[role="dialog"], [role="menu"], [role="listbox"], .dashboard-ask-panel');
    }
    async function offerWhenIdle() {
      if (isBusy()) { timer = setTimeout(offerWhenIdle, 1500); return; }
      const claimed = await claimRefreshCoachmark({ cancelled: () => cancelled || isBusy() });
      if (!cancelled && claimed) setVisible(true);
    }
    timer = setTimeout(offerWhenIdle, 1800);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [published, blocked, anchor]);

  return visible && !blocked ? <RefreshSetupCoachmarkCard anchor={anchor} onDismiss={() => setVisible(false)} /> : null;
}
