import * as DropdownPrimitive from "@radix-ui/react-dropdown-menu";
import React, { useMemo, useState } from "react";

import { dateRangePresets, formatDateRange } from "../date-range.js";
import { Icon } from "./Icon.jsx";
import { useTouchReleaseTrigger } from "./touch-release-trigger.js";

export function DateRangePicker({ label = "Date range", value, choices: availableDates = [], formatChoice = formatDateRange, onChange, allValue, disabled = false }) {
  const choices = useMemo(() => [...new Set(availableDates.filter(date => typeof date === "string"
    && /^\d{4}-\d{2}-\d{2}$/.test(date) && Number.isFinite(Date.parse(date))
    && new Date(date).toISOString().slice(0, 10) === date))].sort().reverse(), [availableDates]);
  const [open, setOpen] = useState(false);
  const release = useTouchReleaseTrigger(setOpen);
  const [custom, setCustom] = useState(false);
  const earliest = choices.at(-1);
  const latest = choices[0];
  const allDates = allValue ?? `${earliest}..${latest}`;
  value ??= allDates;
  const today = new Date().toISOString().slice(0,10);
  const historical = Date.parse(today) - Date.parse(latest) > 2 * 86400000;
  const presets = dateRangePresets(earliest, latest, { historical });
  const preset = presets.find(preset => preset.value === value);
  const [selectedStart, selectedEnd] = typeof value === "string" && value.includes("..")
    ? value.split("..") : [earliest, choices.includes(value) ? value : latest];
  const [pendingStart, setPendingStart] = useState(null);
  const [previewEnd, setPreviewEnd] = useState(null);
  const [displayMonth, setDisplayMonth] = useState(() => selectedEnd?.slice(0, 7));
  const month = new Date(`${displayMonth ?? selectedEnd?.slice(0, 7)}-01T12:00:00Z`);
  const earliestMonth = earliest?.slice(0, 7);
  const latestMonth = latest?.slice(0, 7);
  const showPreviousMonth = displayMonth > earliestMonth;
  const fullDate = (date) => new Intl.DateTimeFormat(undefined,
    { weekday: "long", month: "long", day: "numeric", year: "numeric", timeZone: "UTC" })
    .format(new Date(`${date}T12:00:00Z`));
  function changeMonth(offset) {
    const next = new Date(month);
    next.setUTCMonth(next.getUTCMonth() + offset);
    setDisplayMonth(next.toISOString().slice(0, 7));
  }
  function applyRange(start, end, close = false) {
    if (!start || !end) return;
    const rangeStart = start > end ? end : start;
    const rangeEnd = start > end ? start : end;
    onChange(rangeStart === earliest && rangeEnd === latest ? allDates : `${rangeStart}..${rangeEnd}`);
    setPendingStart(null);
    if (close) setOpen(false);
  }
  function chooseNativeRange(event) {
    const choice = event.currentTarget.value;
    event.currentTarget.value = ""; // Keep the same preset or Custom available on the next open.
    if (choice === "custom") {
      setDisplayMonth(selectedEnd?.slice(0, 7));
      setPendingStart(null);
      setPreviewEnd(null);
      setCustom(true);
      setOpen(true);
    } else if (choice === "all") {
      onChange(allDates);
      setOpen(false);
    } else {
      const selection = presets.find(preset => preset.value === choice);
      if (selection) applyRange(selection.start, selection.end, true);
    }
  }
  function renderMonth(offset) {
    const calendarMonth = new Date(month);
    calendarMonth.setUTCMonth(calendarMonth.getUTCMonth() + offset);
    const monthValue = calendarMonth.toISOString().slice(0, 7);
    const heading = new Intl.DateTimeFormat(undefined,
      { month: "long", year: "numeric", timeZone: "UTC" }).format(calendarMonth);
    const firstWeekday = calendarMonth.getUTCDay();
    const daysInMonth = new Date(Date.UTC(calendarMonth.getUTCFullYear(), calendarMonth.getUTCMonth() + 1, 0)).getUTCDate();

    return <section key={monthValue} className="date-calendar-month" data-current-month={offset === 0}>
      <header className="date-calendar-header">
        {offset === -1 ? <button type="button" className="date-calendar-nav" aria-label="Previous month"
          disabled={monthValue <= earliestMonth} onClick={() => changeMonth(-1)}>
          <Icon name="chevronLeft" size={16} />
        </button> : <button type="button" className="date-calendar-nav date-calendar-mobile-nav"
          aria-label="Previous month" disabled={displayMonth <= earliestMonth} onClick={() => changeMonth(-1)}>
          <Icon name="chevronLeft" size={16} />
        </button>}
        <strong>{heading}</strong>
        {offset === 0 ? <button type="button" className="date-calendar-nav" aria-label="Next month"
          disabled={displayMonth >= latestMonth} onClick={() => changeMonth(1)}>
          <Icon name="chevronRight" size={16} />
        </button> : <span className="date-calendar-nav-placeholder" aria-hidden="true" />}
      </header>
      <div className="date-calendar-grid" role="group" aria-label={heading}>
        {["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"].map((day) =>
          <span key={day} className="date-calendar-weekday" aria-hidden="true">{day}</span>)}
        {Array.from({ length: firstWeekday }, (_, index) =>
          <span key={`empty-${index}`} className="date-calendar-empty" aria-hidden="true" />)}
        {Array.from({ length: daysInMonth }, (_, index) => {
          const date = `${monthValue}-${String(index + 1).padStart(2, "0")}`;
          const enabled = date >= earliest && date <= latest;
          const activeStart = pendingStart ? [pendingStart, previewEnd ?? pendingStart].sort()[0] : selectedStart;
          const activeEnd = pendingStart ? [pendingStart, previewEnd ?? pendingStart].sort()[1] : selectedEnd;
          return <button type="button" key={date} className="date-calendar-day"
            aria-label={fullDate(date)} aria-pressed={date === activeStart || date === activeEnd} disabled={!enabled}
            data-in-range={date >= activeStart && date <= activeEnd}
            data-range-start={date === activeStart} data-range-end={date === activeEnd}
            onPointerEnter={() => { if (pendingStart && enabled) setPreviewEnd(date); }}
            onClick={() => {
              if (!pendingStart) { setPendingStart(date); setPreviewEnd(null); return; }
              applyRange(pendingStart, date, true);
            }}>{index + 1}</button>;
        })}
      </div>
    </section>;
  }

  if (!choices.length) return <button type="button" className="filter-trigger" disabled aria-label={label}><span className="filter-label">{label}</span>No dates available</button>;
  return <DropdownPrimitive.Root open={open && !disabled} onOpenChange={(next) => {
    if (next) { setDisplayMonth(selectedEnd?.slice(0, 7)); setPendingStart(null); setPreviewEnd(null); setCustom(false); }
    setOpen(next);
  }} modal={false}>
    <span className="date-range-host">
    <DropdownPrimitive.Trigger className="filter-trigger date-range-trigger" aria-label={label} disabled={disabled} {...release}>
      <span className="filter-label">{label}</span>
      <span title={formatChoice(value)}>{preset?.label ?? formatChoice(value)}</span><Icon name="chevronDown" className="chevron" />
    </DropdownPrimitive.Trigger>
    <select className="date-range-native-select" aria-label={label} disabled={disabled} defaultValue=""
      onChange={chooseNativeRange}
      onPointerDown={event => { event.currentTarget.dataset.pointerFocus = "true"; }}
      onBlur={event => { delete event.currentTarget.dataset.pointerFocus; }}
      onKeyDown={event => { delete event.currentTarget.dataset.pointerFocus; if (event.key === "Escape") event.stopPropagation(); }}>
      <option value="" disabled>Current: {preset?.label ?? formatChoice(value)}</option>
      <optgroup label="Date ranges">
        {presets.map(preset => <option key={preset.label} value={preset.value}>{preset.label}</option>)}
        <option value="all">All available dates</option>
        <option value="custom">Custom range…</option>
      </optgroup>
    </select>
    </span>
    <DropdownPrimitive.Portal>
      <DropdownPrimitive.Content className={`popover date-range-calendar${custom ? "" : " date-range-presets"}`} align="start"
        data-single-month={custom && !showPreviousMonth || undefined}
        sideOffset={7} collisionPadding={12} aria-label="Choose reporting date range">
        {!custom ? <div className="date-preset-list">
          <span className="date-calendar-caption">Data through {new Intl.DateTimeFormat(undefined, {month:"short",day:"numeric",year:"numeric",timeZone:"UTC"}).format(new Date(`${latest}T00:00:00Z`))}</span>
          {presets.map(preset => <DropdownPrimitive.Item asChild key={preset.label} onSelect={() => applyRange(preset.start,preset.end,true)}><button type="button" aria-pressed={preset.value === value}>{preset.label}<span>{preset.value === value ? "✓" : ""}</span></button></DropdownPrimitive.Item>)}
          <DropdownPrimitive.Item asChild onSelect={() => { onChange(allDates); setOpen(false); }}><button type="button">All available dates</button></DropdownPrimitive.Item>
          <DropdownPrimitive.Item asChild onSelect={event => { event.preventDefault(); setCustom(true); }}><button type="button">Custom range…<Icon name="chevronRight" size={14}/></button></DropdownPrimitive.Item>
        </div> : <><div className="date-calendar-mobile-heading"><strong>Custom range</strong><button type="button" aria-label="Close custom date range" onClick={() => { setOpen(false); setPendingStart(null); setPreviewEnd(null); }}><Icon name="close" size={18} /></button></div><button type="button" className="date-calendar-back" onClick={() => { setCustom(false); setPendingStart(null); setPreviewEnd(null); }}><Icon name="chevronLeft" size={14} />Date ranges</button>
        <div className="date-calendar-months">{showPreviousMonth && renderMonth(-1)}{renderMonth(0)}</div>
        <span className="visually-hidden" aria-live="polite">{pendingStart ? `${formatDateRange(pendingStart)} · Select an end date` : "Select a start date"}</span></>}
      </DropdownPrimitive.Content>
    </DropdownPrimitive.Portal>
  </DropdownPrimitive.Root>;
}
