import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { XAxis, useChartWidth, usePlotArea } from "recharts";
import { temporalAxisLayout } from "./chart-data-shape.js";
import { tick } from "./chart-theme.js";

export function TemporalAxisTick({ x, y, payload, formatLabel, onMeasure }) {
  const textRef = useRef(null);
  useLayoutEffect(() => {
    const width = textRef.current?.getComputedTextLength?.();
    if (Number.isFinite(width) && width > 0) onMeasure?.(payload.value,width);
  });
  return <text ref={textRef} x={x} y={y + 11} fill="var(--secondary)" textAnchor="middle" fontSize={12}
    data-temporal-axis-tick data-axis-value={payload.value}>{formatLabel(payload.value)}</text>;
}

export function TemporalXAxis({ values, banded = false, continuous = false, ...props }) {
  const plot = usePlotArea();
  const chartWidth = useChartWidth() ?? 0;
  const probeRef = useRef(null), measuredSignature = useRef("");
  const [widths,setWidths] = useState({});
  const textMeasure = useRef(null);
  const valuesKey = JSON.stringify(values);
  const includeYear = new Set(values.map(value => String(value).slice(0,4))).size > 1;
  const times = continuous ? values.map(value => Date.parse(value)) : [];
  const start = Math.min(...times), end = Math.max(...times);
  const includeTime = continuous && (end > start && end - start < 86_400_000 || times.some(time => time % 86_400_000));
  const timeFormat = useMemo(() => includeTime ? new Intl.DateTimeFormat("en-US", {
    month:"short",day:"numeric",...(includeYear ? {year:"numeric"} : {}),
    hour:"2-digit",minute:"2-digit",...(end-start < 60_000 ? {second:"2-digit",fractionalSecondDigits:3} : {}),
    hourCycle:"h23",timeZone:"UTC",
  }) : null, [includeTime,includeYear,end-start < 60_000]);
  const formatLabel = value => continuous
    ? timeFormat ? timeFormat.format(new Date(value)) : tick(new Date(value).toISOString(),{includeYear})
    : tick(value,{includeYear});
  const recordWidth = (value,width) => setWidths(current => width > (current[value] ?? 0) + .5
    ? {...current,[value]:width} : current);
  const measure = (force = false) => {
    const probe = probeRef.current, view = probe?.ownerDocument?.defaultView;
    if (!view) return;
    const style = view.getComputedStyle(probe);
    const font = `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
    const signature = `${valuesKey}|${font}|${style.letterSpacing}`;
    if (!force && signature === measuredSignature.current) return;
    const context = probe.ownerDocument.createElement("canvas").getContext("2d");
    if (!context) return;
    context.font = font;
    const spacing = Number.parseFloat(style.letterSpacing) || 0;
    textMeasure.current = label => context.measureText(label).width + Math.max(0,label.length-1)*spacing;
    measuredSignature.current = signature;
    setWidths({});
  };
  // Read the actual inherited SVG font, including theme changes, before paint.
  useLayoutEffect(() => { measure(); });
  useEffect(() => {
    const fonts = probeRef.current?.ownerDocument?.fonts;
    let active = true;
    const update = () => { if (active) measure(true); };
    fonts?.ready?.then(update);
    fonts?.addEventListener?.("loadingdone",update);
    return () => { active=false; fonts?.removeEventListener?.("loadingdone",update); };
  }, [valuesKey]);
  const layout = temporalAxisLayout(values,{
    plotWidth:plot?.width ?? chartWidth,
    leftRoom:plot?.x ?? 0,
    rightRoom:plot ? Math.max(0,chartWidth-plot.x-plot.width) : 0,
    banded, continuous,
    measureLabel:value => widths[value] ?? textMeasure.current?.(String(formatLabel(value))) ?? String(formatLabel(value)).length*8,
  });
  return <>
    <text ref={probeRef} visibility="hidden" aria-hidden="true" pointerEvents="none" fontSize={12}
      data-temporal-axis-start={values[0]} data-temporal-axis-end={values.at(-1)}
      data-temporal-axis-scale={continuous ? "time" : "bucket"}>M</text>
    <XAxis {...props} ticks={layout.ticks} padding={layout.padding} interval={0} minTickGap={0}
      {...(continuous ? {type:"number",scale:"linear",domain:start === end ? [start-43_200_000,end+43_200_000] : [start,end]} : {})}
      tick={props.tick === false ? false : <TemporalAxisTick formatLabel={formatLabel} onMeasure={recordWidth} />} />
  </>;
}
