import React, { useLayoutEffect, useRef } from "react";

import { stickyFilterState } from "../chrome-layout.js";
import { formatDateRange } from "../date-range.js";
import { isTemporalField } from "../source-provenance.js";
import { DateRangePicker } from "./DateRangePicker.jsx";
import { Dropdown } from "./Dropdown.jsx";
import { useSectionFilterPlacement } from "./Section.jsx";

export { DataTable } from "./DataTable.jsx";
export { DateRangePicker, Dropdown };

export function Filters({ filters = [], queries, values, onChange, sticky = false,
  ariaLabel = "Data app filters", clearLabel = "Clear all", showClear = true, dateAllValue,
  sectionScope, children, trailingControls }) {
  const filterBarRef = useRef(null);
  const placement = useSectionFilterPlacement(sectionScope);

  useLayoutEffect(() => {
    if (!sticky) return undefined;
    const filterBar = filterBarRef.current;
    const dashboard = filterBar?.closest(".dashboard-root");
    const topbar = dashboard?.querySelector(".dashboard-topbar");
    if (!filterBar || !topbar) return undefined;
    const themeDrawer = dashboard.querySelector(".theme-drawer");
    let themeHeight = 0;
    const updatePageWidth = () => {
      const width = `${dashboard.getBoundingClientRect().width}px`;
      if (filterBar.style.getPropertyValue("--filter-bar-page-width") !== width) {
        filterBar.style.setProperty("--filter-bar-page-width", width);
      }
    };
    const updateStickyState = () => {
      const topbarBounds = topbar.getBoundingClientRect();
      const filterBounds = filterBar.getBoundingClientRect();
      const state = stickyFilterState({ scrollY: window.scrollY, top:filterBounds.top, bottom:filterBounds.bottom,
        headerBottom:topbarBounds.bottom + themeHeight });
      if (filterBar.hasAttribute("data-stuck") !== state.stuck) {
        filterBar.toggleAttribute("data-stuck", state.stuck);
      }
    };
    const updateLayout = () => {
      themeHeight = themeDrawer?.getBoundingClientRect().height ?? 0;
      const height = `${themeHeight}px`;
      if (filterBar.style.getPropertyValue("--filter-bar-theme-height") !== height) {
        filterBar.style.setProperty("--filter-bar-theme-height", height);
      }
      updatePageWidth();
      updateStickyState();
    };
    const sizes = typeof ResizeObserver === "function" ? new ResizeObserver(updateLayout) : null;
    sizes?.observe(dashboard);
    sizes?.observe(topbar);
    if (themeDrawer) sizes?.observe(themeDrawer);
    const observer = new MutationObserver(updateStickyState);
    observer.observe(topbar, {attributes:true,attributeFilter:["data-scroll-controls-hidden"]});
    updateLayout();
    window.addEventListener("scroll", updateStickyState, { passive: true });
    window.addEventListener("resize", updateLayout);
    return () => {
      window.removeEventListener("scroll", updateStickyState);
      window.removeEventListener("resize", updateLayout);
      sizes?.disconnect();
      observer.disconnect();
      filterBar.removeAttribute("data-stuck");
      filterBar.style.removeProperty("--filter-bar-page-width");
      filterBar.style.removeProperty("--filter-bar-theme-height");
    };
  }, [filters.length, sticky]);

  if ((!filters.length && !children && !trailingControls) || !placement.header) return null;
  const hasActiveFilters = filters.some(({ id, defaultValue, multiple }) => {
    const normalize = value => multiple ? JSON.stringify([...new Set(Array.isArray(value) ? value : value === "all" ? [] : [value])].sort()) : value;
    const fallback = defaultValue ?? "all";
    return normalize(values[id] ?? fallback) !== normalize(fallback);
  });

  return (
    <section ref={filterBarRef} className={sticky ? "filters filter-bar" : "filters"} aria-label={ariaLabel}>
      {children}
      {filters.map((filter) => {
        const scopedQueries = Array.isArray(filter.queryIds)
          ? filter.queryIds.map((queryId) => queries[queryId]).filter(Boolean)
          : Object.values(queries);
        const choices = [...new Set(scopedQueries.flatMap(({ rows }) => rows
          .map((row) => String(row[filter.field] ?? ""))
          .filter((value) => value && value.toLowerCase() !== "all")))];
        const temporal = isTemporalField(filter.field, filter.type ?? filter.valueType);
        if (temporal) {
          choices.sort((left, right) => {
            const leftDate = Date.parse(left);
            const rightDate = Date.parse(right);
            return Number.isFinite(leftDate) && Number.isFinite(rightDate)
              ? rightDate - leftDate : right.localeCompare(left, undefined, { numeric: true });
          });
        }

        const label = temporal && filter.mode === "through" ? "Date range"
          : temporal && /^as of$/i.test(filter.label.trim()) ? "Reporting date" : filter.label;
        const formatChoice = temporal ? (choice) => {
          if (choice === "all") return "All dates";
          if (typeof choice !== "string") return choice;
          const format = (value, year = false) => new Intl.DateTimeFormat(undefined,
            { month: "short", day: "numeric", ...(year ? { year: "numeric" } : {}), timeZone: "UTC" })
            .format(new Date(`${value}T00:00:00Z`));
          if (choice.includes("..")) return formatDateRange(choice);
          if (!/^\d{4}-\d{2}-\d{2}$/.test(choice)) return choice;
          if (filter.mode !== "through") return format(choice, true);
          const earliest = choices.at(-1);
          return earliest && earliest !== choice ? `${format(earliest)} – ${format(choice, true)}` : format(choice, true);
        } : undefined;
        if (temporal && filter.mode === "through" && choices.length) {
          return <DateRangePicker key={filter.id} label={label} value={values[filter.id]}
            choices={choices} formatChoice={formatChoice} allValue={dateAllValue}
            onChange={(choice) => onChange(filter.id, choice)} />;
        }
        if (filter.searchable || filter.multiple || filter.control === "typeahead") {
          const searchable = filter.searchable || filter.control === "typeahead";
          return <div className="filter-typeahead" key={filter.id}
            onClick={(event) => {
              if (!event.target.closest("button")) {
                event.currentTarget.querySelector(".typeahead-input")?.focus({ preventScroll: true });
              }
            }}>
            {filter.showLabel !== false && <span className="filter-label">{label}</span>}
            <Dropdown searchable={searchable} multiple={filter.multiple} label={label}
              value={values[filter.id] ?? filter.defaultValue ?? (filter.multiple ? [] : "all")}
              choices={["all", ...choices]} allLabel={filter.allLabel ?? "All"}
              placeholder={filter.placeholder} choiceLabels={filter.choiceLabels}
              onChange={(choice) => onChange(filter.id, choice)} />
          </div>;
        }
        return <Dropdown key={filter.id} label={label} value={values[filter.id]}
          choices={temporal && filter.defaultValue && filter.defaultValue !== "all" ? choices : ["all", ...choices]}
          onChange={(choice) => onChange(filter.id, choice)} showLabel
          allLabel={temporal ? "All dates" : filter.allLabel ?? "All"}
          choiceLabels={filter.choiceLabels} formatChoice={formatChoice} />;
      })}
      {trailingControls}
      {showClear && hasActiveFilters && <button type="button" className="clear-filters"
        onClick={() => filters.forEach(({ id, defaultValue }) =>
          onChange(id, defaultValue ?? "all"))}>{clearLabel}</button>}
    </section>
  );
}

export function InlineFilters({ label, field, rows = [], value = "all", onChange }) {
  const choices = [...new Set(rows.map((row) => row?.[field])
    .filter((entry) => typeof entry === "string" && entry && entry.toLowerCase() !== "all"))];
  if (choices.length < 2) return null;
  return <div className="inline-filters" role="group" aria-label={`${label} chart filter`}>
    <Dropdown label={label} value={value} choices={["all", ...choices]}
      onChange={(choice) => onChange?.(choice)} showLabel />
  </div>;
}
