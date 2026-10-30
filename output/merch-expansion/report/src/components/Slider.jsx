import React, { useId, useLayoutEffect, useRef, useState } from "react";

import {
  clampSliderValue,
  layoutRangeSliderLabels,
  layoutSingleSliderLabels,
  normalizeMinDistance,
  normalizeRangeValue,
  normalizeSliderBounds,
  normalizeSliderStep,
  sliderPercent,
  sliderValueAtPosition,
  updateRangeValue,
} from "./slider-math.js";

const labelPlacements = new Set(["outside", "inline", "hidden"]);
const sliderLayouts = new Set(["stacked", "inline"]);

function normalizedLabelPlacement(value) {
  return labelPlacements.has(value) ? value : "outside";
}

function normalizedSliderLayout(value) {
  return sliderLayouts.has(value) ? value : "stacked";
}

function stableId(providedId, generatedId) {
  return providedId || `data-slider-${generatedId.replaceAll(":", "")}`;
}

function formattedValue(formatValue, value) {
  return String(formatValue(value));
}

function SliderLabel({ controlId, labelId, label, placement, labelRef }) {
  if (placement === "inline") {
    return <span ref={labelRef} id={labelId}
      className="data-slider-label data-slider-label--inline">{label}</span>;
  }
  return <label ref={labelRef} id={labelId} htmlFor={controlId}
    className={`data-slider-label data-slider-label--${placement}`}>{label}</label>;
}

function observeLayout(elements, update) {
  update();
  const observer = typeof ResizeObserver === "function" ? new ResizeObserver(update) : null;
  elements.filter(Boolean).forEach((element) => observer?.observe(element));
  globalThis.addEventListener?.("resize", update);
  return () => {
    observer?.disconnect();
    globalThis.removeEventListener?.("resize", update);
  };
}

function useRangeValueLayout({
  controlRef,
  lowerValueRef,
  upperValueRef,
  labelRef,
  minimumBoundRef,
  maximumBoundRef,
  startPercent,
  endPercent,
  showBounds,
  layoutKey,
}) {
  const [layout, setLayout] = useState(null);

  useLayoutEffect(() => observeLayout([
    controlRef.current,
    lowerValueRef.current,
    upperValueRef.current,
    labelRef.current,
    minimumBoundRef.current,
    maximumBoundRef.current,
  ], () => {
    const control = controlRef.current;
    const lowerOutput = lowerValueRef.current;
    const upperOutput = upperValueRef.current;
    if (!control || !lowerOutput || !upperOutput) return;
    const inlineLabelWidth = labelRef.current?.classList.contains("data-slider-label--inline")
      ? labelRef.current.offsetWidth : 0;
    const next = layoutRangeSliderLabels({
      width: control.clientWidth,
      startPercent,
      endPercent,
      lowerWidth: lowerOutput.offsetWidth,
      upperWidth: upperOutput.offsetWidth,
      inlineLabelWidth,
      minimumBoundWidth: minimumBoundRef.current?.offsetWidth ?? 0,
      maximumBoundWidth: maximumBoundRef.current?.offsetWidth ?? 0,
      showBounds,
    });
    next.centerInlineLabel = inlineLabelWidth > 0
      && control.clientWidth * startPercent / 100 < 12 + inlineLabelWidth + 12;
    setLayout((current) => current
      && Object.keys(next).every((key) => current[key] === next[key]) ? current : next);
  }), [controlRef, endPercent, labelRef, layoutKey, lowerValueRef,
    maximumBoundRef, minimumBoundRef, showBounds, startPercent, upperValueRef]);

  return layout;
}

