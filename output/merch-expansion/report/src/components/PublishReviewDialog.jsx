import React, { useId, useRef, useState } from "react";

import { publishReviewDestination } from "../publish-review.js";
import { dataAppPromptTarget } from "../runtime-environment.js";
import { Icon } from "./Icon.jsx";
import { Dialog } from "./ui.jsx";

export function PublishReviewContent({ published, accessMode, onAccessChange, href, disabled = false }) {
  const id = useId();
  const submitted = useRef(false);
  const [publishing, setPublishing] = useState(false);
  const destination = publishReviewDestination(href);
  return <>
    <div className="publish-review-body">
      <section className="publish-review-section" aria-labelledby={`${id}-audience`}>
        <h3 id={`${id}-audience`}>Who can access</h3>
        {published ? <div className="publish-review-existing">
          <Icon name="lock" size={18} />
          <div><strong>Keep current access</strong><p>Publishing changes won’t change who can view.</p></div>
        </div> : <fieldset className="publish-review-audience" aria-labelledby={`${id}-audience`}>
          {[
            { value: "custom", icon: "lock", title: "Invited people", detail: "Only you until you invite others." },
            { value: "workspace_all", icon: "building", title: "Workspace members", detail: "Anyone in your workspace with the link." },
          ].map(option => <label key={option.value} className="publish-review-option">
            <Icon name={option.icon} size={18} />
            <span><strong>{option.title}</strong><span className="publish-review-option-detail">{option.detail}</span></span>
            <input type="radio" name={`${id}-access`} value={option.value} checked={accessMode === option.value}
              disabled={disabled || publishing}
              onChange={() => onAccessChange(option.value)} aria-label={option.title} />
          </label>)}
        </fieldset>}
      </section>

      <div className="publish-review-permissions">
        <ul className="publish-review-facts">
          <li>Only data published in the dashboard is visible and accessible to viewers</li>
          <li>Source data isn't accessible beyond what is presented by the Editors of the dashboard</li>
          <li>Editors can set up an automation to update the dashboard and site. Viewers iterating on it require their own permissions to access source data</li>
        </ul>
        {publishing && <p role="status">Send the prepared message in ChatGPT, then wait for publishing to finish.</p>}
      </div>
    </div>
    <footer className="publish-review-footer">
      {href && destination ? <a className="button primary dashboard-publish-confirm" href={href} target={dataAppPromptTarget(href)} rel="noopener noreferrer"
        aria-disabled={disabled || publishing} onClick={event => {
          if (disabled || submitted.current) { event.preventDefault(); return; }
          // Keep the first native link activation intact; block subsequent clicks immediately.
          submitted.current = true;
          setPublishing(true);
        }}>
        {publishing ? "Waiting for ChatGPT…" : <>Publish in ChatGPT<Icon name="arrowUpRight" size={16} /></>}
      </a> : <button type="button" className="button primary dashboard-publish-confirm" disabled>Publishing unavailable</button>}
    </footer>
  </>;
}

export function PublishReviewDialog({ open, onClose, ...props }) {
  const noun = props.surface === "report" ? "report" : "dashboard";
  return <Dialog open={open} onClose={onClose} title={props.published ? "Publish changes" : `Publish ${noun}`}
    className="publish-review-dialog" initialFocusSelector=".dialog-header">
    {open && <PublishReviewContent {...props} />}
  </Dialog>;
}
