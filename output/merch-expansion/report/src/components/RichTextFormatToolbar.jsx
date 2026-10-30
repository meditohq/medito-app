import { $isLinkNode, TOGGLE_LINK_COMMAND } from "@lexical/link";
import {
  $isListItemNode, $isListNode, INSERT_CHECK_LIST_COMMAND, INSERT_ORDERED_LIST_COMMAND, INSERT_UNORDERED_LIST_COMMAND,
} from "@lexical/list";
import { useLexicalComposerContext } from "@lexical/react/LexicalComposerContext";
import { $createHeadingNode, $isHeadingNode } from "@lexical/rich-text";
import {
  $createParagraphNode, $findMatchingParent, $getSelection, $isElementNode, $isRangeSelection, $isRootOrShadowRoot, $setSelection,
  COMMAND_PRIORITY_LOW, FORMAT_TEXT_COMMAND, SELECTION_CHANGE_COMMAND,
} from "lexical";
import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";

import { Icon } from "./Icon.jsx";

const blockStyles = [
  { value: "h2", label: "Heading", shortcut: "1", className: "data-app-format-heading-1" },
  { value: "paragraph", label: "Text", shortcut: "0" },
  { value: "number", label: "Numbered list", shortcut: "2" },
  { value: "bullet", label: "Bulleted list", shortcut: "3" },
  { value: "check", label: "Checklist", shortcut: "4" },
];

function selectedBlock(selection) {
  const node = selection.anchor.getNode();
  return node.getTopLevelElementOrThrow();
}

function liftOrphanedListPrefix(list) {
  if (!$isListNode(list)) return;
  // Splitting a nested item into a heading may leave a list-only wrapper
  // without its preceding parent item. Lift that remainder so Markdown does
  // not serialize it as an indented code block after the new heading.
  let first = list.getFirstChild();
  while ($isListItemNode(first) && first.getChildrenSize() > 0 && first.getChildren().every($isListNode)) {
    for (const nested of first.getChildren()) {
      list.insertBefore(nested);
      liftOrphanedListPrefix(nested);
    }
    first.remove();
    first = list.getFirstChild();
  }
  if (list.isAttached() && list.getChildrenSize() === 0) list.remove();
}

function currentBlockStyle(block) {
  if ($isHeadingNode(block)) return block.getTag();
  if ($isListNode(block)) return block.getListType();
  return "paragraph";
}

function selectedLink(selection) {
  for (const node of selection.getNodes()) {
    if ($isLinkNode(node)) return node.getURL();
    const parent = node.getParent();
    if ($isLinkNode(parent)) return parent.getURL();
  }
  return "";
}

function safeLink(value) {
  try {
    const url = new URL(value.trim());
    return ["http:", "https:"].includes(url.protocol) ? url.href : null;
  } catch {
    return null;
  }
}

function toolbarPosition(rect) {
  const gutter = 12;
  const estimatedWidth = Math.min(260, window.innerWidth - gutter * 2);
  return {
    left: Math.max(gutter, Math.min(rect.left + rect.width / 2 - estimatedWidth / 2,
      window.innerWidth - estimatedWidth - gutter)),
    top: Math.max(gutter, Math.min(
      rect.top >= 52 ? rect.top - 46 : rect.bottom + 8,
      window.innerHeight - 48,
    )),
  };
}

function preservePointer(event) {
  event.preventDefault();
}

