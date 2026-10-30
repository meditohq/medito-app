import React, { useLayoutEffect, useMemo, useRef, useState } from "react";
import { ReferenceArea, ReferenceDot, ReferenceLine, ZIndexLayer, usePlotArea, useXAxisScale, useYAxisScale } from "recharts";
import { chartAnnotationLayoutTokens as tokens, layoutChartAnnotations, chartAnnotationArrow, chartAnnotationBarArrow } from "./chart-annotation-layout.js";

// One readable theme color ties the annotation text, reference, and connector
// together. Keep it distinct from series colors and faint chart grid lines.
const annotationColor = "var(--secondary)";

// Reference components own domains and mark geometry. A separate shared layer
// lays out all labels together, so independently positioned labels cannot overlap.
export function chartAnnotationMarks(annotations, { horizontal = false, layer = "marks", barPoints = false } = {}) {
  return annotations.flatMap((annotation) => {
    const { id, kind, x, xEnd, y, valueAxisId = 0 } = annotation;
    if ((kind === "range") !== (layer === "ranges")) return [];
    const color = annotationColor;
    const common = { className: `chart-annotation-mark--${kind}`, "data-annotation-mark": id,
      ...(horizontal ? { xAxisId: valueAxisId } : { yAxisId: valueAxisId }),
      ifOverflow: "discard", pointerEvents: "none" };
    if (kind === "range") return [<ReferenceArea key={id} {...common} {...(horizontal ? { y1: x, y2: xEnd } : { x1: x, x2: xEnd })}
      fill={color} fillOpacity={0.06} stroke="none" />];
    if (kind === "point") return barPoints ? [] : [<ReferenceDot key={id} {...common} {...(horizontal ? { x: y, y: x } : { x, y })}
      r={3} fill="var(--surface)" stroke={color} strokeWidth={2} />];
    const position = kind === "benchmark" ? (horizontal ? { x: y } : { y }) : (horizontal ? { y: x } : { x });
    return [<ReferenceLine key={id} {...common} {...position} ifOverflow={kind === "benchmark" ? "extendDomain" : "discard"}
      stroke={color} strokeWidth={1}
      strokeDasharray={kind === "benchmark" ? "5 4" : "2 3"} />];
  });
}

export function useChartText(weight = 400, fontSize = 12) {
  const [font, setFont] = useState(`${weight} ${fontSize}px sans-serif`);
  const measureFont = (node) => { if (node) setFont(`${weight} ${fontSize}px ${getComputedStyle(node).fontFamily}`); };
  const measureText = useMemo(() => {
    const context = typeof document === "undefined" ? null : document.createElement("canvas").getContext("2d");
    if (context) context.font = font;
    return (text) => context?.measureText(text).width ?? text.length * 8;
  }, [font]);
  return { font, measureFont, measureText };
}