export function Slider({
  id,
  name,
  label = "Value",
  min = 0,
  max = 100,
  step = 1,
  value = min,
  onChange,
  formatValue = String,
  disabled = false,
  showBounds = false,
  labelPlacement = "outside",
  layout: layoutMode = "stacked",
  className = "",
  style,
}) {
  const generatedId = useId();
  const controlId = stableId(id, generatedId);
  const labelId = `${controlId}-label`;
  const placement = normalizedLabelPlacement(labelPlacement);
  const resolvedLayout = normalizedSliderLayout(layoutMode);
  const bounds = normalizeSliderBounds(min, max);
  const normalizedStep = normalizeSliderStep(step);
  const normalizedValue = clampSliderValue(value, bounds.minimum, bounds.maximum);
  const percent = sliderPercent(normalizedValue, bounds.minimum, bounds.maximum);
  const valueText = formattedValue(formatValue, normalizedValue);
  const minimumText = formattedValue(formatValue, bounds.minimum);
  const maximumText = formattedValue(formatValue, bounds.maximum);
  const controlRef = useRef(null);
  const labelRef = useRef(null);
  const minimumBoundRef = useRef(null);
  const maximumBoundRef = useRef(null);
  const valueRef = useRef(null);
  const touchId = useRef(null);
  const [valueLayout, setValueLayout] = useState(null);
  useLayoutEffect(() => {
    if (!showBounds) return;
    return observeLayout([controlRef.current, valueRef.current, labelRef.current,
      minimumBoundRef.current, maximumBoundRef.current], () => {
      const next = layoutSingleSliderLabels({
        width: controlRef.current?.clientWidth ?? 0, percent,
        valueWidth: valueRef.current?.offsetWidth ?? 0,
        inlineLabelWidth: placement === "inline" ? labelRef.current?.offsetWidth ?? 0 : 0,
        minimumBoundWidth: minimumBoundRef.current?.offsetWidth ?? 0,
        maximumBoundWidth: maximumBoundRef.current?.offsetWidth ?? 0,
      });
      setValueLayout(current => current && Object.keys(next).every(key => current[key] === next[key]) ? current : next);
    });
  }, [showBounds, percent, placement, label, valueText, minimumText, maximumText]);

  const touchValue = event => {
    if (disabled) return;
    const touch = [...event.changedTouches].find(item => item.identifier === touchId.current);
    const rect = controlRef.current?.getBoundingClientRect();
    if (!touch || !rect) return;
    const next = sliderValueAtPosition(touch.clientX, rect, bounds.minimum, bounds.maximum,
      normalizedStep, 44);
    if (next !== normalizedValue) onChange?.(next);
  };

  return <div className={["data-slider", "data-slider--single", className].filter(Boolean).join(" ")}
    data-slider data-selection-mode="single"
    data-show-bounds={showBounds || undefined}
    data-disabled={disabled || undefined} data-label-placement={placement}
    data-layout={resolvedLayout}
    style={{
      ...style,
      "--data-slider-start": "0%",
      "--data-slider-end": `${percent}%`,
      "--data-slider-start-position": "0%",
      "--data-slider-end-position": `${percent}%`,
    }}>
    {placement !== "inline" && <SliderLabel controlId={controlId} labelId={labelId}
      label={label} placement={placement} labelRef={labelRef} />}
    <div ref={controlRef} className="data-slider-control"
      onTouchStart={event => { if (!disabled) { touchId.current = event.changedTouches[0]?.identifier; touchValue(event); } }}
      onTouchMove={touchValue}
      onTouchEnd={() => { touchId.current = null; }}
      onTouchCancel={() => { touchId.current = null; }}>
      {placement === "inline" && <SliderLabel controlId={controlId} labelId={labelId}
        label={label} placement={placement} labelRef={labelRef} />}
      <span className="data-slider-track" aria-hidden="true">
        <span className="data-slider-selection" />
        <span className="data-slider-handle data-slider-handle--upper" />
      </span>
      {showBounds && <>
        <span ref={minimumBoundRef} className="data-slider-bound data-slider-bound--minimum"
          data-hidden={!valueLayout?.showMinimum || normalizedValue === bounds.minimum || undefined}
          aria-hidden="true">{minimumText}</span>
        <span ref={maximumBoundRef} className="data-slider-bound data-slider-bound--maximum"
          data-hidden={!valueLayout?.showMaximum || normalizedValue === bounds.maximum || undefined}
          aria-hidden="true">{maximumText}</span>
      </>}
      <output ref={valueRef} htmlFor={controlId}
        style={showBounds && valueLayout ? { left: valueLayout.valueLeft, right: "auto" } : undefined}
        className="data-slider-value data-slider-value--end">{valueText}</output>
      <input id={controlId} className="data-slider-input data-slider-input--single" type="range"
        name={name}
        min={bounds.minimum} max={bounds.maximum} step={normalizedStep} value={normalizedValue}
        disabled={disabled} aria-labelledby={labelId} aria-valuetext={valueText}
        onChange={(event) => onChange?.(clampSliderValue(
          event.currentTarget.valueAsNumber,
          bounds.minimum,
          bounds.maximum,
        ))} />
    </div>
  </div>;
}

