import React, { useEffect, useId, useMemo, useRef, useState } from "react";

import { Icon } from "./Icon.jsx";
import { Select as MenuSelect } from "./ui.jsx";
import { dropdownModel } from "./dropdown-model.js";

export function Dropdown({ searchable = false, choiceLabels = {}, formatChoice, ...props }) {
  const format = formatChoice ?? ((choice) => choiceLabels?.[choice]);
  if (searchable) return <SearchableDropdown {...props} formatChoice={format} />;
  return <MenuSelect {...props} formatChoice={format} />;
}

function SearchableDropdown({ label, value = "all", choices = [], onChange, allLabel = "All", placeholder,
  multiple = false, showLabel = false, formatChoice }) {
  const id = useId();
  const rootRef = useRef(null);
  const inputRef = useRef(null);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [queryDirty, setQueryDirty] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const { display, displayedValue, isSelected, select } = useMemo(
    () => dropdownModel({ value, multiple, allLabel, formatChoice }),
    [value, multiple, allLabel, formatChoice],
  );
  const filteredChoices = useMemo(() => {
    const search = queryDirty ? query.trim().toLocaleLowerCase() : "";
    return search ? choices.filter((choice) => String(display(choice)).toLocaleLowerCase().includes(search)) : choices;
  }, [choices, query, queryDirty, display]);

  useEffect(() => {
    if (!open) return undefined;
    const close = (event) => {
      if (!rootRef.current?.contains(event.target)) {
        setOpen(false);
        setQuery("");
        setQueryDirty(false);
      }
    };
    document.addEventListener("pointerdown", close);
    return () => document.removeEventListener("pointerdown", close);
  }, [open]);

  useEffect(() => {
    setActiveIndex((index) => Math.min(index, Math.max(0, filteredChoices.length - 1)));
  }, [filteredChoices.length]);

  function choose(choice) {
    onChange?.(select(choice));
    if (!multiple) setOpen(false);
    setQuery("");
    setQueryDirty(false);
    inputRef.current?.focus();
  }

  function openMenu() {
    setOpen(true);
    setQuery("");
    setQueryDirty(false);
    const selectedIndex = choices.findIndex(isSelected);
    setActiveIndex(Math.max(0, selectedIndex));
  }

  return <div className="typeahead" ref={rootRef}>
    <div className="typeahead-control filter-trigger" data-state={open ? "open" : "closed"}
      onClick={(event) => {
        if (!event.target.closest("button")) inputRef.current?.focus({ preventScroll: true });
      }}>
      {showLabel && <span className="filter-label">{label}</span>}
      <input ref={inputRef} className="typeahead-input" role="combobox" aria-label={label}
        aria-autocomplete="list" aria-expanded={open} aria-controls={`${id}-listbox`}
        aria-activedescendant={open && filteredChoices[activeIndex] != null
          ? `${id}-option-${activeIndex}` : undefined}
        value={open && (multiple || queryDirty) ? query : displayedValue}
        placeholder={placeholder ?? (showLabel ? "Search" : `Search ${label.toLocaleLowerCase()}`)}
        onFocus={() => {
          if (!open) openMenu();
        }}
        onChange={(event) => {
          setQuery(event.target.value);
          setQueryDirty(true);
          setOpen(true);
          setActiveIndex(0);
        }}
        onKeyDown={(event) => {
          if (event.key === "ArrowDown") {
            event.preventDefault();
            if (!open) openMenu();
            else setActiveIndex((index) => Math.min(filteredChoices.length - 1, index + 1));
          } else if (event.key === "ArrowUp") {
            event.preventDefault();
            setActiveIndex((index) => Math.max(0, index - 1));
          } else if (event.key === "Enter" && open && filteredChoices[activeIndex] != null) {
            event.preventDefault();
            choose(filteredChoices[activeIndex]);
          } else if (event.key === "Escape") {
            setOpen(false);
            setQuery("");
            setQueryDirty(false);
          }
        }} />
      <button type="button" className="typeahead-toggle"
        aria-label={`${open ? "Close" : "Open"} ${label}`}
        tabIndex={-1} onClick={() => {
          if (open) { setOpen(false); setQuery(""); setQueryDirty(false); }
          else { openMenu(); inputRef.current?.focus(); }
        }}>
        <Icon name="chevronDown" className="chevron" />
      </button>
    </div>
    {open && <div id={`${id}-listbox`} className="popover typeahead-options" role="listbox" aria-label={label}
      aria-multiselectable={multiple || undefined}>
      {filteredChoices.map((choice, index) => <button type="button" role="option"
        id={`${id}-option-${index}`} className="menu-item" key={choice || "none"}
        aria-selected={isSelected(choice)} data-highlighted={index === activeIndex || undefined}
        onPointerMove={() => setActiveIndex(index)} onMouseDown={(event) => event.preventDefault()}
        onClick={() => choose(choice)}>
        <span className="menu-item-label">{display(choice)}</span>
        {isSelected(choice) && <Icon name="check" className="menu-check" />}
      </button>)}
      {!filteredChoices.length && <span className="typeahead-empty">No matches</span>}
    </div>}
  </div>;
}
