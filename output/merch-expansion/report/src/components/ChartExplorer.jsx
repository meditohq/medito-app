import React, { useDeferredValue, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";

import { ChartRenderer } from "../charting/ChartRenderer.jsx";
import { annotationChartTypes } from "../charting/chart-annotations.js";
import { resolvedChartType } from "../charting/chart-data-shape.js";
import {
  changeChartEditorSpec,
  chartEditorChoices,
  chartEditorPreviewState,
  chartEditorSpecsEqual,
} from "../charting/chart-editor-state.js";
import { funnelStageColor, label as humanize, semanticColor } from "../charting/chart-theme.js";
import { chartColorIdentity, chartColorOptions, hexToHsv, hsvToHex, resolvedColorHex, resolvedColorName } from "./chart-color-utils.js";
import { NativeSelect } from "./contained-ui.jsx";
import { Icon } from "./Icon.jsx";
import { SegmentedControl } from "./SegmentedControl.jsx";
import { Switch } from "./Switch.jsx";

export { availableChartTypes } from "../charting/chart-editor-state.js";

const chartsWithoutAxes = new Set(["pie", "funnel", "sparkline", "rankedList", "sankey"]);
const chartsWithoutOptionalLabels = new Set(["waterfall", "funnel", "sparkline", "heatmap", "boxPlot", "rankedList"]);
const sortableCharts = new Set([
  "pie",
  "bar",
  "horizontalBar",
  "stackedBar",
  "stackedBar100",
  "horizontalStackedBar",
  "horizontalStackedBar100",
  "rankedList",
]);
export const chartTypeGroups = [
  { label: "Trends", choices: ["line", "area", "stackedArea", "sparkline"] },
  { label: "Comparisons", choices: ["bar", "horizontalBar", "rankedList", "waterfall"] },
  {
    label: "Composition",
    choices: ["stackedBar", "stackedBar100", "horizontalStackedBar", "horizontalStackedBar100", "pie"],
  },
  { label: "Distribution", choices: ["histogram", "scatter", "heatmap", "boxPlot"] },
  { label: "Flow", choices: ["funnel", "sankey"] },
];
const semanticColorCharts = new Set(["waterfall", "rankedList", "sankey", "heatmap"]);

function optionLabel(value) {
  if (value === "rankedList" || value === "leaderboard") return "Leaderboard";
  return humanize(String(value))
    .split(" ")
    .map((word, index) => (index && !/^[A-Z\d]+$/u.test(word) ? word.toLowerCase() : word))
    .join(" ")
    .replace(/([a-z])100$/u, "$1 (100%)");
}

function ChartMetadataField({ field, label, value, maxLength, rows = 1, disabled, onChange }) {
  const textareaRef = useRef(null);
  useLayoutEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return undefined;
    const resize = () => {
      textarea.style.height = "auto";
      const borderHeight = textarea.offsetHeight - textarea.clientHeight;
      textarea.style.height = `${textarea.scrollHeight + borderHeight}px`;
    };
    let width = textarea.getBoundingClientRect().width;
    resize();
    const observer = new ResizeObserver(() => {
      const nextWidth = textarea.getBoundingClientRect().width;
      if (nextWidth === width) return;
      width = nextWidth;
      resize();
    });
    observer.observe(textarea);
    return () => observer.disconnect();
  }, [value, rows]);

  return (
    <label className="chart-editor-metadata-field">
      <span>{label}</span>
      <textarea
        ref={textareaRef}
        className="chart-editor-metadata-input"
        aria-label={`Chart ${field}`}
        value={value}
        maxLength={maxLength}
        rows={rows}
        disabled={disabled}
        onChange={(event) => onChange?.(field, event.target.value)}
      />
    </label>
  );
}

function ChartSwitch({ label, checked, onChange, disabled = false }) {
  return <Switch label={label} checked={checked} onChange={onChange} disabled={disabled} fullWidth />;
}

function PreviewSkeleton() {
  return (
    <div className="explorer-preview-skeleton" aria-hidden="true">
      <i />
      <i />
      <i />
      <i />
    </div>
  );
}

