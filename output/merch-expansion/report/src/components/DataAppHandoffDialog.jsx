import React, { useEffect, useLayoutEffect, useRef, useState } from "react";

import { navigateDataAppHandoff, registerDataAppHandoff } from "../data-app-handoff.js";
import { readHandoffDestination, writeHandoffDestination } from "../handoff-preference.js";
import { dataAppPromptTarget } from "../runtime-environment.js";
import { refreshCoachmarkDomain } from "../refresh-coachmark.js";
import { Checkbox, Dialog } from "./ui.jsx";

export function DataAppHandoffDialog({ onStatus }) {
  const closeTimer = useRef();
  const [pending, setPending] = useState(null);
  const [remember, setRemember] = useState(false);

  useLayoutEffect(() => registerDataAppHandoff(request => {
    const hrefs = {};
    function getHref(destination) {
      if (!Object.hasOwn(hrefs, destination)) {
        try { hrefs[destination] = request.getHref(destination); }
        catch { hrefs[destination] = null; }
      }
      return hrefs[destination];
    }
    const destination = readHandoffDestination();
    try {
      if (destination && getHref(destination) && !request.requireTap)
        return navigateDataAppHandoff(hrefs[destination], request.onNavigate);
    } catch { /* Keep the chooser available if remembered navigation fails. */ }
    const available = ["desktop", "web"].map(getHref).filter(Boolean);
    if (available.length === 1) return navigateDataAppHandoff(available[0], request.onNavigate);
    window.clearTimeout(closeTimer.current);
    setRemember(false);
    setPending({ onNavigate: request.onNavigate, hrefs: { desktop: getHref("desktop"), web: getHref("web") } });
    return true;
  }), []);
  useEffect(() => () => window.clearTimeout(closeTimer.current), []);

  return <Dialog open={Boolean(pending)} title="Open in ChatGPT"
    className="data-app-handoff-dialog" backdropClassName="data-app-handoff-backdrop" onClose={() => setPending(null)}>
    {pending && <>
      <p className="data-app-handoff-question">Where would you like to open this?</p>
      <div className="data-app-handoff-choices">
        {[["desktop", "Open in desktop"], ["web", "Open on web"]].map(([value, label]) => {
          const href = pending.hrefs[value];
          if (!href) return <button key={value} type="button" className="button" disabled>{label}</button>;
          return <a key={value} className="button" href={href} target={dataAppPromptTarget(href)}
            rel="noopener noreferrer" onClick={() => {
              if (remember && !writeHandoffDestination(value)) {
                onStatus?.("Your choice couldn't be saved in this browser. You'll be asked again next time.");
              }
              pending.onNavigate?.();
              // Keep the chosen anchor mounted through native activation.
              closeTimer.current = window.setTimeout(() => setPending(null), 0);
            }}>{label}</a>;
        })}
      </div>
      {!pending.hrefs.web && <p className="data-app-handoff-question">This preview is local to this task. Open it in desktop, or publish it before using ChatGPT on the web.</p>}
      <footer className="data-app-handoff-footer">
        {refreshCoachmarkDomain() && <Checkbox checked={remember} onChange={event => setRemember(event.target.checked)}>
          Remember in this browser
        </Checkbox>}
        <button type="button" className="button" onClick={() => setPending(null)}>Cancel</button>
      </footer>
    </>}
  </Dialog>;
}
