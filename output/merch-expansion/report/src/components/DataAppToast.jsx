import React, { useEffect } from "react";

import { Icon } from "./Icon.jsx";

export function DataAppToast({ message, onDismiss, duration = 3500 }) {
  useEffect(() => {
    if (!message) return undefined;
    const timer = setTimeout(onDismiss, duration);
    return () => clearTimeout(timer);
  }, [duration, message, onDismiss]);

  if (!message) return null;
  const displayMessage = typeof message === "string" ? message.replace(/\.\s*$/u, "") : message;
  return (
    <div className="dashboard-toast" role="status" aria-live="polite">
      <span>{displayMessage}</span>
      <button type="button" className="dashboard-toast-dismiss" aria-label="Dismiss notification" onClick={onDismiss}>
        <Icon name="close" size={15} />
      </button>
    </div>
  );
}
