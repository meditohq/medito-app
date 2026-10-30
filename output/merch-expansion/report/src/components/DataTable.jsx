import React, { useEffect, useId, useMemo, useRef, useState } from "react";

import { deltaDirection, displayValue, label as chartLabel } from "../charting/chart-theme.js";
import { compareTableValues, distributionBuckets, distributionPercentiles, numericValue, resolveDeltaTone, statusTone } from "../charting/table-data.js";
import { TableSparkline } from "../charting/TableSparkline.jsx";
import { Icon } from "./Icon.jsx";
import { Tooltip } from "./ui.jsx";

function columnLabel(field) {
  return chartLabel(field).split(" ").map((word, index) =>
    index && !/^[A-Z\d]+$/u.test(word) ? word.toLowerCase() : word).join(" ");
}

function numericColumn(rows, column) {
  return rows.some((row) => typeof row[column] === "number"
    || /^[+-]?(?:[$€£])?\d[\d,.]*(?:\s?[KMBT])?%?$/iu.test(String(row[column] ?? "").trim()));
}

function yearColumn(column) {
  const field = String(column).replace(/([a-z\d])([A-Z])/gu, "$1_$2");
  return /^(?:(?:calendar|fiscal|reporting|academic)[ _-])?year$/iu.test(field);
}

function numericPresentation(rows, column, definition) {
  return numericColumn(rows, column)
    && !yearColumn(column)
    && !["sparkline", "bar", "status"].includes(definition?.presentation);
}

function TableVisualTooltip({ label, value, values, formatValue = displayValue, children }) {
  const id = useId();
  const [hover, setHover] = useState(null);
  const ratioHistory = Array.isArray(values) && values.length > 0
    && values.every((point) => Number.isFinite(point) && point >= 0 && point <= 1)
    && values.some((point) => !Number.isInteger(point));
  const reviewedLabel = ratioHistory ? label.replace(/\s+trend$/iu, " rate") : label;
  const reviewedValue = (point) => ratioHistory
    ? new Intl.NumberFormat(undefined, { style: "percent", maximumFractionDigits: 1 }).format(point)
    : formatValue(point);
  function show(event) {
    const bounds = event.currentTarget.getBoundingClientRect();
    const pointerX = typeof event.clientX === "number" && event.clientX > 0
      ? event.clientX : bounds.right;
    const fraction = Math.max(0, Math.min(1, (pointerX - bounds.left) / Math.max(1, bounds.width)));
    const point = Array.isArray(values) && values.length
      ? Math.min(values.length - 1, Math.floor(fraction * values.length)) : null;
    setHover({
      left: Math.max(112, Math.min(globalThis.innerWidth - 112, pointerX)),
      top: Math.max(48, bounds.top - 8),
      point,
    });
  }
  return <span className="table-visual-trigger" tabIndex={0} aria-describedby={hover ? id : undefined}
    onPointerEnter={show} onPointerMove={show} onPointerLeave={() => setHover(null)}
    onFocus={show} onBlur={() => setHover(null)}>
    {children}
    {hover && <Tooltip portal visible id={id} className="table-visual-tooltip"
      style={{ left: hover.left, top: hover.top }}>
      <span className="table-visual-tooltip-label">{reviewedLabel}</span>
      <strong>{hover.point === null ? value : reviewedValue(values[hover.point])}</strong>
    </Tooltip>}
  </span>;
}

