import { useEffect, useLayoutEffect, useRef } from "react";

const narrativeSelector = [
  "h1", "h2:not(.component-title)", "h3", "h4", "h5", "h6", "p", "li", "figcaption", "blockquote",
  ".report-facts dt", ".report-facts > div > span", "[data-editable-narrative]",
].join(", ");

const protectedInterfaceSelector = [
  ".component-title", "[data-data-app-title]", ".source-sidebar", ".markdown-editor", ".popover",
  ".theme-drawer", ".editor-bar",
  ".info-tooltip", ".recharts-wrapper", ".chart-axis-label", ".table-wrap", ".table-pagination",
  ".toolbar", ".filter-bar", ".data-metric-card-tabs",
  "[data-component-kind='custom'] ol:not([data-editable-narrative])",
  "[data-component-kind='custom'] ul:not([data-editable-narrative])",
  "[data-reviewed-rows]", "[data-source-rows]", "[role='row']", "[role='grid']",
  ".scenario-lever", ".scenario-summary", ".forecast-details", ".source-value", ".metric-value",
  ".forecast-value", ".scenario-value", ".scenario-caption", ".scenario-label", ".comparison",
  ".fresh-metric-value", ".fresh-metric-detail", ".showcase-metric-value", "svg", "table", "button",
  "a", "input", "select", "textarea", "output", "label", "[aria-live]", "[data-status]",
  "[role='status']", "[role='tooltip']", "[role='dialog']", "[role='button']", "[role='menu']", "[role='tab']",
].join(", ");

const protectedValueSelector = "[data-reviewed-value], [data-source-value], [data-modeled-value]";
const authoredValueTextSelector = [
  ".report-facts dt", ".report-facts > div > span", ".analysis-caption", ".report-disclosure",
  "[data-editable-narrative]",
].join(", ");

function editableElement(element, activeDraft = false) {
  return Boolean(element?.matches(narrativeSelector)
    && (activeDraft || element.textContent.trim())
    && !element.closest(protectedInterfaceSelector)
    && (!element.closest(protectedValueSelector) || element.matches(authoredValueTextSelector))
    && !element.closest("[data-rich-narrative]")
    && (activeDraft || (!element.querySelector("button, a, input, select, textarea, [role='button']")
      && (!element.matches("div, ol, ul, dl, section, article")
        || !element.querySelector(narrativeSelector)))));
}

export function editableTextTarget(root, target) {
  const richNarrative = target?.closest?.("[data-rich-narrative]");
  if (richNarrative && root?.contains(richNarrative)) return richNarrative;
  const candidate = target?.closest?.(`${narrativeSelector}, [data-data-app-title], .component-title-text`);
  if (!candidate || !root?.contains(candidate)) return null;
  if (candidate.matches("[data-data-app-title], .component-title-text")) return candidate;
  return editableElement(candidate) ? candidate : null;
}

function editableElements(root, activeElement) {
  const candidates = [...root.querySelectorAll(narrativeSelector)].filter((element) =>
    editableElement(element, element === activeElement && element.dataset.inlineEditable === "true"));
  const candidateSet = new Set(candidates);
  return candidates.filter((element) => {
    for (let parent = element.parentElement; parent && parent !== root; parent = parent.parentElement) {
      if (candidateSet.has(parent)) return false;
    }
    return true;
  });
}

function narrativeId(root, element, scopeIndexes) {
  const component = element.closest("[data-component-id]");
  const scope = component ?? element.closest("section, header, aside") ?? root;
  const scopeId = component?.dataset.componentId || scope.id
    || scope.getAttribute("aria-label") || String(scope.className || "Data app").split(/\s+/)[0];
  let indexes = scopeIndexes.get(scope);
  if (!indexes) {
    indexes = new Map();
    scopeIndexes.set(scope, indexes);
  }
  const group = `${component?.dataset.componentId ?? ""}:${element.tagName}`;
  const index = indexes.get(group) ?? 0;
  indexes.set(group, index + 1);
  return element.id || element.dataset.editableId || `${scopeId}:${element.tagName.toLowerCase()}:${index}`;
}

