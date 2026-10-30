import React, { useEffect, useLayoutEffect, useId, useMemo, useRef, useState } from "react";

import { chartImageResolution, renderLiveChartImage } from "../chart-image.js";
import { chartExportAppearance, chartExportControls, chartExportFilename, chartExportPresets, chartExportSize, chartExportSpec } from "../chart-export.js";
import { ChartRenderer } from "../charting/ChartRenderer.jsx";
import { dataAppThemes } from "../theme-presets.js";
import { Dialog, Select } from "./ui.jsx";
import { Switch } from "./Switch.jsx";
import { SegmentedControl } from "./SegmentedControl.jsx";

const emptyProvenance = {};
const exportThemes = dataAppThemes.filter(theme => theme.tokens);

function initialAppearance() {
  if (typeof document === "undefined") return "light";
  return getComputedStyle(document.documentElement).colorScheme === "dark" ? "dark" : "light";
}

function DimensionInput({ label, value, minimum, onCommit }) {
  const [text, setText] = useState(String(value));
  useEffect(() => setText(String(value)), [value]);
  return <label><span aria-hidden="true">{label[0]}</span><input aria-label={label} type="number" min={minimum} max={2400} step={10} value={text}
    onChange={event => setText(event.target.value)}
    onKeyDown={event => { if (event.key === "Enter") event.currentTarget.blur(); }}
    onBlur={() => {
      const number = Number(text);
      const next = text.trim() && Number.isFinite(number) ? Math.max(minimum, Math.min(2400, Math.round(number))) : value;
      setText(String(next));
      if (next !== value) onCommit(next);
    }} /></label>;
}