// Measure painted geometry, not just reviewed anchors: an endpoint label can
// otherwise cover the whole bar or the other series. Sample actual curved paths.
function paintedObstacles(svg, font, cache) {
  if (!svg?.getScreenCTM()) return [];
  const bars = '.recharts-bar-rectangle .recharts-rectangle';
  const curves = '.recharts-line-curve, .recharts-area-curve, .recharts-area-area';
  const nodes = [...svg.querySelectorAll(`${bars}, ${curves}, .recharts-line-dot, .recharts-area-dot, .recharts-label-list text, .recharts-reference-line-line[data-annotation-mark]`)];
  const key = JSON.stringify([font, svg.getAttribute('viewBox'), nodes.map((node) => node.outerHTML)]);
  // Fill tests close over live SVG nodes. Equal markup is not enough after
  // Recharts replaces a shape during resize, theme change, or geometry edits.
  if (cache.current?.key === key && cache.current.nodes.every((node, index) => node === nodes[index])) return cache.current.boxes;
  const inverse = svg.getScreenCTM().inverse();
  const boxes = [];
  for (const node of nodes) {
    const matrix = inverse.multiply(node.getScreenCTM());
    const point = (p) => new DOMPoint(p.x, p.y).matrixTransform(matrix);
    const add = (a, b, pad = 0) => {
      const box = { x: Math.min(a.x, b.x) - pad, y: Math.min(a.y, b.y) - pad,
        width: Math.abs(b.x - a.x) + 2 * pad, height: Math.abs(b.y - a.y) + 2 * pad };
      boxes.push(box);
      return box;
    };
    if (node.matches(curves)) {
      const length = node.getTotalLength();
      let previous = point(node.getPointAtLength(0));
      for (let at = 6; at < length + 6; at += 6) {
        const next = point(node.getPointAtLength(Math.min(at, length)));
        add(previous, next, 2); previous = next;
      }
      if (node.matches('.recharts-area-area')) {
        // Reserve the actual fill, not its bounding rectangle: a sloped area
        // can leave useful interior whitespace above its lower observations.
        // Boundary samples above cover edge cells; contiguous occupied cells
        // merge into row runs so layout does not receive a full pixel grid.
        const box = node.getBBox();
        const step = 6;
        for (let y = box.y; y < box.y + box.height; y += step) {
          let start = null;
          for (let x = box.x; x < box.x + box.width + step; x += step) {
            const filled = x < box.x + box.width
              && node.isPointInFill(new DOMPoint(x + step / 2, y + step / 2));
            if (filled && start === null) start = x;
            if (!filled && start !== null) {
              add(point({ x: start, y }), point({ x: Math.min(x, box.x + box.width),
                y: Math.min(y + step, box.y + box.height) }));
              start = null;
            }
          }
        }
      }
    } else {
      const box = node.getBBox();
      const painted = add(point(box), point({ x: box.x + box.width, y: box.y + box.height }));
      if (node.matches(bars) && typeof node.isPointInFill === "function") {
        const local = matrix.inverse();
        painted.contains = (p) => node.isPointInFill(new DOMPoint(p.x, p.y).matrixTransform(local));
      }
    }
  }
  cache.current = { key, boxes, nodes };
  return boxes;
}