export function RangeSlider({
  id,
  name,
  lowerName,
  upperName,
  label = "Range",
  min = 0,
  max = 100,
  step = 1,
  minDistance = 0,
  value = [min, max],
  onChange,
  formatValue = String,
  disabled = false,
  showBounds = false,
  labelPlacement = "outside",
  layout: layoutMode = "stacked",
  className = "",
  style,
}) {
  const generatedId = useId();
  const baseId = stableId(id, generatedId);
  const lowerId = `${baseId}-lower`;
  const upperId = `${baseId}-upper`;
  const labelId = `${baseId}-label`;
  const lowerLabelId = `${baseId}-lower-label`;
  const upperLabelId = `${baseId}-upper-label`;
  const placement = normalizedLabelPlacement(labelPlacement);
  const resolvedLayout = normalizedSliderLayout(layoutMode);
  const bounds = normalizeSliderBounds(min, max);
  const normalizedStep = normalizeSliderStep(step);
  const distance = normalizeMinDistance(minDistance, bounds.minimum, bounds.maximum);
  const [lower, upper] = normalizeRangeValue(
    value,
    bounds.minimum,
    bounds.maximum,
    distance,
  );
  const startPercent = sliderPercent(lower, bounds.minimum, bounds.maximum);
  const endPercent = sliderPercent(upper, bounds.minimum, bounds.maximum);
  const lowerText = formattedValue(formatValue, lower);
  const upperText = formattedValue(formatValue, upper);
  const minimumText = formattedValue(formatValue, bounds.minimum);
  const maximumText = formattedValue(formatValue, bounds.maximum);
  const boundaryActiveThumb = lower === upper && lower === bounds.minimum ? "upper"
    : lower === upper && upper === bounds.maximum ? "lower" : null;
  const [activeThumb, setActiveThumb] = useState(null);
  const renderedActiveThumb = boundaryActiveThumb ?? activeThumb ?? "upper";
  const controlRef = useRef(null);
  const touchThumb = useRef(null);
  const lowerValueRef = useRef(null);
  const upperValueRef = useRef(null);
  const labelRef = useRef(null);
  const minimumBoundRef = useRef(null);
  const maximumBoundRef = useRef(null);
  const layout = useRangeValueLayout({
    controlRef,
    lowerValueRef,
    upperValueRef,
    labelRef,
    minimumBoundRef,
    maximumBoundRef,
    startPercent,
    endPercent,
    showBounds,
    layoutKey: `${placement}:${label}:${minimumText}:${maximumText}:${lowerText}:${upperText}`,
  });
  const centerInlineLabel = placement === "inline" && layout?.centerInlineLabel;

  function changeThumb(thumb, nextValue) {
    setActiveThumb(thumb);
    onChange?.(updateRangeValue(
      [lower, upper],
      thumb,
      nextValue,
      bounds.minimum,
      bounds.maximum,
      distance,
    ));
  }

  const touchValue = event => {
    if (disabled || !touchThumb.current) return;
    const touch = [...event.changedTouches].find(item => item.identifier === touchThumb.current.id);
    const rect = controlRef.current?.getBoundingClientRect();
    if (!touch || !rect) return;
    const next = sliderValueAtPosition(touch.clientX, rect, bounds.minimum, bounds.maximum,
      normalizedStep, 44);
    changeThumb(touchThumb.current.thumb, next);
  };

  return <div className={["data-slider", "data-slider--range", className].filter(Boolean).join(" ")}
    data-slider data-selection-mode="range"
    data-disabled={disabled || undefined} data-label-placement={placement}
    data-layout={resolvedLayout}
    data-collapsed={lower === upper || undefined}
    data-active-thumb={renderedActiveThumb}
    data-center-inline-label={centerInlineLabel || undefined}
    style={{
      ...style,
      "--data-slider-start": `${startPercent}%`,
      "--data-slider-end": `${endPercent}%`,
      "--data-slider-midpoint": `${(startPercent + endPercent) / 2}%`,
      "--data-slider-span": `${endPercent - startPercent}%`,
      "--data-slider-start-position": `${startPercent}%`,
      "--data-slider-end-position": `${endPercent}%`,
    }}>
    {placement !== "inline" && <SliderLabel controlId={lowerId} labelId={labelId}
      label={label} placement={placement} labelRef={labelRef} />}
    <div ref={controlRef} className="data-slider-control"
      onTouchStart={event => {
        if (disabled) return;
        const touch = event.changedTouches[0];
        const rect = controlRef.current?.getBoundingClientRect();
        if (!touch || !rect) return;
        const next = sliderValueAtPosition(touch.clientX, rect, bounds.minimum, bounds.maximum,
          normalizedStep, 44);
        touchThumb.current = { id: touch.identifier,
          thumb: Math.abs(next - lower) <= Math.abs(next - upper) ? "lower" : "upper" };
        touchValue(event);
      }}
      onTouchMove={touchValue}
      onTouchEnd={() => { touchThumb.current = null; }}
      onTouchCancel={() => { touchThumb.current = null; }}>
      {placement === "inline" && <SliderLabel controlId={lowerId} labelId={labelId}
        label={label} placement={placement} labelRef={labelRef} />}
      <span className="data-slider-track" aria-hidden="true">
        <span className="data-slider-selection" />
        <span className="data-slider-handle data-slider-handle--lower" />
        <span className="data-slider-handle data-slider-handle--upper" />
      </span>
      {showBounds && <>
        <span ref={minimumBoundRef} className="data-slider-bound data-slider-bound--minimum"
          aria-hidden="true" data-hidden={!layout?.showMinimum || undefined}>{minimumText}</span>
        <span ref={maximumBoundRef} className="data-slider-bound data-slider-bound--maximum"
          aria-hidden="true" data-hidden={!layout?.showMaximum || undefined}>{maximumText}</span>
      </>}
      <output ref={lowerValueRef} htmlFor={lowerId}
        className="data-slider-value data-slider-value--lower"
        data-placement={centerInlineLabel ? "edge" : layout?.lowerPlacement}
        style={centerInlineLabel
          ? { left: "var(--data-slider-control-padding)", visibility: "visible" }
          : { left: layout ? `${layout.lowerLeft}px` : 0, visibility: layout ? "visible" : "hidden" }}>
        {lowerText}
      </output>
      <output ref={upperValueRef} htmlFor={upperId}
        className="data-slider-value data-slider-value--upper"
        data-placement={centerInlineLabel ? "edge" : layout?.upperPlacement}
        style={centerInlineLabel
          ? { right: "var(--data-slider-control-padding)", left: "auto", visibility: "visible" }
          : { left: layout ? `${layout.upperLeft}px` : 0, visibility: layout ? "visible" : "hidden" }}>
        {upperText}
      </output>
      <input id={lowerId} className="data-slider-input data-slider-input--lower" data-thumb="lower"
        name={lowerName ?? name}
        type="range" min={bounds.minimum} max={bounds.maximum}
        step={normalizedStep} value={lower} disabled={disabled}
        aria-labelledby={`${labelId} ${lowerLabelId}`} aria-valuetext={lowerText}
        onFocus={() => setActiveThumb("lower")} onPointerDown={() => setActiveThumb("lower")}
        onChange={(event) => changeThumb("lower", event.currentTarget.valueAsNumber)} />
      <input id={upperId} className="data-slider-input data-slider-input--upper" data-thumb="upper"
        name={upperName ?? name}
        type="range" min={bounds.minimum} max={bounds.maximum}
        step={normalizedStep} value={upper} disabled={disabled}
        aria-labelledby={`${labelId} ${upperLabelId}`} aria-valuetext={upperText}
        onFocus={() => setActiveThumb("upper")} onPointerDown={() => setActiveThumb("upper")}
        onChange={(event) => changeThumb("upper", event.currentTarget.valueAsNumber)} />
    </div>
    <span id={lowerLabelId} className="data-slider-visually-hidden">Minimum</span>
    <span id={upperLabelId} className="data-slider-visually-hidden">Maximum</span>
  </div>;
}