export function DataTable({ rows, searchable = true, compactColumns = [], compactNumbers = true,
  signedDeltas = false, columns: columnDefinitions = [], rowKey, selectedRowKey, onRowSelect, rowActionLabel, toolbarControls,
  caption, label, pageSize = 8, paginationStyle = "default" }) {
  const [search, setSearch] = useState("");
  const [order, setOrder] = useState({ field: "", descending: false });
  const [page, setPage] = useState(0);
  const [overflow, setOverflow] = useState({ start: false, end: false });
  const tableRef = useRef(null);
  const accessibleName = caption ?? label ?? "Reviewed data";
  const columns = columnDefinitions.length
    ? columnDefinitions.map(({ field, key }) => field ?? key)
    : [...new Set(rows.flatMap(Object.keys))];
  const definitions = new Map(columnDefinitions.map((column) => [column.field ?? column.key, column]));
  const distributions = useMemo(() => new Map(columnDefinitions
    .filter(({ presentation }) => presentation === "bar")
    .map(({ field, key, max }) => [field ?? key, {
      buckets: distributionBuckets(rows, field ?? key, max),
      percentiles: distributionPercentiles(rows, field ?? key),
    }])),
  [rows, columnDefinitions]);
  const compactFields = new Set(compactColumns);
  const formatCell = (value, column) => {
    if (yearColumn(column) && value !== null && value !== undefined) return String(value);
    const formatted = typeof value === "number" && Number.isFinite(value)
      && !compactNumbers && !compactFields.has(column)
      ? new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 }).format(value)
      : displayValue(value);
    return signedDeltas && deltaDirection(column, value) === "positive" && !String(formatted).startsWith("+")
      ? `+${formatted}` : formatted;
  };
  const visible = rows.filter((row) => Object.values(row).some((value) =>
    String(value).toLowerCase().includes(search.toLowerCase()))).sort((left, right) => {
    if (!order.field) return 0;
    return compareTableValues(left[order.field], right[order.field], order.descending);
  });
  const pages = Math.max(1, Math.ceil(visible.length / pageSize));
  const currentPage = Math.min(page, pages - 1);

  useEffect(() => {
    const table = tableRef.current;
    if (!table) return undefined;
    const update = () => {
      const next = {
        start: table.scrollLeft > 1,
        end: table.scrollLeft + table.clientWidth < table.scrollWidth - 1,
      };
      setOverflow((current) => current.start === next.start && current.end === next.end ? current : next);
    };
    update();
    table.addEventListener("scroll", update, { passive: true });
    const observer = typeof ResizeObserver === "function" ? new ResizeObserver(update) : null;
    observer?.observe(table);
    return () => { table.removeEventListener("scroll", update); observer?.disconnect(); };
  }, [rows.length, columns.length, search, order.field, order.descending, currentPage]);

  return (
    <>
      {search && <div className="table-print-search" hidden>Search: {search}</div>}
      {(searchable || toolbarControls) && (
        <div className="toolbar table-toolbar">
          {searchable && <label className="search-field"><Icon name="search" />
            <input className="search" aria-label="Search data" placeholder="Search data" value={search}
              onChange={(event) => { setSearch(event.target.value); setPage(0); }} />
          </label>}
          {toolbarControls && <div className="table-toolbar-controls">{toolbarControls}</div>}
        </div>
      )}
      <div className="table-wrap" ref={tableRef} role="region" aria-label={`${accessibleName} table`}
        tabIndex={overflow.start || overflow.end ? 0 : undefined}
        data-overflow-start={overflow.start} data-overflow-end={overflow.end}>
        <table className="table">
          <caption className="visually-hidden">{accessibleName}</caption>
          <thead><tr>{columns.map((column) => (
            <th key={column} scope="col" aria-sort={order.field === column ? order.descending ? "descending" : "ascending" : "none"} className={numericPresentation(rows, column, definitions.get(column))
              ? "numeric" : undefined}><button type="button" onClick={() => setOrder({
              field: column, descending: order.field === column && !order.descending,
            })}>{definitions.get(column)?.label ?? columnLabel(column)}{order.field === column ? (order.descending ? " ↓" : " ↑") : ""}</button></th>
          ))}</tr></thead>
          <tbody>{visible.slice(currentPage * pageSize, currentPage * pageSize + pageSize).map((row, index) => (
            <tr key={rowKey ? row[rowKey] : index} data-row-action={onRowSelect ? "true" : undefined} data-selected={rowKey && row[rowKey] === selectedRowKey || undefined}
              onClick={onRowSelect ? event => {
                if (event.target.closest("button, a, input, select, textarea, [role=button]")) return;
                const selection = globalThis.getSelection?.();
                if (selection?.toString() && (event.currentTarget.contains(selection.anchorNode) || event.currentTarget.contains(selection.focusNode))) return;
                onRowSelect(row);
              } : undefined}>{columns.map((column, columnIndex) => {
              const definition = definitions.get(column);
              const value = row[column];
              const presentation = definition?.presentation;
              const distribution = distributions.get(column);
              const percentile = distribution?.percentiles.get(value);
              const content = typeof definition?.renderCell === "function" ? definition.renderCell(value, row)
                  : presentation === "sparkline" ? <TableVisualTooltip
                  label={definition.label ?? columnLabel(column)} values={value}
                  value="No reviewed history" formatValue={(point) => formatCell(point, column)}>
                  <TableSparkline values={value} label={definition.label ?? columnLabel(column)} />
                </TableVisualTooltip>
                  : presentation === "bar" ? <TableVisualTooltip
                    label={definition.label ?? columnLabel(column)}
                    value={percentile === undefined ? "No reviewed value"
                      : `${formatCell(value, column)} · ${percentile}th percentile`}>
                    <span className="table-data-bar">
                    <span className="table-data-bar-track" aria-hidden="true">
                      {(distribution?.buckets ?? []).map((height, index) =>
                        <span key={index} className="table-data-bar-segment"
                          style={{ "--distribution-height": `${height}%` }} />)}
                      {percentile !== undefined && <span className="table-distribution-marker"
                        style={{ left: `${Math.max(0, Math.min(100, numericValue(value)
                          / (definition.max ?? 100) * 100))}%` }} />}
                    </span>
                  </span></TableVisualTooltip> : presentation === "status" ? <span className="table-status"
                    data-status={statusTone(value)}>
                    {String(value ?? "—")}</span>
                  : presentation === "identity" ? <span className="table-identity"><strong>{String(value ?? "—")}</strong>
                    {definition.secondaryField && <span>{String(row[definition.secondaryField] ?? "")}</span>}</span>
                  : presentation === "percent" && Number.isFinite(value)
                    ? new Intl.NumberFormat(undefined, { style: "percent", maximumFractionDigits: 0 }).format(value)
                    : formatCell(row[column], column);
              return <td key={column}
                className={[numericPresentation(rows, column, definition) ? "numeric" : "",
                  presentation ? `table-cell-${presentation}` : ""]
                  .filter(Boolean).join(" ") || undefined}
                data-delta={resolveDeltaTone(definition?.deltaTone, value, row,
                  signedDeltas ? deltaDirection(column, value) || undefined : undefined)}>
                {onRowSelect && columnIndex === 0 ? <div className="table-row-action-cell">
                  {content}<button type="button" className="table-row-action"
                    aria-label={rowActionLabel?.(row) ?? `View ${value}`}
                    aria-pressed={rowKey ? row[rowKey] === selectedRowKey : undefined}
                    onClick={() => onRowSelect(row)}><span aria-hidden="true">→</span></button>
                </div> : content}</td>;
            })}</tr>
          ))}</tbody>
        </table>
      </div>
      {pages > 1 && paginationStyle === "receipt" ? <div className="receipt-pagination">
        <button type="button" aria-label="Previous page" disabled={!currentPage}
          onClick={() => setPage(currentPage - 1)}>Previous</button>
        <span role="status" aria-live="polite">Rows {currentPage * pageSize + 1}–{Math.min((currentPage + 1) * pageSize, visible.length)} of {visible.length.toLocaleString()}</span>
        <button type="button" aria-label="Next page" disabled={currentPage + 1 >= pages}
          onClick={() => setPage(currentPage + 1)}>Next</button>
      </div> : paginationStyle !== "receipt" && (searchable || toolbarControls || pages > 1) && (
        <div className="toolbar table-pagination">
          <span className="source-value" aria-live="polite">{visible.length ? `${currentPage * pageSize + 1}–${Math.min((currentPage + 1) * pageSize,visible.length)} of ${visible.length} results` : "No results"}</span>
          {pages > 1 && <div className="actions"><span className="source-value">Page {currentPage + 1} of {pages}</span>
            <button type="button" className="table-page-button" aria-label="Previous page"
              disabled={!currentPage} onClick={() => setPage(currentPage - 1)}><Icon name="chevronLeft" /></button>
            <button type="button" className="table-page-button" aria-label="Next page"
              disabled={currentPage + 1 >= pages} onClick={() => setPage(currentPage + 1)}>
              <Icon name="chevronRight" />
            </button>
          </div>}
        </div>
      )}
    </>
  );
}
