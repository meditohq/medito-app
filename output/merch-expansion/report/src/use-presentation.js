import { useEffect, useLayoutEffect, useRef, useState } from "react";

import { editHistoryValue, recordPresentationEdit, mergePresentationChanges, normalizePresentation, validatePresentation, writeLocalPresentation } from "./presentation-state.js";
import { readVerificationReminderDismissed, rememberVerificationReminderDismissed } from "./verification-reminder.js";

function serializePresentation(value) {
  if (value !== null && typeof value === "object"
    && [Object.prototype, null].includes(Object.getPrototypeOf(value))) {
    value = Object.fromEntries(Object.keys(value).sort().map((key) => [key, value[key]]));
  }
  return JSON.stringify(value);
}

// Check only on a verification click, not render. This also observes a cookie
// changed by another dashboard or cleared by the browser without polling.
export function useVerificationReminder(environment) {
  const [dismissed, setDismissed] = useState(false);
  const check = () => {
    const current = readVerificationReminderDismissed(environment);
    setDismissed(current);
    return current;
  };
  const remember = () => {
    const retained = rememberVerificationReminderDismissed(environment);
    setDismissed(retained);
    return retained;
  };
  return { dismissed, check, remember };
}

export function usePresentationHistory(presentation, enabled, restore) {
  const value = editHistoryValue(presentation);
  const [history, setHistory] = useState(() => ({ entries: [value], index: 0 }));
  useLayoutEffect(() => {
    setHistory((current) => recordPresentationEdit(current, value, enabled));
  }, [value, enabled]);
  const step = (direction) => {
    const index = history.index + direction;
    if (!enabled || index < 0 || index >= history.entries.length) return;
    setHistory({ ...history, index });
    restore(JSON.parse(history.entries[index]));
  };
  useEffect(() => {
    if (!enabled) return undefined;
    const onKeyDown = (event) => {
      if (event.defaultPrevented || !(event.metaKey || event.ctrlKey) || event.altKey
        || event.target?.closest?.('input, textarea, select, [contenteditable="true"], [role="dialog"]')) return;
      const key = event.key.toLowerCase();
      if (key !== "z" && key !== "y") return;
      event.preventDefault();
      step(key === "y" || event.shiftKey ? 1 : -1);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
  return { canUndo: enabled && history.index > 0, canRedo: enabled && history.index < history.entries.length - 1,
    undo: () => step(-1), redo: () => step(1) };
}

export function usePresentationPersistence({
  snapshot, hosted, presentation, personalPresentation = {}, initialPresentation,
  initialRevision = 0, canEdit = true, endpoint = "/api/presentation", verificationAction = null,
  persistLocally = true,
  onAcknowledged, onError,
}) {
  const [status, setStatus] = useState("idle");
  const sharedInitial = Object.fromEntries(Object.entries(normalizePresentation(initialPresentation))
    .filter(([field]) => Object.hasOwn(presentation, field)));
  const latest = useRef(normalizePresentation({ ...presentation, ...sharedInitial }));
  const revision = useRef(initialRevision);
  // Keep the authored values until the save boundary can reject invalid edits.
  // Normalizing here would silently discard oversized text before validation.
  const serialized = serializePresentation(presentation);
  const personal = JSON.stringify(normalizePresentation(personalPresentation));
  const latestPersonal = useRef(personal);
  latestPersonal.current = personal;
  const previous = useRef(serialized);
  const saveGeneration = useRef(0);
  const acknowledgedGeneration = useRef(0);
  const inFlight = useRef(new Map());

  useEffect(() => {
    if (persistLocally) writeLocalPresentation(snapshot, { ...JSON.parse(serialized), ...JSON.parse(personal) });
  }, [persistLocally, personal, serialized, snapshot]);

  useEffect(() => {
    const unchanged = serialized === previous.current;
    const pending = [...inFlight.current]
      .filter(([generation, value]) => generation > acknowledgedGeneration.current && value !== serialized)
      .map(([, value]) => JSON.parse(value));
    if (unchanged && !verificationAction && !pending.length) return undefined;
    const baseline = JSON.parse(previous.current);
    if (!canEdit) {
      previous.current = serialized;
      return undefined;
    }
    const generation = ++saveGeneration.current;
    let current;
    try {
      current = validatePresentation(JSON.parse(serialized));
    } catch (error) {
      setStatus("error");
      onError?.(error instanceof Error ? error.message : "Unable to save Data app changes.", verificationAction);
      return undefined;
    }
    if (!hosted) {
      previous.current = serialized;
      setStatus("saved");
      onAcknowledged?.(current, verificationAction);
      return undefined;
    }
    setStatus("saving");

    const save = async () => {
      inFlight.current.set(generation, serialized);
      try {
        let next = mergePresentationChanges(baseline, current, latest.current, pending);
        for (let attempt = 0; attempt < 2; attempt += 1) {
          const response = await fetch(endpoint, {
            method: "PUT", headers: { "content-type": "application/json" },
            body: JSON.stringify({
              presentation: next,
              revision: revision.current,
              ...(verificationAction ? { verificationAction } : {}),
            }),
          });
          const result = await response.json();
          if (generation < acknowledgedGeneration.current) return;
          if (response.status === 409 && attempt === 0) {
            if (result.revision < revision.current || generation < saveGeneration.current) return;
            next = mergePresentationChanges(baseline, current, result.presentation, pending);
            revision.current = result.revision;
            continue;
          }
          if (!response.ok) throw new Error(result.error || "Unable to save Data app changes.");
          if (result.revision < revision.current) return;
          const authoritative = normalizePresentation(result.presentation ?? next);
          const acknowledged = JSON.parse(serialized);
          if (authoritative.verification) acknowledged.verification = authoritative.verification;
          else delete acknowledged.verification;
          acknowledgedGeneration.current = generation;
          latest.current = authoritative;
          revision.current = result.revision;
          previous.current = serializePresentation(acknowledged);
          // An older success still advances our server baseline, but cannot
          // acknowledge a newer draft or clear its pending/failed save status.
          if (generation < saveGeneration.current) return;
          if (persistLocally) writeLocalPresentation(snapshot, { ...authoritative, ...JSON.parse(latestPersonal.current) });
          setStatus("saved");
          onAcknowledged?.(authoritative, verificationAction);
          return;
        }
      } catch (error) {
        if (generation < saveGeneration.current) return;
        setStatus("error");
        onError?.(error instanceof Error ? error.message : "Unable to save Data app changes.", verificationAction);
      } finally {
        inFlight.current.delete(generation);
      }
    };

    const timer = setTimeout(save, 300);
    return () => clearTimeout(timer);
  }, [canEdit, endpoint, hosted, onAcknowledged, onError, persistLocally, serialized, snapshot, verificationAction]);

  return status;
}