export function ChartAnnotationLayer({ annotations, horizontal = false, barPoints = false, onPlacedChange }) {
  const plot = usePlotArea();
  const xScale = useXAxisScale();
  const yScale = useYAxisScale();
  const secondaryXScale = useXAxisScale("secondary");
  const secondaryYScale = useYAxisScale("secondary");
  const { font, measureFont: readFont, measureText } = useChartText(400, tokens.fontSize);
  const layer = useRef(null);
  const markCache = useRef(null);
  const layoutCache = useRef(null);
  const [obstacles, setObstacles] = useState([]);
  const measureFont = (node) => {
    layer.current = node;
    readFont(node?.querySelector("text") ?? node);
  };
  useLayoutEffect(() => {
    const next = paintedObstacles(layer.current?.ownerSVGElement, font, markCache);
    setObstacles((previous) => previous === next || !previous.length && !next.length ? previous : next);
  });
  const category = horizontal ? yScale : xScale;
  const usable = plot && category;
  const items = usable ? annotations.flatMap((annotation) => {
    const value = annotation.valueAxisId === "secondary"
      ? horizontal ? secondaryXScale : secondaryYScale : horizontal ? xScale : yScale;
    const numeric = annotation.kind === "point" || annotation.kind === "benchmark";
    if (numeric && !value) return [];
    let categoryPosition = category(annotation.x, { position: "middle" });
    // Match ReferenceArea's actual band edges, including categorical bandwidth.
    // This is layout-only geometry, never a change to the reviewed range dates.
    const range = annotation.kind === "range" ? {
      axis: horizontal ? "y" : "x",
      start: category(annotation.x, { position: "start" }),
      end: category(annotation.xEnd, { position: "end" }),
    } : undefined;
    if (annotation.kind === "range") categoryPosition =
      (category(annotation.x, { position: "middle" }) + category(annotation.xEnd, { position: "middle" })) / 2;
    // Events and periods anchor a date, not an invented value. Start their text
    // beside the upper event lane (or the range midpoint), then search other clear space.
    const valuePosition = numeric ? value(annotation.y, { position: "middle" })
      : annotation.kind === "event" ? horizontal ? plot.x + 20 : plot.y + 20
      : horizontal ? plot.x + plot.width / 2 : plot.y + plot.height / 2;
    if (annotation.kind === "benchmark") categoryPosition = horizontal ? plot.y + 12 : plot.x + plot.width - 12;
    const point = horizontal ? { x: valuePosition, y: categoryPosition } : { x: categoryPosition, y: valuePosition };
    return [{ ...annotation, anchor: point, range, barPoint: barPoints && annotation.kind === "point", horizontal,
      preferred: horizontal ? "right" : undefined }];
  }) : [];
  const bounds = usable ? plot : null;
  const anchors = items.map(({ anchor: p }) => ({ x: p.x - 4, y: p.y - 4, width: 8, height: 8 }));
  const layoutKey = JSON.stringify([items, bounds, font]);
  if (layoutCache.current?.key !== layoutKey || layoutCache.current?.obstacles !== obstacles)
    layoutCache.current = { key: layoutKey, obstacles,
      layouts: layoutChartAnnotations(items, bounds, { measureText, obstacles: [...obstacles, ...anchors] }) };
  const { layouts } = layoutCache.current;
  const displayed = layouts.flatMap((box) => {
    const annotation = annotations.find(({ id }) => id === box.id);
    // A reference line already identifies its date/value. Connect to the
    // nearest point along it, not an arbitrary distant end of the line.
    const anchor = { ...box.anchor };
    const axis = (annotation.kind === "benchmark") === horizontal ? "y" : "x";
    if (annotation.kind !== "point") {
      anchor[axis] = box[axis] + box[axis === "x" ? "width" : "height"] / 2;
    }
    const otherLabels = layouts.filter((other) => other.id !== box.id);
    const barPoint = barPoints && annotation.kind === "point";
    const arrow = barPoint ? chartAnnotationBarArrow(box, obstacles, horizontal, otherLabels, plot)
      : chartAnnotationArrow({ ...box, anchor }, otherLabels, obstacles,
        ["benchmark", "event"].includes(annotation.kind) && axis);
    const distance = Math.hypot(Math.max(box.x - anchor.x, anchor.x - box.x - box.width, 0),
      Math.max(box.y - anchor.y, anchor.y - box.y - box.height, 0));
    // Keep nearby text undecorated. A displaced label without a safe connector
    // belongs in the full-text figure note, not beside unrelated evidence.
    return (barPoint || distance > 24) && !arrow ? [] : [{ box, annotation, arrow }];
  });
  const placedKey = JSON.stringify(displayed.map(({ box }) => box.id));
  useLayoutEffect(() => { onPlacedChange?.(JSON.parse(placedKey)); }, [placedKey, onPlacedChange]);
  if (!usable || !annotations.length) return null;
  return <ZIndexLayer zIndex={2001}>
    <g ref={measureFont} className="chart-annotation-labels" pointerEvents="none" aria-hidden="true">
      {displayed.map(({ box, annotation, arrow }) => {
        const textX = box.textAnchor === "end" ? box.x + box.width - tokens.paddingX : box.x + tokens.paddingX;
        return <g key={box.id}>
          {arrow && <path data-annotation-arrow={box.id} d={arrow.path}
            fill="none" stroke={annotationColor} strokeWidth={1}
            strokeLinecap="round" strokeLinejoin="round" />}
          <g className="chart-annotation-label" data-chart-annotation={box.id} data-annotation-kind={annotation.kind}>
            <text x={textX} y={box.y + tokens.paddingY + tokens.fontSize}
              fill={annotationColor} fontSize={tokens.fontSize} fontWeight={400} textAnchor={box.textAnchor ?? "start"}>
              {box.lines.map((line, i) => <tspan key={i} x={textX}
                dy={i ? tokens.lineHeight : 0}>{line}</tspan>)}
            </text>
          </g>
        </g>;
      })}
    </g>
  </ZIndexLayer>;
}

// Every annotation has one readable equivalent. Only text that cannot safely
// fit on the plot is visible below it; export and print retain exact evidence.
export function ChartAnnotationNotes({ annotations, placedIds = [] }) {
  if (!annotations.length) return null;
  return <div className="chart-annotation-notes" role="note" aria-label="Chart annotation evidence">
    {annotations.map((annotation) => <p key={annotation.id} data-annotation-note={annotation.id}
      className={`chart-annotation-note${placedIds.includes(annotation.id) ? " visually-hidden" : ""}`}>
      <span>{annotation.label}</span>
      <span className="chart-annotation-evidence visually-hidden"> {annotation.evidence}</span>
    </p>)}
  </div>;
}