function restoreFormattedText(element, value, authoredMarkup) {
  if (!authoredMarkup.firstElementChild) {
    element.textContent = value;
    return;
  }

  const restored = authoredMarkup.cloneNode(true);
  const original = restored.textContent;
  const walker = element.ownerDocument.createTreeWalker(restored, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  if (!nodes.length) {
    element.textContent = value;
    return;
  }

  let prefix = 0;
  while (prefix < original.length && prefix < value.length && original[prefix] === value[prefix]) prefix += 1;
  let suffix = 0;
  while (suffix < original.length - prefix && suffix < value.length - prefix
    && original[original.length - suffix - 1] === value[value.length - suffix - 1]) suffix += 1;
  const originalChangeEnd = original.length - suffix;
  const changeInLength = value.length - original.length;
  const mappedOffset = (offset) => offset <= prefix ? offset
    : offset >= originalChangeEnd ? offset + changeInLength : prefix;

  let offset = 0;
  for (const [index, node] of nodes.entries()) {
    const nextOffset = offset + node.textContent.length;
    const start = mappedOffset(offset);
    const end = index === nodes.length - 1 ? value.length : mappedOffset(nextOffset);
    node.textContent = value.slice(start, end);
    offset = nextOffset;
  }
  element.replaceChildren(...restored.childNodes);
}

function fitReportTitle(root, enabled) {
  const title = root.dataset.dataAppContent === "report"
    && enabled && root.querySelector("[data-data-app-title][contenteditable='true']");
  if (!title) return () => {};
  const previousWidth = title.style.getPropertyValue("width");
  const previousPriority = title.style.getPropertyPriority("width");
  const fit = () => {
    title.style.removeProperty("width");
    const range = title.ownerDocument.createRange();
    range.selectNodeContents(title);
    title.style.setProperty("width", `${Math.ceil(range.getBoundingClientRect().width)}px`, "important");
  };
  fit();
  title.addEventListener("input", fit);
  window.addEventListener("resize", fit);
  return () => {
    title.removeEventListener("input", fit);
    window.removeEventListener("resize", fit);
    if (previousWidth) title.style.setProperty("width", previousWidth, previousPriority);
    else title.style.removeProperty("width");
  };
}

export function useInlineEditing(enabled, onCommit, savedEdits = {}) {
  const rootRef = useRef(null);
  const stateRef = useRef(null);
  stateRef.current = { enabled, onCommit, savedEdits };
  const synchronizeRef = useRef(null);
  const rememberedRef = useRef(null);

  useLayoutEffect(() => {
    const root = rootRef.current;
    if (!root) return undefined;
    const remembered = rememberedRef.current ??= new WeakMap();
    const entries = new Map();
    const observer = new MutationObserver(() => synchronize());

    function writeText(entry, value, restoreMarkup = false) {
      if (restoreMarkup || entry.element.textContent !== value) {
        restoreFormattedText(entry.element, value, entry.authoredMarkup);
      }
      entry.displayedText = value;
    }

    function track(element, id) {
      let entry = remembered.get(element);
      if (!entry) {
        entry = { element, authoredMarkup: element.cloneNode(true), displayedText: element.textContent,
          originalAriaLabel: element.getAttribute("aria-label"), focusValue: element.textContent,
          dirty: false, pendingCommit: false };
        entry.focus = () => { entry.focusValue = element.textContent; entry.dirty = false; };
        entry.input = () => { entry.dirty = true; };
        entry.commit = (preserveDraft = false) => {
          if (!stateRef.current.enabled && preserveDraft !== true) return;
          const next = element.textContent.trim();
          if (!next) {
            writeText(entry, entry.focusValue, true);
            return;
          }
          if (entry.dirty || next !== entry.focusValue) writeText(entry, next, true);
          if (next !== entry.focusValue) {
            // Keep an observer pass from restoring stale state before React accepts the commit.
            entry.pendingCommit = true;
            stateRef.current.onCommit?.(entry.id, next);
          }
          entry.focusValue = next;
          entry.dirty = false;
        };
        entry.keydown = (event) => {
          if (!stateRef.current.enabled) return;
          if (event.key === "Enter") { event.preventDefault(); element.blur(); }
          if (event.key === "Escape") {
            if (entry.dirty) writeText(entry, entry.focusValue, true);
            entry.dirty = false;
            element.blur();
          }
        };
        remembered.set(element, entry);
      }
      entry.id = id;
      if (!entries.has(element)) {
        entries.set(element, entry);
        element.addEventListener("focus", entry.focus);
        element.addEventListener("input", entry.input);
        element.addEventListener("blur", entry.commit);
        element.addEventListener("keydown", entry.keydown);
      }
      return entry;
    }

    function disable(entry) {
      const { element, originalAriaLabel } = entry;
      element.removeAttribute("contenteditable");
      element.removeAttribute("data-inline-editable");
      if (originalAriaLabel === null) element.removeAttribute("aria-label");
      else element.setAttribute("aria-label", originalAriaLabel);
    }

    function untrack(entry) {
      entry.element.removeEventListener("focus", entry.focus);
      entry.element.removeEventListener("input", entry.input);
      entry.element.removeEventListener("blur", entry.commit);
      entry.element.removeEventListener("keydown", entry.keydown);
      disable(entry);
      entries.delete(entry.element);
    }

    function synchronize(fromState = false) {
      // Reconcile the whole current tree once per batch, without observing our own writes.
      observer.disconnect();
      const { enabled, savedEdits } = stateRef.current;
      const activeElement = root.ownerDocument.activeElement;
      const elements = editableElements(root, activeElement);
      const currentElements = new Set(elements);
      for (const [element, entry] of entries) {
        if (!currentElements.has(element)) untrack(entry);
      }
      const scopeIndexes = new WeakMap();
      for (const element of elements) {
        const entry = track(element, narrativeId(root, element, scopeIndexes));
        const focused = enabled && element === activeElement;
        if (fromState) entry.pendingCommit = false;
        // Freeze the current text into the edit draft before disabling its field.
        if (!enabled && entry.dirty) entry.commit(true);
        if (element !== activeElement && !entry.pendingCommit && element.textContent !== entry.displayedText) {
          // React may replace unedited authored text while keeping the same element.
          entry.authoredMarkup = element.cloneNode(true);
        }
        const saved = savedEdits[entry.id];
        const value = typeof saved === "string" && saved.trim() ? saved : entry.authoredMarkup.textContent;
        if (!focused && !entry.pendingCommit) writeText(entry, value);
        if (enabled) {
          element.contentEditable = "true";
          element.dataset.inlineEditable = "true";
          element.setAttribute("aria-label", `Edit ${entry.originalAriaLabel || "Data app narrative"}`);
        } else {
          disable(entry);
        }
      }
      observer.observe(root, { childList: true, characterData: true, subtree: true });
    }

    synchronizeRef.current = synchronize;
    synchronize();
    return () => {
      observer.disconnect();
      for (const entry of entries.values()) untrack(entry);
      synchronizeRef.current = null;
    };
  }, []);

  useLayoutEffect(() => {
    synchronizeRef.current?.(true);
  }, [enabled, savedEdits]);

  useEffect(() => {
    const root = rootRef.current;
    if (root) return fitReportTitle(root, enabled);
  }, [enabled]);

  return rootRef;
}