export function RichTextFormatToolbar() {
  const [editor] = useLexicalComposerContext();
  const [selectionState, setSelectionState] = useState(null);
  const [panel, setPanel] = useState(null);
  const [styleMenuPosition, setStyleMenuPosition] = useState({});
  const [linkValue, setLinkValue] = useState("");
  const panelRef = useRef(null);
  const styleTriggerRef = useRef(null);
  const styleMenuRef = useRef(null);
  const savedSelection = useRef(null);
  const frame = useRef(null);

  const inspectSelection = useCallback(() => {
    if (panelRef.current) return;
    editor.getEditorState().read(() => {
      const selection = $getSelection();
      const nativeSelection = window.getSelection();
      const root = editor.getRootElement();
      if (!$isRangeSelection(selection) || selection.isCollapsed()
        || !nativeSelection?.rangeCount || !root?.contains(nativeSelection.anchorNode)
        || !root.contains(nativeSelection.focusNode)) {
        setSelectionState(null);
        return;
      }
      const range = nativeSelection.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      if (!rect.width && !rect.height) {
        setSelectionState(null);
        return;
      }
      const block = selectedBlock(selection);
      savedSelection.current = selection.clone();
      setSelectionState({
        position: toolbarPosition(rect),
        bold: selection.hasFormat("bold"),
        italic: selection.hasFormat("italic"),
        block: currentBlockStyle(block),
        link: selectedLink(selection),
      });
    });
  }, [editor]);

  useEffect(() => {
    function scheduleInspection() {
      cancelAnimationFrame(frame.current);
      frame.current = requestAnimationFrame(inspectSelection);
    }
    const unregisterUpdate = editor.registerUpdateListener(scheduleInspection);
    const unregisterSelection = editor.registerCommand(SELECTION_CHANGE_COMMAND, () => {
      scheduleInspection();
      return false;
    }, COMMAND_PRIORITY_LOW);
    document.addEventListener("selectionchange", scheduleInspection);
    window.addEventListener("resize", scheduleInspection);
    window.addEventListener("scroll", scheduleInspection, true);
    return () => {
      cancelAnimationFrame(frame.current);
      unregisterUpdate();
      unregisterSelection();
      document.removeEventListener("selectionchange", scheduleInspection);
      window.removeEventListener("resize", scheduleInspection);
      window.removeEventListener("scroll", scheduleInspection, true);
    };
  }, [editor, inspectSelection]);

  useLayoutEffect(() => {
    if (panel !== "style") return;
    function positionMenu() {
      const menu = styleMenuRef.current;
      const trigger = styleTriggerRef.current;
      if (!menu || !trigger) return;
      const bounds = menu.getBoundingClientRect();
      const anchor = trigger.getBoundingClientRect();
      const toolbar = trigger.parentElement.getBoundingClientRect();
      const below = anchor.bottom + 8;
      const top = below + bounds.height <= window.innerHeight - 12
        ? below : anchor.top - bounds.height - 8;
      setStyleMenuPosition({
        left: Math.max(12, Math.min(anchor.left - 8, window.innerWidth - bounds.width - 12)) - toolbar.left,
        top: Math.max(12, Math.min(top, window.innerHeight - bounds.height - 12)) - toolbar.top,
      });
    }
    positionMenu();
    window.addEventListener("resize", positionMenu);
    return () => window.removeEventListener("resize", positionMenu);
  }, [panel, selectionState?.position.left, selectionState?.position.top]);

  function closePanel() {
    panelRef.current = null;
    setPanel(null);
  }

  function openPanel(nextPanel) {
    panelRef.current = nextPanel;
    setPanel(nextPanel);
    if (nextPanel === "link") setLinkValue(selectionState.link || "");
  }

  function restoreSelection() {
    if (savedSelection.current) $setSelection(savedSelection.current.clone());
  }

  function applyFormat(format) {
    editor.dispatchCommand(FORMAT_TEXT_COMMAND, format);
    closePanel();
  }

  function applyBlockStyle(style) {
    if (["bullet", "number", "check"].includes(style)) {
      editor.update(restoreSelection);
      const command = style === "bullet" ? INSERT_UNORDERED_LIST_COMMAND
        : style === "number" ? INSERT_ORDERED_LIST_COMMAND : INSERT_CHECK_LIST_COMMAND;
      editor.dispatchCommand(command, undefined);
    } else {
      editor.update(() => {
        restoreSelection();
        const selection = $getSelection();
        if (!$isRangeSelection(selection)) return;
        // Replace selected blocks individually: ListItemNode.replace splits its
        // list, preserving the list structure of unselected neighbors.
        const blocks = new Set(selection.getNodes().map((node) => $findMatchingParent(node, (parent) =>
          $isElementNode(parent) && !parent.isInline() && !$isListNode(parent) && !$isRootOrShadowRoot(parent)
          && (!$isListItemNode(parent) || parent.getChildren().some((child) => !$isListNode(child))))).filter(Boolean));
        for (const current of blocks) {
          if (current.getType() === (style === "paragraph" ? "paragraph" : "heading")
            && currentBlockStyle(current) === style) continue;
          const replacement = style === "paragraph" ? $createParagraphNode() : $createHeadingNode(style);
          current.replace(replacement, true);
          liftOrphanedListPrefix(replacement.getNextSibling());
        }
      });
    }
    closePanel();
    requestAnimationFrame(inspectSelection);
  }

  function applyLink(value) {
    const url = value === null ? null : safeLink(value);
    if (value !== null && !url) return;
    editor.update(() => {
      restoreSelection();
      editor.dispatchCommand(TOGGLE_LINK_COMMAND, url);
    });
    closePanel();
    editor.focus();
  }

  useEffect(() => {
    if (!selectionState) return undefined;
    function onKeyDown(event) {
      if ((event.metaKey || event.ctrlKey) && event.altKey) {
        const option = blockStyles.find(({ shortcut }) => shortcut === event.key);
        if (option) {
          event.preventDefault();
          applyBlockStyle(option.value);
        }
        return;
      }
      if (event.key !== "Escape") return;
      closePanel();
      setSelectionState(null);
    }
    function onPointerDown(event) {
      if (!event.target.closest("[data-rich-format-toolbar]")) closePanel();
    }
    document.addEventListener("keydown", onKeyDown);
    document.addEventListener("pointerdown", onPointerDown);
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.removeEventListener("pointerdown", onPointerDown);
    };
  }, [selectionState]);

  if (!selectionState) return null;

  return createPortal(<div className="data-app-format-toolbar" data-rich-format-toolbar
    role="toolbar" aria-label="Format selected text" style={selectionState.position}>
    {panel === "link" ? <form className="data-app-format-link"
      onSubmit={(event) => { event.preventDefault(); applyLink(linkValue); }}>
      <Icon name="link" />
      <input aria-label="Link URL" placeholder="Type or paste a link" value={linkValue} autoFocus
        onChange={(event) => setLinkValue(event.target.value)} />
      <button type="submit" disabled={!safeLink(linkValue)} aria-label="Apply link"><Icon name="check" /></button>
      {selectionState.link && <button type="button" aria-label="Remove link"
        onClick={() => applyLink(null)}><Icon name="cross" /></button>}
      <button type="button" aria-label="Cancel link entry" onMouseDown={preservePointer}
        onClick={() => {
          editor.update(() => restoreSelection());
          closePanel();
        }}><Icon name="cross" /></button>
    </form> : <>
    <button type="button" className="data-app-format-button" aria-label={selectionState.link ? "Edit link" : "Add link"}
      aria-pressed={Boolean(selectionState.link)} onMouseDown={preservePointer}
      onClick={() => openPanel("link")}><Icon name="link" /></button>
    <button type="button" className="data-app-format-button" aria-label="Bold"
      aria-pressed={selectionState.bold} onMouseDown={preservePointer}
      onClick={() => applyFormat("bold")}><Icon name="bold" /></button>
    <button type="button" className="data-app-format-button" aria-label="Italic"
      aria-pressed={selectionState.italic} onMouseDown={preservePointer}
      onClick={() => applyFormat("italic")}><Icon name="italic" /></button>
    <button ref={styleTriggerRef} type="button" className="data-app-format-style" aria-label="Text styles"
      aria-haspopup="menu" aria-expanded={panel === "style"} onMouseDown={preservePointer}
      onClick={() => panel === "style" ? closePanel() : openPanel("style")}>
      <span>{blockStyles.find((option) => option.value === selectionState.block)?.label || "Text"}</span>
      <Icon name="chevronDown" size={14} />
    </button>
    {panel === "style" && <div ref={styleMenuRef} className="data-app-format-menu" role="menu" aria-label="Text styles"
      style={{ ...styleMenuPosition, maxHeight: "calc(100vh - 24px)", overflowY: "auto" }}>
      {blockStyles.map((option) => <button key={option.value} type="button" role="menuitemradio"
        aria-checked={selectionState.block === option.value}
        data-selected={selectionState.block === option.value ? "true" : undefined}
        onMouseDown={preservePointer} onClick={() => applyBlockStyle(option.value)}>
        <span className={option.className}>{option.label}</span>
        <span className="data-app-format-shortcut" aria-hidden="true">⌥⌘{option.shortcut}</span>
      </button>)}
    </div>}
    </>}
  </div>, document.body);
}