function MountedChart({ onReady, ...props }) {
  useEffect(() => {
    let second;
    const first = requestAnimationFrame(() => {
      second = requestAnimationFrame(onReady);
    });
    return () => {
      cancelAnimationFrame(first);
      cancelAnimationFrame(second);
    };
  }, []);
  return <ChartRenderer {...props} />;
}

function ChartColorControl({
  colorKey,
  color,
  swatchColor = color,
  automatic = false,
  onChange,
  portalContainer,
  themeRoot,
  contained = false,
  disabled = false,
}) {
  const name = optionLabel(colorKey);
  const triggerRef = useRef(null);
  const popoverRef = useRef(null);
  const [popoverPosition, setPopoverPosition] = useState(null);
  const [customOpen, setCustomOpen] = useState(false);
  const [themeColorLabels, setThemeColorLabels] = useState({});
  const emittedColor = useRef(null);
  const [customHsv, setCustomHsv] = useState(() => hexToHsv(/^#[\da-f]{6}$/iu.test(color ?? "") ? color : "#0285ff"));
  const customHue = customHsv.hue;
  const [customHex, setCustomHex] = useState(/^#[\da-f]{6}$/iu.test(color ?? "") ? color : "#0285ff");
  const identity = chartColorIdentity(color, { automatic });
  const colorLabel = identity.label;
  const customSelected = identity.customHex !== null;
  useEffect(() => {
    const target = triggerRef.current;
    if (!target) return undefined;
    function updateThemeColorLabels() {
      const labels = Object.fromEntries(chartColorOptions.map(({ token }) => [token, resolvedColorName(token, target)]));
      setThemeColorLabels((current) => Object.keys(labels).every((token) => labels[token] === current[token])
        ? current : labels);
    }
    updateThemeColorLabels();
    const observer = new MutationObserver(updateThemeColorLabels);
    const options = { attributes: true, attributeFilter: ["style", "data-app-theme", "data-color-scheme"] };
    observer.observe(target.ownerDocument.documentElement, options);
    if (themeRoot) observer.observe(themeRoot, options);
    return () => observer.disconnect();
  }, [themeRoot]);
  useEffect(() => {
    if (customSelected && color !== emittedColor.current) {
      setCustomHex(color);
      setCustomHsv(hexToHsv(color));
    }
  }, [color, customSelected]);

  function changeHsv(next) {
    const hex = hsvToHex(next);
    emittedColor.current = hex;
    setCustomHsv(next);
    setCustomHex(hex);
    onChange(hex);
  }

  function toggleCustom() {
    if (!customOpen) {
      const hex = resolvedColorHex(color, triggerRef.current);
      setCustomHex(hex);
      setCustomHsv(hexToHsv(hex));
    }
    setCustomOpen((open) => !open);
  }

  useEffect(() => {
    if (!popoverPosition) return undefined;
    const trigger = triggerRef.current;
    const ownerDocument = trigger?.ownerDocument ?? document;
    const ownerWindow = ownerDocument.defaultView ?? window;
    const keyTarget = contained ? trigger?.closest(".chart-editor-dialog") ?? trigger?.getRootNode() : ownerWindow;
    const closeOutside = (event) => {
      const path = event.composedPath?.() ?? [];
      if (
        !path.includes(popoverRef.current) &&
        !path.includes(triggerRef.current) &&
        !popoverRef.current?.contains(event.target) &&
        !triggerRef.current?.contains(event.target)
      ) {
        setPopoverPosition(null);
        setCustomOpen(false);
      }
    };
    const closeOnEscape = (event) => {
      if (event.key === "Escape" && !event.defaultPrevented) {
        event.preventDefault();
        event.stopPropagation();
        setPopoverPosition(null);
        setCustomOpen(false);
        trigger?.focus({ preventScroll: true });
      }
    };
    ownerDocument.addEventListener("pointerdown", closeOutside);
    keyTarget?.addEventListener("keydown", closeOnEscape, true);
    return () => {
      ownerDocument.removeEventListener("pointerdown", closeOutside);
      keyTarget?.removeEventListener("keydown", closeOnEscape, true);
    };
  }, [contained, popoverPosition]);

  function togglePopover() {
    if (popoverPosition) {
      setPopoverPosition(null);
      setCustomOpen(false);
      return;
    }
    if (disabled) return;
    const bounds = triggerRef.current.getBoundingClientRect();
    const ownerWindow = triggerRef.current.ownerDocument.defaultView ?? window;
    setPopoverPosition({
      left: Math.max(12, Math.min(bounds.right - 272, ownerWindow.innerWidth - 284)),
      top: bounds.bottom + 7,
    });
  }

  function selectArea(event) {
    if (event.type === "pointermove" && event.buttons !== 1) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    const saturation = Math.max(0, Math.min(100, ((event.clientX - bounds.left) / bounds.width) * 100));
    const value = Math.max(0, Math.min(100, (1 - (event.clientY - bounds.top) / bounds.height) * 100));
    changeHsv({ hue: customHue, saturation, value });
    if (event.type === "pointerdown") event.currentTarget.setPointerCapture(event.pointerId);
  }

  return (
    <div className="explorer-color-row">
      <span className="explorer-property-name">{name}</span>
      <button
        ref={triggerRef}
        type="button"
        className="explorer-color-trigger"
        aria-label={`Color for ${name}`}
        aria-description={colorLabel}
        title={colorLabel}
        aria-expanded={Boolean(popoverPosition)}
        disabled={disabled}
        onClick={togglePopover}
      >
        <i style={{ "--explorer-swatch-color": swatchColor }} />
        <span>{colorLabel}</span>
      </button>
      {popoverPosition &&
        createPortal(
          <div
            ref={popoverRef}
            className="popover explorer-color-popover"
            aria-label={`Choose color for ${name}`}
            style={{
              left: popoverPosition.left,
              top: Math.max(
                12,
                Math.min(
                  popoverPosition.top,
                  (triggerRef.current?.ownerDocument.defaultView?.innerHeight ?? window.innerHeight) -
                    (customOpen ? 325 : 130) -
                    12,
                ),
              ),
            }}
          >
            <span className="explorer-color-popover-title">Theme colors</span>
            <div className="explorer-color-options" role="group" aria-label="Chart series colors">
              {chartColorOptions.map(({ label, token }) => (
                <button
                  key={token}
                  type="button"
                  className="explorer-color-option"
                  aria-label={label}
                  title={themeColorLabels[token] ? `${label} (${themeColorLabels[token]})` : label}
                  aria-description={themeColorLabels[token]}
                  aria-pressed={identity.explicitColor === token}
                  style={{ "--explorer-swatch-color": token }}
                  onClick={() => onChange(token)}
                />
              ))}
              <button
                type="button"
                className="explorer-color-option explorer-custom-color"
                aria-label={`Custom color for ${name}`}
                aria-expanded={customOpen}
                aria-pressed={customSelected}
                style={{ "--explorer-swatch-color": customSelected ? color : "var(--secondary)" }}
                onClick={toggleCustom}
              >
                <Icon name="plus" size={15} />
              </button>
            </div>
            {customOpen && (
              <div className="explorer-custom-picker">
                <div
                  className="explorer-color-area"
                  role="slider"
                  aria-label="Color saturation and brightness"
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={Math.round(customHsv.saturation)}
                  aria-valuetext={`${Math.round(customHsv.saturation)}% saturation, ${Math.round(customHsv.value)}% brightness`}
                  tabIndex={0}
                  style={{ "--explorer-custom-hue": `${customHue}deg` }}
                  onPointerDown={selectArea}
                  onPointerMove={selectArea}
                  onKeyDown={(event) => {
                    if (!event.key.startsWith("Arrow")) return;
                    event.preventDefault();
                    const step = event.shiftKey ? 10 : 1;
                    changeHsv({
                      ...customHsv,
                      saturation: Math.max(
                        0,
                        Math.min(
                          100,
                          customHsv.saturation +
                            (event.key === "ArrowRight" ? step : event.key === "ArrowLeft" ? -step : 0),
                        ),
                      ),
                      value: Math.max(
                        0,
                        Math.min(
                          100,
                          customHsv.value + (event.key === "ArrowUp" ? step : event.key === "ArrowDown" ? -step : 0),
                        ),
                      ),
                    });
                  }}
                >
                  <span
                    className="explorer-color-handle"
                    aria-hidden="true"
                    style={{
                      left: `${customHsv.saturation}%`,
                      top: `${100 - customHsv.value}%`,
                      background: customHex,
                    }}
                  />
                </div>
                <input
                  className="explorer-hue-slider"
                  type="range"
                  min="0"
                  max="359"
                  aria-label="Color hue"
                  value={customHue}
                  onChange={(event) => {
                    const hue = Number(event.target.value);
                    changeHsv({ ...customHsv, hue });
                  }}
                />
                <label className="explorer-hex-color">
                  <span>Hex</span>
                  <input
                    aria-label={`Custom hex color for ${name}`}
                    value={customHex.toUpperCase()}
                    maxLength={7}
                    spellCheck={false}
                    onChange={(event) => {
                      const value = event.target.value.startsWith("#") ? event.target.value : `#${event.target.value}`;
                      setCustomHex(value);
                      if (/^#[\da-f]{6}$/iu.test(value)) onChange(value);
                    }}
                  />
                </label>
              </div>
            )}
          </div>,
          portalContainer ??
            triggerRef.current?.closest(".chart-editor-dialog") ??
            triggerRef.current?.ownerDocument.body ??
            document.body,
        )}
    </div>
  );
}

function BarPresentationControls({ spec, columns, numeric, update, SelectComponent, disabled, portalContainer, contained }) {
  const options = spec.barOptions ?? {};
  const option = (key, value) => update("barOptions")({ ...options, [key]: value });
  const control = (label, value, onChange, choices = numeric) => <label key={label}><span>{label}</span>
    <SelectComponent label={label} value={value} choices={choices} formatChoice={optionLabel} onChange={onChange}
      disabled={disabled} portalContainer={portalContainer} modal={!contained} /></label>;
  return <section className="explorer-section" aria-label="Reviewed data settings"><h3>Data</h3>
    {control("Category", spec.x, update("x"), columns)}
    {options.series?.length ? options.series.map((series, index) => control(series.label ?? `Measure ${index + 1}`, series.key,
      value => option("series", options.series.map((item, i) => i === index ? { ...item, key: value } : item))))
      : options.range?.length ? options.range.map((field, index) => control(index ? "Range end" : "Range start", field,
        value => option("range", options.range.map((item, i) => i === index ? value : item))))
        : control("Measure", spec.y, update("y"))}
    {options.target && control("Target", options.target, value => option("target", value))}
    {spec.presentation === "rangePosition" && control("Current value", spec.y, update("y"))}
    {options.projection && control("Projection", options.projection, value => option("projection", value))}
    {spec.presentation === "progress" && control("Goal", options.track?.max, value => option("track", { ...options.track, max: value }))}
  </section>;
}

export function ChartExplorer({
  SelectComponent = NativeSelect,
  component,
  rows,
  onChange,
  resolveColor,
  chartId,
  visibleSeries,
  zoomRange,
  canEdit = true,
  draft,
  getCapabilities,
  portalContainer,
  themeRoot,
  previewHeight = 500,
  contained = false,
  disabled = false,
  metadata,
  onMetadataChange,
  notice,
  error,
}) {
  const columns = useMemo(() => [...new Set(rows.flatMap(Object.keys))], [rows]);
  const numeric = useMemo(
    () =>
      columns.filter((column) => rows.some((row) => typeof row[column] === "number" && Number.isFinite(row[column]))),
    [columns, rows],
  );
  const initial = component.chart;
  const [localSpec, setLocalSpec] = useState(initial);
  const [previewReady, setPreviewReady] = useState(false);
  const [previewPainted, setPreviewPainted] = useState(false);
  const spec = useMemo(() => {
    const current = draft ?? localSpec;
    const type = resolvedChartType(current, rows);
    return type === current.type ? current : { ...current, type };
  }, [draft, localSpec, rows]);
  const previewSpec = useDeferredValue(spec);
  const capabilities = getCapabilities?.(spec, rows) ?? {};
  const { availableTypes, fieldsEditable, xFields, yFields, seriesFields } = chartEditorChoices(
    component.chart,
    spec,
    { columns, numeric },
    capabilities,
  );
  const notices = [
    ...new Set([notice, capabilities.notice].filter((value) => typeof value === "string" && value.trim())),
  ];
  const previewState = chartEditorPreviewState(component.chart, previewSpec, { visibleSeries, zoomRange });
  const previewKey = JSON.stringify([
    previewSpec.type,
    previewSpec.x,
    previewSpec.y,
    previewSpec.series ?? "",
    previewSpec.fields ?? [previewSpec.y],
  ]);
  const horizontal = spec.type.startsWith("horizontal");
  const categoryFieldLabel =
    spec.type === "pie" || spec.type === "funnel" ? "Group by" : horizontal ? "Y axis" : "X axis";
  const valueFieldLabel = spec.type === "pie" || spec.type === "funnel" ? "Measure" : horizontal ? "X axis" : "Y axis";
  const hasLegend = spec.type === "pie" || Boolean(spec.series) || (spec.fields ?? [spec.y]).length > 1;
  const hasAnnotations = annotationChartTypes.includes(spec.type)
    && Array.isArray(spec.annotations) && spec.annotations.length > 0;
  const colorKeys = useMemo(
    () =>
      semanticColorCharts.has(spec.type)
        ? []
        : spec.type === "pie" || spec.type === "funnel"
          ? [...new Set(rows.map((row) => row[spec.x]).filter((value) => value != null))]
          : spec.series
            ? [...new Set(rows.map((row) => row[spec.series]).filter((value) => value != null))]
            : (spec.fields ?? [spec.y]).filter(Boolean),
    [rows, spec.fields, spec.series, spec.type, spec.x, spec.y],
  );
  const colorForKey = (key, index) =>
    spec.colors?.[key] ??
    (spec.type === "funnel" ? spec.colors?.[spec.y]
      ?? resolveColor?.({ field: spec.y, index: 0 }) ?? semanticColor({ field: spec.y, index: 0 })
      : ["line", "sparkline"].includes(spec.type) && /(?:target|plan|forecast|projected|benchmark)/iu.test(String(key))
      ? "var(--secondary)"
      : resolveColor?.(
          spec.series || spec.type === "pie" || spec.type === "funnel"
            ? { field: spec.y, dimension: spec.series || spec.x, value: key, index }
            : { field: key, index },
        ));

  useEffect(() => {
    let revealFrame;
    const shellFrame = requestAnimationFrame(() => {
      revealFrame = requestAnimationFrame(() => setPreviewReady(true));
    });
    return () => {
      cancelAnimationFrame(shellFrame);
      if (revealFrame) cancelAnimationFrame(revealFrame);
    };
  }, []);

  const update = (field) => (value) => {
    if (
      disabled ||
      (field === "type" && !availableTypes.includes(value)) ||
      (field === "x" && (!fieldsEditable || !xFields.includes(value))) ||
      (field === "y" && (!fieldsEditable || !yFields.includes(value))) ||
      (field === "series" && (!fieldsEditable || !seriesFields.includes(value)))
    )
      return;
    const next = changeChartEditorSpec(draft ?? localSpec, field, value, { columns });
    setLocalSpec(next);
    onChange?.(next, !chartEditorSpecsEqual(next, initial), field);
  };

  return (
    <div className="chart-explorer">
      <div className="explorer-preview">
        <div className="explorer-chart" data-ready={previewPainted} aria-busy={!previewPainted}>
          <PreviewSkeleton />
          <div className="explorer-chart-content">
            {previewReady && (
              <MountedChart
                key={previewKey}
                onReady={() => setPreviewPainted(true)}
                spec={previewSpec}
                rows={rows}
                height={previewHeight}
                chartId={chartId ?? component.id}
                resolveColor={resolveColor}
                themeRoot={themeRoot}
                visibleSeries={previewState.visibleSeries}
                zoomRange={previewState.zoomRange}
              />
            )}
          </div>
        </div>
      </div>
      {canEdit && (
        <div className="explorer-controls" aria-label="Chart controls">
          {notices.map((value) => (
            <p key={value} className="chart-editor-notice">
              {value}
            </p>
          ))}
          {error && (
            <p className="chart-editor-error" role="alert">
              {error}
            </p>
          )}
          {metadata && (
            <section className="explorer-section chart-editor-metadata" aria-label="Chart details">
              <h3>Details</h3>
              <ChartMetadataField
                field="title"
                label="Title"
                value={metadata.title}
                maxLength={500}
                disabled={disabled}
                onChange={onMetadataChange}
              />
              <ChartMetadataField
                field="description"
                label="Description"
                value={metadata.description ?? ""}
                maxLength={2000}
                rows={1}
                disabled={disabled}
                onChange={onMetadataChange}
              />
            </section>
          )}
          {spec.presentation ? (fieldsEditable && <BarPresentationControls spec={spec} columns={columns} numeric={numeric}
            update={update} SelectComponent={SelectComponent} disabled={disabled} portalContainer={portalContainer}
            contained={contained} />) : <>
          <section className="explorer-section explorer-visualization-section" aria-label="Visualization settings">
            <h3>Visualization</h3>
            <label>
              <span>Chart type</span>
              <SelectComponent
                label="Chart type"
                value={spec.type}
                choices={availableTypes}
                groups={chartTypeGroups
                  .map((group) => ({
                    ...group,
                    choices: group.choices.filter((type) => availableTypes.includes(type)),
                  }))
                  .filter((group) => group.choices.length)}
                contentClassName="chart-type-menu"
                formatChoice={optionLabel}
                onChange={update("type")}
                disabled={disabled || availableTypes.length < 2}
                portalContainer={portalContainer}
                modal={!contained}
              />
            </label>
          </section>
          {(fieldsEditable || sortableCharts.has(spec.type)) && (
            <section className="explorer-section" aria-label="Reviewed data settings">
              <h3>Data</h3>
              {fieldsEditable && (
                <>
                  <label>
                    <span>{categoryFieldLabel}</span>
                    <SelectComponent
                      label={categoryFieldLabel}
                      value={spec.x}
                      choices={xFields}
                      formatChoice={optionLabel}
                      onChange={update("x")}
                      disabled={disabled || xFields.length < 2}
                      portalContainer={portalContainer}
                      modal={!contained}
                    />
                  </label>
                  <label>
                    <span>{valueFieldLabel}</span>
                    <SelectComponent
                      label={valueFieldLabel}
                      value={spec.y}
                      choices={yFields}
                      formatChoice={optionLabel}
                      onChange={update("y")}
                      disabled={disabled || yFields.length < 2}
                      portalContainer={portalContainer}
                      modal={!contained}
                    />
                  </label>
                  <label>
                    <span>Split by</span>
                    <SelectComponent
                      label="Split series by"
                      value={spec.series}
                      choices={seriesFields}
                      formatChoice={optionLabel}
                      onChange={update("series")}
                      disabled={disabled || seriesFields.length < 2}
                      portalContainer={portalContainer}
                      modal={!contained}
                    />
                  </label>
                </>
              )}
              {sortableCharts.has(spec.type) && (
                <label>
                  <span>Sort order</span>
                  <SelectComponent
                    label="Sort order"
                    value={
                      spec.sortOrder ?? (["leaderboard", "rankedList"].includes(spec.type) ? "descending" : "original")
                    }
                    choices={["original", "ascending", "descending"]}
                    formatChoice={optionLabel}
                    onChange={update("sortOrder")}
                    disabled={disabled}
                    portalContainer={portalContainer}
                    modal={!contained}
                  />
                </label>
              )}
            </section>
          )}
          {!chartsWithoutAxes.has(spec.type) && (
            <section className="explorer-section" aria-label="Chart axes settings">
              <h3>Axes</h3>
              {!spec.series && !spec.barFields?.length && (spec.fields ?? []).length > 1
                && ["line", "bar", "area", "horizontalBar"].includes(spec.type) && (
                <label><span>{horizontal ? "Secondary axis" : "Right axis"}</span>
                  <SelectComponent label="Secondary axis" value={spec.rightAxisFields === undefined ? "auto"
                    : spec.rightAxisFields[0] ?? "none"} choices={["auto", "none", ...spec.fields]}
                    formatChoice={(value) => value === "auto" ? "Automatic" : value === "none" ? "Shared scale" : optionLabel(value)}
                    onChange={(value) => update("rightAxisFields")(value === "auto" ? undefined : value === "none" ? [] : [value])}
                    disabled={disabled} portalContainer={portalContainer} modal={!contained} />
                </label>
              )}
              <label>
                <span>X axis label</span>
                <input
                  aria-label="X axis title"
                  value={spec.xLabel ?? (spec.type === "histogram" && spec.showXAxisLabel !== false ? humanize(spec.y) : "")}
                  disabled={disabled}
                  onChange={(event) => update("xLabel")(event.target.value)}
                />
              </label>
              {!spec.type.startsWith("horizontal") && (
                <label>
                  <span>Y axis label</span>
                  <input
                    aria-label="Y axis title"
                    value={spec.yLabel ?? (spec.type === "histogram" && spec.showYAxisLabel === true ? "Observations" : "")}
                    disabled={disabled}
                    onChange={(event) => update("yLabel")(event.target.value)}
                  />
                </label>
              )}
              <div className="explorer-control-row"><span>Y axis side</span>
                <SegmentedControl ariaLabel="Y axis side" size="default" value={spec.yAxisPosition ?? "left"}
                  options={[{ value: "left", label: "Left" }, { value: "right", label: "Right" }]}
                  onChange={update("yAxisPosition")} disabled={disabled} fullWidth />
              </div>
              {!["heatmap", "histogram"].includes(spec.type) && (
                <ChartSwitch
                  label="Start axis at zero"
                  checked={spec.startAtZero !== false}
                  onChange={update("startAtZero")}
                  disabled={disabled}
                />
              )}
            </section>
          )}
          {(colorKeys.length > 0 || spec.type === "heatmap") && (
            <section className="explorer-section" aria-label="Chart color settings">
              <h3>Colors</h3>
              {spec.type === "heatmap" && (
                <ChartColorControl
                  colorKey="Base color"
                  color={spec.baseColor ?? "var(--chart-1)"}
                  automatic={spec.baseColor == null}
                  onChange={update("baseColor")}
                  portalContainer={portalContainer}
                  contained={contained}
                  themeRoot={themeRoot}
                  disabled={disabled}
                />
              )}
              {colorKeys.map((key, index) => (
                <ChartColorControl
                  key={String(key)}
                  colorKey={key}
                  color={colorForKey(key, index)}
                  swatchColor={spec.type === "funnel" ? funnelStageColor(colorForKey(key, index),
                    rows.findIndex((row) => row[spec.x] === key), rows.length) : undefined}
                  automatic={spec.colors?.[key] == null}
                  onChange={(color) => update("colors")({ ...spec.colors, [key]: color })}
                  portalContainer={portalContainer}
                  contained={contained}
                  themeRoot={themeRoot}
                  disabled={disabled}
                />
              ))}
            </section>
          )}
          {(!chartsWithoutOptionalLabels.has(spec.type) || hasLegend || hasAnnotations) && (
            <section className="explorer-section" aria-label="Chart appearance settings">
              <h3>Appearance</h3>
              {!chartsWithoutOptionalLabels.has(spec.type) && (
                <ChartSwitch
                  label="Show values"
                  checked={spec.showValues === true}
                  onChange={update("showValues")}
                  disabled={disabled}
                />
              )}
              {hasLegend && (
                <ChartSwitch
                  label="Show legend"
                  checked={spec.showLegend !== false}
                  onChange={update("showLegend")}
                  disabled={disabled}
                />
              )}
              {hasAnnotations && <ChartSwitch label="Show annotations"
                checked={spec.showAnnotations !== false} onChange={update("showAnnotations")} disabled={disabled} />}
            </section>
          )}
          </>}
        </div>
      )}
    </div>
  );
}