export function ChartExportDialog({ component, rows, originalSize, provenance = emptyProvenance, resolveColor, visibleSeries, zoomRange, onClose }) {
  const chartId = useId();
  const artwork = useRef(null);
  const stage = useRef(null);
  const [plot, setPlot] = useState(null);
  const [previewScale, setPreviewScale] = useState(1);
  const drag = useRef(null);
  const closeTimer = useRef(null);
  const downloadedUrl = useRef(null);
  const [closing, setClosing] = useState(false);
  const [size, setSize] = useState(() => chartExportSize(originalSize.width, originalSize.height));
  const [preset, setPreset] = useState("original");
  const [appearance, setAppearance] = useState(initialAppearance);
  const [transparent, setTransparent] = useState(false);
  const [themeId, setThemeId] = useState(() => exportThemes.find(theme =>
    theme.id === (typeof document === "undefined" ? null : document.documentElement.dataset.appTheme))?.id ?? "codex-classic");
  const [options, setOptions] = useState({ title: true, description: true, source: true, filters: true, values: component.chart.showValues === true, axes: true });
  const [plotHeight, setPlotHeight] = useState(240);
  const [image, setImage] = useState(null);
  const [error, setError] = useState("");
  const [layoutError, setLayoutError] = useState("");
  const [copyStatus, setCopyStatus] = useState("");
  const [busy, setBusy] = useState(true);
  const controls = chartExportControls(component.chart);
  const spec = useMemo(() => chartExportSpec(component.chart, options), [component.chart, options]);
  const appearanceStyle = useMemo(() => chartExportAppearance(themeId, appearance), [themeId, appearance]);
  const selectedPreset = chartExportPresets.find(item => item.id === preset);
  const resolution = chartImageResolution(size.width, size.height);
  const imageKey = JSON.stringify({ size, options, plotHeight, appearance, themeId, transparent });
  const ready = !busy && !error && !layoutError && image?.key === imageKey;
  useLayoutEffect(() => {
    const element = stage.current;
    if (!element) return undefined;
    const update = () => setPreviewScale(window.matchMedia('(max-width: 650px)').matches
      ? Math.min(1, (element.clientWidth - 32) / (size.width + 2)) : 1);
    update();
    const observer = new ResizeObserver(update);
    observer.observe(element);
    window.addEventListener('resize', update);
    return () => { observer.disconnect(); window.removeEventListener('resize', update); };
  }, [size.width, plot]);
  // Preview layout is independent of PNG encoding. Fixed axis widths keep
  // Recharts' automatic label measurements stable while resizing.
  const chart = useMemo(() => <ChartRenderer key={`${appearance}-${themeId}`}
    spec={{ ...spec, markRadius: spec.markRadius ?? Number(appearanceStyle["--mark-radius"]) }} rows={rows}
    height={plotHeight} chartId={`export-${chartId}`} resolveColor={resolveColor} themeRoot={plot?.parentElement} fixedAxisWidths
    visibleSeries={visibleSeries} zoomRange={zoomRange} />,
  [spec, rows, plotHeight, chartId, resolveColor, visibleSeries, zoomRange, appearance, appearanceStyle, themeId, plot]);

  useEffect(() => () => window.clearTimeout(closeTimer.current), []);

  function dismiss() {
    if (closing) return;
    if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
      onClose();
      return;
    }
    setClosing(true);
    closeTimer.current = window.setTimeout(onClose, 110);
  }

  useLayoutEffect(() => {
    const area = plot;
    if (!area) return undefined;
    let cancelled = false;
    const measure = () => {
      if (cancelled) return;
      const layout = area.querySelector(".chart-layout");
      const frame = layout?.querySelector(".chart-frame");
      const funnel = area.querySelector(".chart-funnel");
      const canvas = funnel?.querySelector(".chart-funnel-canvas");
      const vertical = funnel?.dataset.funnelLayout === "vertical";
      const extra = layout && frame ? Math.max(0, layout.offsetHeight - frame.offsetHeight)
        : canvas && !vertical ? canvas.offsetHeight - plotHeight : 0;
      const minimumPlot = vertical ? area.scrollHeight : (canvas ? 232 : 100) + extra;
      const minimumHeight = Math.ceil(size.height - area.clientHeight + minimumPlot);
      if (minimumHeight > size.height + 1) {
        if ((preset === "original" || chartExportPresets.find(item => item.id === preset)?.adaptiveHeight) && minimumHeight <= 2400) {
          setSize(current => ({ ...current, height: minimumHeight }));
          return;
        }
        setLayoutError(`Use a height of at least ${minimumHeight} px to fit this chart and its labels.`);
        return;
      }
      setLayoutError("");
      if (frame || canvas && !vertical) {
        const next = Math.max(canvas ? 232 : 100, area.clientHeight - extra);
        if (Math.abs(next - plotHeight) > 1) setPlotHeight(next);
      }
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(area);
    if (area.firstElementChild) observer.observe(area.firstElementChild);
    document.fonts?.ready.then(measure);
    return () => { cancelled = true; observer.disconnect(); };
  }, [plot, size, options, plotHeight, preset, appearance, themeId]);

  useEffect(() => {
    let cancelled = false;
    let firstFrame;
    let secondFrame;
    let url;
    setBusy(true);
    setError("");
    setCopyStatus("");
    // Only the downloadable PNG is debounced; the live chart stays visible.
    const timer = setTimeout(async () => {
      await document.fonts?.ready;
      if (cancelled || layoutError) return;
      firstFrame = requestAnimationFrame(() => {
        secondFrame = requestAnimationFrame(async () => {
          try {
            const result = await renderLiveChartImage(artwork.current, { transparent });
            if (cancelled) return;
            url = URL.createObjectURL(result.blob);
            setImage({ ...result, url, key: imageKey });
            setBusy(false);
          } catch (failure) {
            if (cancelled) return;
            setError(failure instanceof Error ? failure.message : "The chart could not be exported.");
            setBusy(false);
          }
        });
      });
    }, 160);
    return () => {
      cancelled = true;
      clearTimeout(timer);
      cancelAnimationFrame(firstFrame);
      cancelAnimationFrame(secondFrame);
      if (url) {
        // Let the browser consume the download even when reduced motion closes
        // the dialog before the native link's default action runs.
        if (downloadedUrl.current === url) window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
        else URL.revokeObjectURL(url);
      }
    };
  }, [imageKey, layoutError, component, rows, provenance, visibleSeries, zoomRange, resolveColor]);

  function resize(width, height) {
    setPreset("custom");
    setSize(chartExportSize(width, height));
  }
  function choosePreset(id) {
    setPreset(id);
    const next = id === "original" ? originalSize : chartExportPresets.find(item => item.id === id);
    if (next?.width) setSize(chartExportSize(next.width, next.height));
  }
  function chooseTheme(id) {
    setThemeId(id);
    if (exportThemes.find(theme => theme.id === id)?.darkOnly) setAppearance("dark");
  }
  function chooseAppearance(value) {
    setAppearance(value);
    if (value === "light" && exportThemes.find(theme => theme.id === themeId)?.darkOnly) setThemeId("codex-classic");
  }
  async function copyImage() {
    if (!ready) return;
    try {
      if (!navigator.clipboard?.write || typeof ClipboardItem !== "function") throw new Error("Copying images is unavailable in this browser. Download the PNG instead.");
      await navigator.clipboard.write([new ClipboardItem({ "image/png": image.blob })]);
      setCopyStatus("Copied");
    } catch (failure) {
      setCopyStatus(failure instanceof Error ? failure.message : "The image could not be copied. Download the PNG instead.");
    }
  }
  const toggle = key => value => setOptions(current => ({ ...current, [key]: value }));

  return <Dialog title="Export chart" className={`chart-editor-dialog chart-export-dialog${closing ? " is-closing" : ""}`} backdropClassName="chart-editor-backdrop"
    initialFocusSelector=".dialog-header" expanded onClose={dismiss}>
    <div className="chart-export-layout">
      <div className="chart-export-main">
        <div ref={stage} className="chart-export-stage">
          <div className="chart-export-preview-frame" style={{ width: (size.width + 2) * previewScale, height: (size.height + 2) * previewScale }}>
          <div className="chart-export-preview" style={{ width: size.width, height: size.height, transform: `scale(${previewScale})` }}>
            <div className="chart-export-preview-clip" data-transparent={transparent} style={appearanceStyle}>
              <div ref={artwork} className="chart-export-artwork" data-transparent={transparent} style={{ ...appearanceStyle, width: size.width, height: size.height }}
                role="img" aria-label={`Export preview of ${component.title}`}>
                {(options.title || options.description && component.description) && <header className="chart-export-heading">
                  {options.title && <h2>{component.title}</h2>}
                  {options.description && component.description && <p>{component.description}</p>}
                </header>}
                <div ref={setPlot} className="chart-export-plot">
                  {chart}
                </div>
                {(options.source && provenance.source || options.filters && provenance.filters) && <div className="chart-export-provenance">
                  {options.source && provenance.source && <p>{provenance.source}</p>}
                  {options.filters && provenance.filters && <p>{provenance.filters}</p>}
                </div>}
              </div>
            </div>
          </div>
            <button type="button" className="chart-export-resize" aria-label="Resize chart image"
              title="Drag to resize, or use the arrow keys"
              onPointerDown={event => {
                if (event.button !== 0) return;
                event.preventDefault();
                event.currentTarget.setPointerCapture(event.pointerId);
                drag.current = { x: event.clientX, y: event.clientY, scale: previewScale, ...size };
              }}
              onPointerMove={event => {
                const start = drag.current;
                if (start) resize(start.width + (event.clientX - start.x) / start.scale,
                  start.height + (event.clientY - start.y) / start.scale);
              }}
              onPointerUp={() => { drag.current = null; }}
              onPointerCancel={() => { drag.current = null; }}
              onLostPointerCapture={() => { drag.current = null; }}
              onKeyDown={event => {
                const step = event.shiftKey ? 100 : 10;
                if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
                event.preventDefault();
                resize(size.width + (event.key === "ArrowRight" ? step : event.key === "ArrowLeft" ? -step : 0),
                  size.height + (event.key === "ArrowDown" ? step : event.key === "ArrowUp" ? -step : 0));
              }} />
          </div>
        </div>
        <div className="chart-export-size-controls">
          <div className="chart-export-presets" role="group" aria-label="Image size presets">
            {chartExportPresets.filter(item => item.id !== "custom").map(item => <button type="button" key={item.id} data-active={preset === item.id || undefined}
              title={item.width ? `${item.label} · ${item.width} × ${item.height}` : item.label}
              aria-label={item.label} aria-pressed={preset === item.id} onClick={() => choosePreset(item.id)}>
              {item.label}
            </button>)}
            <div className="chart-export-custom-size">
              <button type="button" data-active={preset === "custom" || undefined} aria-pressed={preset === "custom"}
                onClick={() => choosePreset("custom")}>Custom</button>
              {preset === "custom" && <div className="chart-export-dimensions">
                <DimensionInput label="Width" value={size.width} minimum={320} onCommit={width => resize(width, size.height)} />
                <span aria-hidden="true">×</span>
                <DimensionInput label="Height" value={size.height} minimum={240} onCommit={height => resize(size.width, height)} />
                <span>px</span>
              </div>}
            </div>
          </div>
          <p className="chart-export-preset-description">
            {selectedPreset?.description && <>{size.width} × {size.height} · {selectedPreset.description}<br /></>}
            PNG {resolution.width} × {resolution.height} px · {Number(resolution.scale.toFixed(2))}× resolution
          </p>
        </div>
      </div>
      <aside className="chart-export-controls explorer-controls" aria-label="Export settings">
        <section className="explorer-section">
          <h3>Theme</h3>
          <Select label="Image theme" value={themeId} choices={exportThemes.map(theme => theme.id)} onChange={chooseTheme}
            formatChoice={id => exportThemes.find(theme => theme.id === id)?.label} />
        </section>
        <section className="explorer-section">
          <h3>Appearance</h3>
          <SegmentedControl ariaLabel="Image appearance" value={appearance} onChange={chooseAppearance} fullWidth
            options={[{ value: "light", label: "Light" }, { value: "dark", label: "Dark" }]} />
          <Switch fullWidth label="Transparent background" checked={transparent} onChange={setTransparent} />
        </section>
        <section className="explorer-section">
          <h3>Include</h3>
          <Switch fullWidth label="Title" checked={options.title} onChange={toggle("title")} />
          {component.description && <Switch fullWidth label="Description" checked={options.description} onChange={toggle("description")} />}
          {controls.values && <Switch fullWidth label="Data labels" checked={options.values} onChange={toggle("values")} />}
          {controls.axes && <Switch fullWidth label="Axis titles" checked={options.axes} onChange={toggle("axes")} />}
          {provenance.source && <Switch fullWidth label="Source" checked={options.source} onChange={toggle("source")} />}
          {provenance.filters && <Switch fullWidth label="Filters" checked={options.filters} onChange={toggle("filters")} />}
        </section>
      </aside>
    </div>
    <footer className="chart-export-footer">
      {(layoutError || error || copyStatus && copyStatus !== "Copied") && <p className="chart-export-status" role="alert">{layoutError || error || copyStatus}</p>}
      <button type="button" className="dashboard-header-action-button" disabled={!ready} onClick={copyImage}>{copyStatus === "Copied" ? "Copied" : "Copy image"}</button>
      {ready ? <a className="dashboard-publish-button" href={image.url} download={chartExportFilename(component.title)}
        onClick={() => { downloadedUrl.current = image.url; dismiss(); }}>Download PNG</a>
        : <button type="button" className="dashboard-publish-button" disabled>Download PNG</button>}
    </footer>
  </Dialog>;
}
